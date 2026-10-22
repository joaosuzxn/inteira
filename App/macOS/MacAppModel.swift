import Foundation
import Observation
import ServiceManagement
import ArCore

/// Dono dos objetos do app no Mac: serviço da nuvem, controle, conta e item de login.
/// As telas só leem e chamam; nada de protocolo mora aqui.
@MainActor @Observable
final class MacAppModel {
    let service: AirConditionerService
    let control: ControlViewModel

    private(set) var isSignedIn: Bool
    private(set) var applianceName: String?
    /// Mensagem curta (em português) quando registrar ou remover o item de login falha.
    private(set) var loginItemError: String?
    private(set) var launchesAtLogin: Bool

    private let store: KeychainCredentialStore
    @ObservationIgnored nonisolated(unsafe) private var refreshTask: Task<Void, Never>?

    private static let didConfigureKey = "didConfigureLoginItem"

    init() {
        let store = KeychainCredentialStore()
        let service = AirConditionerService(store: store, transport: URLSessionTransport())
        self.store = store
        self.service = service
        self.control = ControlViewModel(control: service, history: nil)
        let stored = (try? store.load()) ?? nil
        self.isSignedIn = stored?.appliance != nil
        self.applianceName = stored?.appliance?.name
        self.launchesAtLogin = SMAppService.mainApp.status == .enabled
        configureLoginItemOnFirstLaunch()
        startRefreshLoop()
    }

    deinit { refreshTask?.cancel() }

    /// Atualiza o estado do ar (ao abrir o painel e a cada 5 minutos).
    func refresh() async {
        guard isSignedIn else { return }
        await control.refresh()
    }

    func reloadSession() {
        let stored = (try? store.load()) ?? nil
        isSignedIn = stored?.appliance != nil
        applianceName = stored?.appliance?.name
        Task { await refresh() }
    }

    func signOut() async throws {
        try await service.signOut()
        reloadSession()
    }

    // MARK: Abrir ao iniciar o Mac

    func setLaunchAtLogin(_ enabled: Bool) {
        loginItemError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            loginItemError = "Não foi possível alterar a abertura ao iniciar o Mac"
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func configureLoginItemOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.didConfigureKey) else { return }
        defaults.set(true, forKey: Self.didConfigureKey)
        setLaunchAtLogin(true)
    }

    private func startRefreshLoop() {
        refreshTask = Task { [weak self] in
            let clock = ContinuousClock()
            while !Task.isCancelled {
                await self?.refresh()
                try? await clock.sleep(for: .seconds(300))
            }
        }
    }
}
