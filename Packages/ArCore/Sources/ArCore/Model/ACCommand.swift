/// Comando para o ar. "Ligar" leva o estado completo desejado, então repetir dá o mesmo resultado.
public enum ACCommand: Sendable, Equatable {
    case turnOn(temperature: Int)
    case turnOff
    case setTemperature(Int)

    public static let temperatureRange = 17...30

    /// Corpo de `command.control` enviado a `/v1/device/lua/control`.
    var control: [String: any Sendable] {
        switch self {
        case .turnOn(let temperature):
            return [
                "power": "on", "mode": "cool", "temperature": Self.clamp(temperature),
                "small_temperature": 0, "wind_speed": 102,
            ]
        case .turnOff:
            return ["power": "off"]
        case .setTemperature(let temperature):
            return ["temperature": Self.clamp(temperature)]
        }
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, temperatureRange.lowerBound), temperatureRange.upperBound)
    }
}

/// Controle de um ar já escolhido (implementado pelo app sobre o cliente da nuvem).
public protocol ACControlling: Sendable {
    func status() async throws -> ACStatus
    func send(_ command: ACCommand) async throws
}
