import Foundation

/// Envia um POST e devolve o corpo da resposta. Injetável para os testes nunca tocarem a nuvem real.
public protocol HTTPTransport: Sendable {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
}

/// Transporte real sobre `URLSession`, com timeout de 30 s.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.httpBody = body
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        let (data, _) = try await session.data(for: request)
        return data
    }
}
