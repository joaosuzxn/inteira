import Foundation
import Testing
@testable import ArCore

@Suite struct AutomationEngineTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    let home = Coordinate(latitude: -23.5, longitude: -46.6)

    func settings(enabled: Bool = true, home: Coordinate? = Coordinate(latitude: -23.5, longitude: -46.6)) -> AutomationSettings {
        AutomationSettings(enabled: enabled, home: home)
    }

    @Test func exitThenEnterAfter31MinTurnsOn() {
        var state = AutomationState()
        _ = AutomationEngine.decide(.exitedArrival, at: t0, settings: settings(), state: &state)
        let d = AutomationEngine.decide(.enteredArrival, at: t0.addingTimeInterval(31 * 60), settings: settings(), state: &state)
        #expect(d == .turnOnIfOff(temperature: 23))
    }

    @Test func after29MinDoesNothing() {
        var state = AutomationState()
        _ = AutomationEngine.decide(.exitedArrival, at: t0, settings: settings(), state: &state)
        let d = AutomationEngine.decide(.enteredArrival, at: t0.addingTimeInterval(29 * 60), settings: settings(), state: &state)
        #expect(d == .none)
    }

    @Test func enterWithoutRecordedExitDoesNothing() {
        var state = AutomationState()
        #expect(AutomationEngine.decide(.enteredArrival, at: t0, settings: settings(), state: &state) == .none)
    }

    @Test func secondEnterWithoutNewExitDoesNothing() {
        var state = AutomationState()
        _ = AutomationEngine.decide(.exitedArrival, at: t0, settings: settings(), state: &state)
        _ = AutomationEngine.decide(.enteredArrival, at: t0.addingTimeInterval(3600), settings: settings(), state: &state)
        let d = AutomationEngine.decide(.enteredArrival, at: t0.addingTimeInterval(7200), settings: settings(), state: &state)
        #expect(d == .none)
        #expect(state.lastArrivalExit == nil)
    }

    @Test func exitDepartureTurnsOffImmediately() {
        var state = AutomationState()
        #expect(AutomationEngine.decide(.exitedDeparture, at: t0, settings: settings(), state: &state) == .turnOffIfOn)
    }

    @Test func enteredDepartureDoesNothing() {
        var state = AutomationState()
        #expect(AutomationEngine.decide(.enteredDeparture, at: t0, settings: settings(), state: &state) == .none)
    }

    @Test func disabledOrNoHomeDoesNothing() {
        let events: [RegionEvent] = [.enteredArrival, .exitedArrival, .enteredDeparture, .exitedDeparture]
        for s in [settings(enabled: false), settings(home: nil)] {
            for e in events {
                var state = AutomationState(lastArrivalExit: t0)
                #expect(AutomationEngine.decide(e, at: t0.addingTimeInterval(7200), settings: s, state: &state) == .none)
            }
        }
    }

    @Test func settingsAreClamped() {
        var s = AutomationSettings()
        s.arrivalRadius = 50
        s.autoTemperature = 40
        s.departureRadius = 500
        let c = s.clamped()
        #expect(c.arrivalRadius == 200)
        #expect(c.autoTemperature == 30)
        s.arrivalRadius = 2000
        #expect(s.departureSmallerThanArrival)
    }
}
