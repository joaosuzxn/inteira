import CoreLocation
import Observation
import os

/// Permissão de localização e leitura avulsa da posição (para "usar minha localização atual" e a
/// distância até casa). O monitoramento de região em si fica no `RegionMonitor`.
@MainActor @Observable
final class LocationAccess: NSObject, CLLocationManagerDelegate {
    private(set) var status: CLAuthorizationStatus
    /// Chamado quando a permissão muda (o app religa ou desliga o monitor).
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var upgradeToAlways = false

    var isAlways: Bool { status == .authorizedAlways }
    var canReadLocation: Bool { status == .authorizedAlways || status == .authorizedWhenInUse }

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    /// Pede "Sempre". O iOS exige passar antes por "Durante o uso": se ainda não perguntou, pede
    /// esse primeiro e, aceito, pede "Sempre" em seguida. Se o dono já negou, não há o que pedir.
    func requestAlways() {
        switch manager.authorizationStatus {
        case .notDetermined:
            upgradeToAlways = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // O gerenciador foi criado na thread principal; o iOS chama o delegado nela.
        MainActor.assumeIsolated { authorizationChanged() }
    }

    private func authorizationChanged() {
        let current = manager.authorizationStatus
        if upgradeToAlways, current == .authorizedWhenInUse {
            upgradeToAlways = false
            manager.requestAlwaysAuthorization()
        }
        guard current != status else { return }
        status = current
        onChange?()
    }

    /// Uma leitura da posição: a primeira com precisão até `accuracy` metros; ao fim do prazo, a melhor
    /// que chegou (ou nada, sem permissão).
    func currentLocation(accuracy: Double, timeout: Duration = .seconds(15)) async -> CLLocation? {
        let best = OSAllocatedUnfairLock<CLLocation?>(initialState: nil)
        return await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if update.authorizationDenied || update.authorizationDeniedGlobally
                            || update.authorizationRestricted { return nil }
                        guard let location = update.location, location.horizontalAccuracy >= 0 else { continue }
                        if location.horizontalAccuracy <= accuracy { return location }
                        best.withLock { current in
                            if current == nil || location.horizontalAccuracy < current!.horizontalAccuracy {
                                current = location
                            }
                        }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return best.withLock { $0 }
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
