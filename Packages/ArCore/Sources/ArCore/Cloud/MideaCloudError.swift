/// Erros do cliente da nuvem Midea.
public enum MideaCloudError: Error, Equatable, Sendable {
    case invalidCredentials
    case tokenInvalid
    case reloginThrottled
    case applianceOffline
    case network
    case unexpectedResponse(code: Int, message: String)

    /// Texto para o dono, em português.
    public var userMessage: String {
        switch self {
        case .invalidCredentials: "A Midea recusou o login — confira a senha"
        case .tokenInvalid, .reloginThrottled: "Sessão da Midea expirou — tente de novo em 1 minuto"
        case .applianceOffline: "O ar está offline"
        case .network: "Sem internet"
        case .unexpectedResponse: "A Midea mudou algo e o app precisa de atualização"
        }
    }
}
