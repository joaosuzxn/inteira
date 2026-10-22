import Foundation
import Testing
@testable import ArCore

/// Compara dicionários heterogêneos pelo valor (NSDictionary).
private func same(_ a: [String: any Sendable], _ b: [String: Any]) -> Bool {
    (a as NSDictionary).isEqual(to: b)
}

@Test func turnOnBuildsFullDesiredState() {
    let expected: [String: Any] = [
        "power": "on", "mode": "cool", "temperature": 23, "small_temperature": 0, "wind_speed": 102,
    ]
    #expect(same(ACCommand.turnOn(temperature: 23).control, expected))
}

@Test func turnOffOnlySetsPower() {
    #expect(same(ACCommand.turnOff.control, ["power": "off"]))
}

@Test func setTemperatureIsClampedToRange() {
    #expect(ACCommand.setTemperature(31).control["temperature"] as? Int == 30)
    #expect(ACCommand.setTemperature(10).control["temperature"] as? Int == 17)
    #expect(ACCommand.temperatureRange == 17...30)
}
