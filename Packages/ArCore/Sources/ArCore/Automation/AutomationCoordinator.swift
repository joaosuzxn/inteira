import Foundation

public protocol AutomationNotifying: Sendable {
    func notify(title: String, body: String) async
}

/// Liga a regra de disparo ao ar: decide, envia na hora, avisa o dono e registra no histórico.
public actor AutomationCoordinator {
    private let control: any ACControlling
    private let history: HistoryStore
    private let notifier: any AutomationNotifying
    private let settings: @Sendable () -> AutomationSettings
    private let stateURL: URL
    private var state: AutomationState

    public init(
        control: any ACControlling, history: HistoryStore, notifier: any AutomationNotifying,
        settings: @escaping @Sendable () -> AutomationSettings, stateURL: URL
    ) {
        self.control = control
        self.history = history
        self.notifier = notifier
        self.settings = settings
        self.stateURL = stateURL
        state = Self.load(stateURL)
    }

    public func handle(_ event: RegionEvent, at date: Date) async {
        let decision = AutomationEngine.decide(event, at: date, settings: settings(), state: &state)
        saveState()
        switch decision {
        case .none:
            if let recorded = Self.historyEvent(for: event) {
                await history.append(HistoryEntry(date: date, event: recorded, outcome: .ok))
            }
        case .turnOnIfOff(let temperature):
            if let recorded = Self.historyEvent(for: event) {
                await history.append(HistoryEntry(date: date, event: recorded, outcome: .ok))
            }
            await run(.turnOn(temperature: temperature), event: .autoTurnOn(temperature: temperature), at: date)
        case .turnOffIfOn:
            if let recorded = Self.historyEvent(for: event) {
                await history.append(HistoryEntry(date: date, event: recorded, outcome: .ok))
            }
            await run(.turnOff, event: .autoTurnOff, at: date)
        }
    }

    public func resetForNewHome() async {
        state = AutomationState()
        saveState()
    }

    // MARK: - Envio

    private func run(_ command: ACCommand, event: HistoryEvent, at date: Date) async {
        let turningOn: Bool
        if case .turnOn = command { turningOn = true } else { turningOn = false }

        // Se não der para ler o estado, envia mesmo assim: ligar/desligar repetido é inofensivo.
        if let status = try? await control.status(), status.isOn == turningOn {
            let reason = turningOn ? "já estava ligado" : "já estava desligado"
            await history.append(HistoryEntry(date: date, event: event, outcome: .skipped(reason: reason)))
            return
        }
        do {
            try await control.send(command)
            await history.append(HistoryEntry(date: date, event: event, outcome: .ok))
            if case .turnOn(let temperature) = command {
                await notifier.notify(title: "Liguei o ar (\(temperature) °C)", body: "Você está chegando em casa.")
            } else {
                await notifier.notify(
                    title: "Desliguei o ar",
                    body: "Você passou de \(Self.radiusText(settings().clamped().departureRadius)) de casa.")
            }
        } catch {
            let message = (error as? MideaCloudError)?.userMessage ?? "Erro inesperado"
            await history.append(HistoryEntry(date: date, event: event, outcome: .failed(message: message)))
            await notifier.notify(
                title: turningOn ? "Não consegui ligar o ar" : "Não consegui desligar o ar", body: message)
        }
    }

    private static func historyEvent(for event: RegionEvent) -> HistoryEvent? {
        switch event {
        case .enteredArrival: .enteredArrival
        case .exitedArrival: .exitedArrival
        case .exitedDeparture: .exitedDeparture
        case .enteredDeparture: nil
        }
    }

    /// "500 m" abaixo de 1 km; senão km com até uma casa e vírgula ("2 km", "2,5 km").
    static func radiusText(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        let tenths = Int((meters / 100).rounded())
        let whole = tenths / 10, decimal = tenths % 10
        return decimal == 0 ? "\(whole) km" : "\(whole),\(decimal) km"
    }

    // MARK: - Estado em disco

    private static func load(_ url: URL) -> AutomationState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? Data(contentsOf: url)).flatMap { try? decoder.decode(AutomationState.self, from: $0) } ?? AutomationState()
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(state) { try? data.write(to: stateURL, options: .atomic) }
    }
}
