import Foundation

public struct Coordinate: Codable, Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Ajustes da automação por localização. Raios em metros, tempo em segundos.
public struct AutomationSettings: Codable, Sendable, Equatable {
    public static let radiusRange = 200.0...20000.0
    public static let absenceRange = 0.0...14400.0

    public var enabled: Bool
    public var home: Coordinate?
    public var arrivalRadius: Double
    public var departureRadius: Double
    public var minAbsenceForArrival: Double
    public var autoTemperature: Int

    public init(
        enabled: Bool = false, home: Coordinate? = nil,
        arrivalRadius: Double = 2000, departureRadius: Double = 2000,
        minAbsenceForArrival: Double = 1800, autoTemperature: Int = 23
    ) {
        self.enabled = enabled
        self.home = home
        self.arrivalRadius = arrivalRadius
        self.departureRadius = departureRadius
        self.minAbsenceForArrival = minAbsenceForArrival
        self.autoTemperature = autoTemperature
    }

    /// Cópia com todos os valores dentro das faixas permitidas.
    public func clamped() -> Self {
        var copy = self
        copy.arrivalRadius = min(max(arrivalRadius, Self.radiusRange.lowerBound), Self.radiusRange.upperBound)
        copy.departureRadius = min(max(departureRadius, Self.radiusRange.lowerBound), Self.radiusRange.upperBound)
        copy.minAbsenceForArrival = min(max(minAbsenceForArrival, Self.absenceRange.lowerBound), Self.absenceRange.upperBound)
        copy.autoTemperature = min(max(autoTemperature, ACCommand.temperatureRange.lowerBound), ACCommand.temperatureRange.upperBound)
        return copy
    }

    /// Raio de saída menor que o de chegada: o app avisa o dono, mas aceita.
    public var departureSmallerThanArrival: Bool { departureRadius < arrivalRadius }
}
