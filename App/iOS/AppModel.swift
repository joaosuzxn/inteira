import CoreLocation
import Foundation
import Observation
import UIKit
import os
import ArCore

/// Dono dos objetos do app no iPhone: serviço da nuvem, controle, histórico, ajustes e automação.
/// As telas só leem e chamam; nada de protocolo ou regra de disparo mora aqui.
/// É criado na abertura do app (inclusive quando o iOS o relança em segundo plano por um evento de
/// região), e já abre o monitor de região, para o evento chegar sem nenhuma tela aparecer.
@MainActor @Observable
final class AppModel {
    let service: AirConditionerService
    let control: ControlViewModel
    let history: HistoryStore
    let coordinator: AutomationCoordinator
    let location = LocationAccess()

    /// Ajustes da automação (persistidos em `settings.json`). Mude só por `updateSettings`.
    private(set) var settings: AutomationSettings
    /// Entradas do histórico, mais recente primeiro (releia com `reloadHistory`).
    private(set) var entries: [HistoryEntry] = []
    /// Há conta salva com um ar escolhido.
    private(set) var isSignedIn: Bool
    private(set) var applianceName: String?
    private(set) var accountName: String?

    /// Distância até casa na última leitura (só com a tela principal à vista).
    private(set) var distanceToHome: Double?
    /// Saída do raio de chegada ainda sem volta, para mostrar "fora há".
    private(set) var lastArrivalExit: Date?

    private let store: KeychainCredentialStore
    private let settingsURL: URL
    /// Cópia dos ajustes que o coordenador lê fora da thread principal.
    private let settingsSnapshot: OSAllocatedUnfairLock<AutomationSettings>
    private var regionMonitor: RegionMonitor!
    /// Última reconfiguração do monitor; a próxima espera por ela para não se cruzarem.
    private var monitorUpdate: Task<Void, Never>?

    init() {
        let directory = Self.supportDirectory()
        let store = KeychainCredentialStore()
        let service = AirConditionerService(store: store, transport: URLSessionTransport())
        let history = HistoryStore(fileURL: directory.appendingPathComponent("history.json"))
        self.store = store
        self.service = service
        self.history = history
        self.control = ControlViewModel(control: service, history: history)
        self.settingsURL = directory.appendingPathComponent("settings.json")
        let settings = Self.loadSettings(from: settingsURL)
        self.settings = settings
        let snapshot = OSAllocatedUnfairLock(initialState: settings)
        self.settingsSnapshot = snapshot
        let coordinator = AutomationCoordinator(
            control: service, history: history, notifier: LocalNotifier(),
            settings: { snapshot.withLock { $0 } },
            stateURL: directory.appendingPathComponent("automation-state.json"))
        self.coordinator = coordinator
        let stored = (try? store.load()) ?? nil
        self.isSignedIn = stored?.appliance != nil
        self.applianceName = stored?.appliance?.name
        self.accountName = stored?.account

        // O evento vai direto ao coordenador, que manda o comando antes de qualquer outra coisa.
        // A tarefa de segundo plano pede ao iOS tempo para a chamada de rede terminar.
        regionMonitor = RegionMonitor { [weak self] event, date in
            let work = await BackgroundWork.begin()
            await coordinator.handle(event, at: date)
            await work.end()
            await self?.automationStateChanged()
        }
        location.onChange = { [weak self] in self?.applyMonitor() }
        applyMonitor()
    }

    /// Relê a conta do Keychain depois de entrar ou sair.
    func reloadSession() {
        let stored = (try? store.load()) ?? nil
        isSignedIn = stored?.appliance != nil
        applianceName = stored?.appliance?.name
        accountName = stored?.account
    }

    func signOut() async throws {
        try await service.signOut()
        reloadSession()
    }

    func reloadHistory() async {
        entries = await history.entries()
    }

    /// Aplica a mudança, limita às faixas permitidas, grava e avisa quem escuta.
    func updateSettings(_ change: (inout AutomationSettings) -> Void) {
        var next = settings
        change(&next)
        next = next.clamped()
        guard next != settings else { return }
        settings = next
        let saved = next
        settingsSnapshot.withLock { $0 = saved }
        if let data = try? JSONEncoder().encode(next) { try? data.write(to: settingsURL, options: .atomic) }
        applyMonitor()
    }

    // MARK: - Automação

    /// O automático está ligado nos ajustes, mas falta a permissão "Sempre": o monitor fica parado.
    var needsAlwaysPermission: Bool { settings.enabled && !location.isAlways }

    /// Liga ou desliga o automático; ao ligar, pede "Sempre" e notificações.
    func setAutomaticEnabled(_ enabled: Bool) {
        updateSettings { $0.enabled = enabled }
        guard enabled else { return }
        location.requestAlways()
        Task { await LocalNotifier.requestPermission() }
    }

    /// Lê a posição atual e a grava como casa; zera a hora de saída e recria os círculos.
    /// Devolve `false` se não deu para ler a posição.
    func useCurrentLocationAsHome() async -> Bool {
        guard let here = await location.currentLocation(accuracy: 100) else { return false }
        await coordinator.resetForNewHome()
        updateSettings {
            $0.home = Coordinate(latitude: here.coordinate.latitude, longitude: here.coordinate.longitude)
        }
        await automationStateChanged()
        return true
    }

    /// Atualiza a distância até casa e o "fora há" (tela principal à vista; não pede permissão).
    func refreshAutomationStatus() async {
        lastArrivalExit = await coordinator.lastArrivalExit()
        guard let home = settings.home, location.canReadLocation,
              let here = await location.currentLocation(accuracy: 1000, timeout: .seconds(10)) else {
            if settings.home == nil { distanceToHome = nil }
            return
        }
        distanceToHome = here.distance(from: CLLocation(latitude: home.latitude, longitude: home.longitude))
    }

    private func automationStateChanged() async {
        lastArrivalExit = await coordinator.lastArrivalExit()
        await reloadHistory()
    }

    /// Repassa os ajustes ao monitor; sem a permissão "Sempre", desliga o monitor em vez de fingir.
    private func applyMonitor() {
        var effective = settings
        effective.enabled = settings.enabled && location.isAlways
        let monitor = regionMonitor!
        let previous = monitorUpdate
        monitorUpdate = Task {
            await previous?.value
            await monitor.apply(effective)
        }
    }

    private static func loadSettings(from url: URL) -> AutomationSettings {
        let loaded = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(AutomationSettings.self, from: $0) }
        return (loaded ?? AutomationSettings()).clamped()
    }

    private static func supportDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}

/// Pede ao iOS alguns segundos a mais em segundo plano enquanto o comando vai para a nuvem.
@MainActor
private final class BackgroundWork {
    private var id = UIBackgroundTaskIdentifier.invalid

    static func begin() -> BackgroundWork {
        let work = BackgroundWork()
        work.id = UIApplication.shared.beginBackgroundTask(withName: "automação") { [weak work] in work?.end() }
        return work
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
