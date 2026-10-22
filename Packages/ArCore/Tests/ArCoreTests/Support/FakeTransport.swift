import Foundation
@testable import ArCore

/// Transporte falso: grava as requisições e devolve respostas enfileiradas por endpoint (`alias=`).
/// Sem resposta na fila, lança `URLError(.notConnectedToInternet)`. Nunca toca a rede.
actor FakeTransport: HTTPTransport {
    struct Recorded: Sendable {
        let url: URL
        let headers: [String: String]
        let body: Data

        /// Endpoint depois de `alias=`.
        var alias: String {
            let text = url.absoluteString
            guard let range = text.range(of: "alias=") else { return text }
            return String(text[range.upperBound...])
        }

        var bodyText: String { String(data: body, encoding: .utf8) ?? "" }

        var bodyJSON: [String: Any] {
            (try? JSONSerialization.jsonObject(with: body) as? [String: Any]) ?? [:]
        }
    }

    enum Reply: Sendable {
        case body(Data)
        case failure
    }

    private(set) var requests: [Recorded] = []
    private var queues: [String: [Reply]] = [:]

    private var gated: Set<String> = []
    private var held: [String: [CheckedContinuation<Void, Never>]] = [:]

    /// Segura as próximas chamadas ao endpoint até `release`.
    func gate(_ alias: String) { gated.insert(alias) }

    func heldCount(_ alias: String) -> Int { held[alias]?.count ?? 0 }

    /// Solta as chamadas seguradas e desfaz o gate.
    func release(_ alias: String) {
        gated.remove(alias)
        let waiting = held.removeValue(forKey: alias) ?? []
        for continuation in waiting { continuation.resume() }
    }

    func enqueue(_ alias: String, _ json: String) {
        queues[alias, default: []].append(.body(Data(json.utf8)))
    }

    func enqueueFailure(_ alias: String) {
        queues[alias, default: []].append(.failure)
    }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        let recorded = Recorded(url: url, headers: headers, body: body)
        requests.append(recorded)
        guard var queue = queues[recorded.alias], !queue.isEmpty else {
            throw URLError(.notConnectedToInternet)
        }
        let reply = queue.removeFirst()
        queues[recorded.alias] = queue
        if gated.contains(recorded.alias) {
            await withCheckedContinuation { held[recorded.alias, default: []].append($0) }
        }
        switch reply {
        case .body(let data): return data
        case .failure: throw URLError(.notConnectedToInternet)
        }
    }
}
