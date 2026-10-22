/// Estado lido do ar (atributos Lua de `/v1/device/status/lua/get`).
public struct ACStatus: Sendable, Equatable {
    public let isOn: Bool
    public let mode: String
    /// Alvo em °C, já somada a parte decimal (`small_temperature`).
    public let targetTemperature: Double
    public let indoorTemperature: Double?

    public init(isOn: Bool, mode: String, targetTemperature: Double, indoorTemperature: Double?) {
        self.isOn = isOn
        self.mode = mode
        self.targetTemperature = targetTemperature
        self.indoorTemperature = indoorTemperature
    }
}
