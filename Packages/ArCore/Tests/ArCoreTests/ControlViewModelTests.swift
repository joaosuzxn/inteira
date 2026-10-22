import Foundation
import Testing
@testable import ArCore

fileprivate final class FakeControl: ACControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var _status: ACStatus
    private var _sent: [ACCommand] = []
    private var _statusCalls = 0
    var sendError: Error?
    var sent: [ACCommand] { lock.withLock { _sent } }
    var statusCalls: Int { lock.withLock { _statusCalls } }

    init(isOn: Bool, target: Double = 23, sendError: Error? = nil) {
        _status = ACStatus(isOn: isOn, mode: "cool", targetTemperature: target, indoorTemperature: nil)
        self.sendError = sendError
    }
    func status() async throws -> ACStatus { lock.withLock { _statusCalls += 1; return _status } }
    func send(_ command: ACCommand) async throws {
        lock.withLock { _sent.append(command) }
        if let sendError { throw sendError }
        lock.withLock {
            switch command {
            case .turnOn(let t): _status = ACStatus(isOn: true, mode: "cool", targetTemperature: Double(t), indoorTemperature: nil)
            case .turnOff: _status = ACStatus(isOn: false, mode: "cool", targetTemperature: _status.targetTemperature, indoorTemperature: nil)
            case .setTemperature(let t): _status = ACStatus(isOn: _status.isOn, mode: "cool", targetTemperature: Double(t), indoorTemperature: nil)
            }
        }
    }
}

@MainActor
@Suite struct ControlViewModelTests {
    let clock = TestClock()

    private func make(_ control: FakeControl, history: HistoryStore? = nil) -> ControlViewModel {
        ControlViewModel(control: control, history: history, debounce: .seconds(1), clock: clock)
    }

    /// Cede a vez até a condição valer (sem tempo real; só agenda de tarefas).
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    @Test func tenRapidIncrementsSendOneCommand() async {
        let control = FakeControl(isOn: true, target: 23)
        let model = make(control)
        await model.refresh()
        for _ in 0..<10 { model.increment() }
        #expect(model.pendingTemperature == 30)
        await waitUntil { clock.sleeperCount == 1 }
        clock.advance(by: .seconds(1))
        await waitUntil { model.pendingTemperature == nil }
        #expect(control.sent == [.setTemperature(30)])
        #expect(model.status?.targetTemperature == 30)
        #expect(model.displayedTemperature == 30)
    }

    @Test func decrementClampsAtMinimum() async {
        let control = FakeControl(isOn: true, target: 18)
        let model = make(control)
        await model.refresh()
        for _ in 0..<5 { model.decrement() }
        #expect(model.pendingTemperature == 17)
    }

    @Test func incrementWithoutStatusDoesNothing() {
        let model = make(FakeControl(isOn: true))
        model.increment()
        #expect(model.pendingTemperature == nil)
    }

    @Test func togglePowerWhenOffSendsTurnOnWithCurrentTarget() async {
        let control = FakeControl(isOn: false, target: 25)
        let model = make(control)
        await model.refresh()
        await model.togglePower()
        #expect(control.sent == [.turnOn(temperature: 25)])
        #expect(model.status?.isOn == true)
        #expect(control.statusCalls == 2)
        #expect(model.isBusy == false)
    }

    @Test func togglePowerWhenOnSendsTurnOff() async {
        let control = FakeControl(isOn: true)
        let model = make(control)
        await model.refresh()
        await model.togglePower()
        #expect(control.sent == [.turnOff])
        #expect(model.status?.isOn == false)
    }

    @Test func errorShowsUserMessageAndClearsBusy() async {
        let control = FakeControl(isOn: true, sendError: MideaCloudError.network)
        let model = make(control)
        await model.refresh()
        await model.togglePower()
        #expect(model.errorMessage == "Sem internet")
        #expect(model.isBusy == false)
    }

    @Test func unknownErrorShowsGenericMessage() async {
        struct Boom: Error {}
        let control = FakeControl(isOn: true, sendError: Boom())
        let model = make(control)
        await model.refresh()
        await model.togglePower()
        #expect(model.errorMessage == "Erro inesperado")
    }

    @Test func manualCommandsGoToHistory() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let history = HistoryStore(fileURL: url)
        let ok = make(FakeControl(isOn: true), history: history)
        await ok.refresh()
        await ok.togglePower()
        let bad = make(FakeControl(isOn: true, sendError: MideaCloudError.network), history: history)
        await bad.refresh()
        await bad.togglePower()
        let entries = await history.entries()
        #expect(entries.map(\.event) == [.manual(.turnOff), .manual(.turnOff)])
        #expect(entries.map(\.outcome) == [.failed(message: "Sem internet"), .ok])
    }
}
