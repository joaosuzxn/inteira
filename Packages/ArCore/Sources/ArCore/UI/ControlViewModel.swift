import Foundation
import Observation

/// Estado da tela de controle manual. Toques seguidos em +/- viram um único comando.
@MainActor @Observable
public final class ControlViewModel {
    public private(set) var status: ACStatus?
    public private(set) var pendingTemperature: Int?
    public private(set) var isBusy = false
    public private(set) var errorMessage: String?

    /// Temperatura mostrada: a escolhida ainda não enviada, senão o alvo lido do ar.
    public var displayedTemperature: Int? {
        pendingTemperature ?? status.map { Int($0.targetTemperature) }
    }

    private let control: any ACControlling
    private let history: HistoryStore?
    private let debounce: Duration
    private let clock: any Clock<Duration>
    private var debounceTask: Task<Void, Never>?

    public init(
        control: any ACControlling,
        history: HistoryStore?,
        debounce: Duration = .seconds(1),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.control = control
        self.history = history
        self.debounce = debounce
        self.clock = clock
    }

    /// Esquece estado, temperatura pendente e erro (ao sair da conta ou trocar de aparelho).
    public func reset() {
        debounceTask?.cancel()
        debounceTask = nil
        status = nil
        pendingTemperature = nil
        errorMessage = nil
    }

    public func refresh() async {
        do {
            status = try await control.status()
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    public func togglePower() async {
        guard !isBusy, let status else { return }
        let command: ACCommand = status.isOn ? .turnOff : .turnOn(temperature: displayedTemperature ?? 23)
        isBusy = true
        defer { isBusy = false }
        await perform(command)
    }

    public func increment() { adjust(by: 1) }
    public func decrement() { adjust(by: -1) }

    private func adjust(by delta: Int) {
        guard let current = displayedTemperature else { return }
        let range = ACCommand.temperatureRange
        pendingTemperature = min(max(current + delta, range.lowerBound), range.upperBound)
        debounceTask?.cancel()
        debounceTask = Task { [weak self, clock, debounce] in
            do { try await clock.sleep(for: debounce) } catch { return }
            await self?.flushPendingTemperature()
        }
    }

    private func flushPendingTemperature() async {
        guard let temperature = pendingTemperature else { return }
        await perform(.setTemperature(temperature))
        // Se o usuário mexeu de novo durante o envio, o novo valor continua pendente.
        if pendingTemperature == temperature { pendingTemperature = nil }
    }

    /// Envia, registra no histórico e relê o estado.
    private func perform(_ command: ACCommand) async {
        do {
            try await control.send(command)
            errorMessage = nil
            await history?.append(HistoryEntry(event: .manual(command), outcome: .ok))
            await refresh()
        } catch {
            let message = Self.message(for: error)
            errorMessage = message
            await history?.append(HistoryEntry(event: .manual(command), outcome: .failed(message: message)))
            // Envio falhou: a temperatura escolhida não vale mais.
            pendingTemperature = nil
        }
    }

    private static func message(for error: Error) -> String {
        (error as? MideaCloudError)?.userMessage ?? "Erro inesperado"
    }
}
