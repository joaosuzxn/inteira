import Foundation
import Observation
import ArCore

/// Dono dos objetos do app no iPhone: serviço da nuvem, controle, histórico e ajustes.
/// As telas só leem e chamam; nada de protocolo ou disparo mora aqui.
@MainActor @Observable
final class AppModel {
    let service: AirConditionerService
    let control: ControlViewModel
    let history: HistoryStore

    /// Ajustes da automação (persistidos em `settings.json`). Mude só por `updateSettings`.
    private(set) var settings: AutomationSettings
    /// Entradas do histórico, mais recente primeiro (releia com `reloadHistory`).
    private(set) var entries: [HistoryEntry] = []
    /// Há conta salva com um ar escolhido.
    private(set) var isSignedIn: Bool
    private(set) var applianceName: String?
    private(set) var accountName: String?

    /// Chamado depois de cada mudança de ajustes (a Task 11 liga o monitor de região aqui).
    var onSettingsChange: ((AutomationSettings) -> Void)?

    private let store: KeychainCredentialStore
    private let settingsURL: URL

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
        self.settings = Self.loadSettings(from: settingsURL)
        let stored = (try? store.load()) ?? nil
        self.isSignedIn = stored?.appliance != nil
        self.applianceName = stored?.appliance?.name
        self.accountName = stored?.account
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
        if let data = try? JSONEncoder().encode(next) { try? data.write(to: settingsURL, options: .atomic) }
        onSettingsChange?(next)
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
