import Foundation
import Testing
@testable import ArCore

fileprivate final class FakeControl: ACControlling, @unchecked Sendable {
    private let lock = NSLock()
    var statusResult: Result<ACStatus, Error>
    var sendError: Error?
    private var _sent: [ACCommand] = []
    var sent: [ACCommand] { lock.withLock { _sent } }

    init(isOn: Bool? = false, sendError: Error? = nil) {
        statusResult = isOn.map { .success(ACStatus(isOn: $0, mode: "cool", targetTemperature: 23, indoorTemperature: nil)) }
            ?? .failure(MideaCloudError.network)
        self.sendError = sendError
    }
    func status() async throws -> ACStatus { try statusResult.get() }
    func send(_ command: ACCommand) async throws {
        lock.withLock { _sent.append(command) }
        if let sendError { throw sendError }
    }
}

fileprivate final class FakeNotifier: AutomationNotifying, @unchecked Sendable {
    private let lock = NSLock()
    private var _items: [[String]] = []
    var items: [[String]] { lock.withLock { _items } }
    func notify(title: String, body: String) async { lock.withLock { _items.append([title, body]) } }
}

@Suite struct AutomationCoordinatorTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    init() { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }

    fileprivate func make(_ control: FakeControl, departureRadius: Double = 2000, stateName: String = "state.json")
        -> (AutomationCoordinator, HistoryStore, FakeNotifier) {
        let history = HistoryStore(fileURL: dir.appendingPathComponent("h.json"))
        let notifier = FakeNotifier()
        var s = AutomationSettings(enabled: true, home: Coordinate(latitude: 1, longitude: 2))
        s.departureRadius = departureRadius
        let settings = s
        let c = AutomationCoordinator(control: control, history: history, notifier: notifier,
                                      settings: { settings }, stateURL: dir.appendingPathComponent(stateName))
        return (c, history, notifier)
    }

    fileprivate func arrive(_ c: AutomationCoordinator) async {
        await c.handle(.exitedArrival, at: t0)
        await c.handle(.enteredArrival, at: t0.addingTimeInterval(3600))
    }

    @Test func turnOnSkipsWhenAlreadyOn() async {
        let control = FakeControl(isOn: true)
        let (c, history, notifier) = make(control)
        await arrive(c)
        #expect(control.sent.isEmpty)
        #expect(notifier.items.isEmpty)
        let e = await history.entries()
        #expect(e.contains { $0.event == .autoTurnOn(temperature: 23) && $0.outcome == .skipped(reason: "já estava ligado") })
    }

    @Test func turnOnSendsAndNotifies() async {
        let control = FakeControl(isOn: false)
        let (c, history, notifier) = make(control)
        await arrive(c)
        #expect(control.sent == [.turnOn(temperature: 23)])
        #expect(notifier.items == [["Liguei o ar (23 °C)", "Você está chegando em casa."]])
        let e = await history.entries()
        #expect(e.contains { $0.event == .autoTurnOn(temperature: 23) && $0.outcome == .ok })
        #expect(e.contains { $0.event == .enteredArrival && $0.outcome == .ok })
        #expect(e.contains { $0.event == .exitedArrival && $0.outcome == .ok })
    }

    @Test func statusFailureStillSends() async {
        let control = FakeControl(isOn: nil)
        let (c, _, _) = make(control)
        await arrive(c)
        #expect(control.sent == [.turnOn(temperature: 23)])
    }

    @Test func turnOffSkipsWhenAlreadyOff() async {
        let control = FakeControl(isOn: false)
        let (c, history, _) = make(control)
        await c.handle(.exitedDeparture, at: t0)
        #expect(control.sent.isEmpty)
        let e = await history.entries()
        #expect(e.contains { $0.event == .autoTurnOff && $0.outcome == .skipped(reason: "já estava desligado") })
    }

    @Test func turnOffNotifiesWithRadius() async {
        let c1 = FakeControl(isOn: true)
        let (a, _, n1) = make(c1)
        await a.handle(.exitedDeparture, at: t0)
        #expect(c1.sent == [.turnOff])
        #expect(n1.items == [["Desliguei o ar", "Você passou de 2 km de casa."]])

        let c2 = FakeControl(isOn: true)
        let (b, _, n2) = make(c2, departureRadius: 500)
        await b.handle(.exitedDeparture, at: t0)
        #expect(n2.items == [["Desliguei o ar", "Você passou de 500 m de casa."]])

        let (c, _, n3) = make(FakeControl(isOn: true), departureRadius: 2500)
        await c.handle(.exitedDeparture, at: t0)
        #expect(n3.items.first?[1] == "Você passou de 2,5 km de casa.")
    }

    @Test func sendFailureNotifiesError() async {
        let control = FakeControl(isOn: false, sendError: MideaCloudError.applianceOffline)
        let (c, history, notifier) = make(control)
        await arrive(c)
        #expect(notifier.items == [["Não consegui ligar o ar", "O ar está offline"]])
        let e = await history.entries()
        #expect(e.contains { $0.event == .autoTurnOn(temperature: 23) && $0.outcome == .failed(message: "O ar está offline") })
    }

    @Test func turnOffFailureAndUnexpectedError() async {
        struct Boom: Error {}
        let control = FakeControl(isOn: true, sendError: Boom())
        let (c, _, notifier) = make(control)
        await c.handle(.exitedDeparture, at: t0)
        #expect(notifier.items == [["Não consegui desligar o ar", "Erro inesperado"]])
    }

    @Test func statePersistsAcrossInstances() async {
        let (a, _, _) = make(FakeControl(isOn: false))
        await a.handle(.exitedArrival, at: t0)
        let control = FakeControl(isOn: false)
        let (b, _, _) = make(control)
        await b.handle(.enteredArrival, at: t0.addingTimeInterval(3600))
        #expect(control.sent == [.turnOn(temperature: 23)])
    }

    @Test func resetForNewHomeClearsState() async {
        let control = FakeControl(isOn: false)
        let (c, _, _) = make(control)
        await c.handle(.exitedArrival, at: t0)
        await c.resetForNewHome()
        await c.handle(.enteredArrival, at: t0.addingTimeInterval(3600))
        #expect(control.sent.isEmpty)
        let (d, _, _) = make(control)
        await d.handle(.enteredArrival, at: t0.addingTimeInterval(7200))
        #expect(control.sent.isEmpty)
    }

    @Test func lastArrivalExitFollowsEvents() async {
        let (c, _, _) = make(FakeControl(isOn: false))
        #expect(await c.lastArrivalExit() == nil)
        await c.handle(.exitedArrival, at: t0)
        #expect(await c.lastArrivalExit() == t0)
        await c.handle(.enteredArrival, at: t0.addingTimeInterval(3600))
        #expect(await c.lastArrivalExit() == nil)
        await c.handle(.exitedArrival, at: t0)
        await c.resetForNewHome()
        #expect(await c.lastArrivalExit() == nil)
    }

    @Test func radiusTextFormatsMetersAndKilometers() {
        #expect(AutomationCoordinator.radiusText(450) == "450 m")
        #expect(AutomationCoordinator.radiusText(2000) == "2 km")
        #expect(AutomationCoordinator.radiusText(2540) == "2,5 km")
    }
}
