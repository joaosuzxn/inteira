import Foundation

public struct AutomationState: Codable, Sendable, Equatable {
    /// Quando o dono saiu do raio de chegada pela última vez; limpo ao entrar de novo.
    public var lastArrivalExit: Date?

    public init(lastArrivalExit: Date? = nil) { self.lastArrivalExit = lastArrivalExit }
}

public enum RegionEvent: Sendable, Equatable {
    case enteredArrival, exitedArrival, enteredDeparture, exitedDeparture
}

public enum AutomationDecision: Sendable, Equatable {
    case none
    case turnOnIfOff(temperature: Int)
    case turnOffIfOn
}

/// Regra de disparo: lógica pura, sem CoreLocation, com o relógio passado por parâmetro.
public enum AutomationEngine {
    public static func decide(
        _ event: RegionEvent, at date: Date, settings: AutomationSettings, state: inout AutomationState
    ) -> AutomationDecision {
        guard settings.enabled, settings.home != nil else { return .none }
        let settings = settings.clamped()
        switch event {
        case .exitedArrival:
            state.lastArrivalExit = date
            return .none
        case .enteredArrival:
            guard let exit = state.lastArrivalExit else { return .none }
            state.lastArrivalExit = nil
            guard date.timeIntervalSince(exit) >= settings.minAbsenceForArrival else { return .none }
            return .turnOnIfOff(temperature: settings.autoTemperature)
        case .exitedDeparture:
            return .turnOffIfOn
        case .enteredDeparture:
            return .none
        }
    }
}
