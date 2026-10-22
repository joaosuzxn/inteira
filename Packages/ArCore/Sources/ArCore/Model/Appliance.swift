/// Aparelho da conta SmartHome. Campos como em `list_appliances`
/// (sususweet/midea_auto_cloud @ ce0c4b88224def0f6b53714312c19f71aa9c2a50,
/// custom_components/midea_auto_cloud/core/cloud.py, Apache-2.0).
public struct Appliance: Codable, Sendable, Equatable, Identifiable {
    public let id: Int64
    public let name: String
    /// Tipo numérico (0xAC = ar-condicionado).
    public let type: Int
    /// Número de série já decifrado.
    public let sn: String
    public let modelNumber: String
    public let manufacturerCode: String
    public let online: Bool

    public init(
        id: Int64, name: String, type: Int, sn: String,
        modelNumber: String, manufacturerCode: String, online: Bool
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.sn = sn
        self.modelNumber = modelNumber
        self.manufacturerCode = manufacturerCode
        self.online = online
    }
}
