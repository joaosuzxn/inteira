import Foundation

/// O que aconteceu.
public enum HistoryEvent: Codable, Sendable, Equatable {
    case enteredArrival, exitedArrival, exitedDeparture
    case autoTurnOn(temperature: Int)
    case autoTurnOff
    case manual(ACCommand)
}

/// Como terminou.
public enum HistoryOutcome: Codable, Sendable, Equatable {
    case ok
    case skipped(reason: String)
    case failed(message: String)
}

public struct HistoryEntry: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let event: HistoryEvent
    public let outcome: HistoryOutcome

    public init(id: UUID = UUID(), date: Date = Date(), event: HistoryEvent, outcome: HistoryOutcome) {
        self.id = id
        self.date = date
        self.event = event
        self.outcome = outcome
    }
}

/// Histórico em JSON no disco: mais recente primeiro, no máximo 200 entradas.
public actor HistoryStore {
    private static let limit = 200
    private let fileURL: URL
    private var items: [HistoryEntry]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? Data(contentsOf: fileURL)).flatMap { try? decoder.decode([HistoryEntry].self, from: $0) } ?? []
    }

    public func append(_ entry: HistoryEntry) {
        items.insert(entry, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Falha ao gravar não derruba a ação que está sendo registrada.
        if let data = try? encoder.encode(items) { try? data.write(to: fileURL, options: .atomic) }
    }

    public func entries() -> [HistoryEntry] { items }
}
