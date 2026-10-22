import Foundation
import Testing
@testable import ArCore

@Test func historyKeepsNewestFirstAndCapsAt200() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("history-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    let store = HistoryStore(fileURL: url)
    var last: HistoryEntry?
    for i in 0..<201 {
        let entry = HistoryEntry(
            id: UUID(), date: Date(timeIntervalSince1970: Double(i)),
            event: .autoTurnOn(temperature: 23), outcome: .ok)
        await store.append(entry)
        last = entry
    }
    let entries = await store.entries()
    #expect(entries.count == 200)
    #expect(entries.first == last)
    let reloaded = await HistoryStore(fileURL: url).entries()
    #expect(reloaded == entries)
}

@Test func historyEntryRoundTripsThroughJSON() throws {
    let entry = HistoryEntry(
        id: UUID(), date: Date(timeIntervalSince1970: 10),
        event: .manual(.setTemperature(21)), outcome: .failed(message: "sem internet"))
    let data = try JSONEncoder().encode(entry)
    #expect(try JSONDecoder().decode(HistoryEntry.self, from: data) == entry)
}
