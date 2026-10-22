import CoreLocation
import ArCore

/// Vigia os dois círculos em volta de casa com o `CLMonitor` e repassa cada entrada ou saída na hora.
///
/// O monitor tem nome fixo ("ar"): o iOS guarda as condições e, quando relança o app em segundo plano,
/// entrega o evento ao monitor reaberto com o mesmo nome. Por isso ele é criado na abertura do app.
actor RegionMonitor {
    static let arrivalID = "chegada"
    static let departureID = "saida"
    private static let monitorName = "ar"
    /// Condições recém-adicionadas cujo primeiro evento ainda não chegou (guardado no aparelho).
    private static let pendingKey = "regionMonitor.awaitingFirstEvent"
    /// Há condições gravadas no monitor do sistema (para limpá-las mesmo depois de reabrir o app).
    private static let installedKey = "regionMonitor.conditionsInstalled"

    private let onEvent: @Sendable (RegionEvent, Date) async -> Void
    private var monitor: CLMonitor?
    private var session: CLServiceSession?
    private var eventsTask: Task<Void, Never>?

    init(onEvent: @escaping @Sendable (RegionEvent, Date) async -> Void) {
        self.onEvent = onEvent
    }

    /// Liga, atualiza ou desliga o monitoramento conforme os ajustes. Quem chama garante a permissão
    /// "Sempre": sem ela, passa os ajustes com `enabled == false`.
    func apply(_ settings: AutomationSettings) async {
        let settings = settings.clamped()
        guard settings.enabled, let home = settings.home else {
            await stop()
            return
        }
        // No iOS 18, a permissão "Sempre" só vale em segundo plano com uma sessão explícita.
        if session == nil { session = CLServiceSession(authorization: .always) }
        let monitor = await openMonitor()
        startEvents(from: monitor)
        UserDefaults.standard.set(true, forKey: Self.installedKey)
        let center = CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
        await ensure(Self.arrivalID, center: center, radius: settings.arrivalRadius, in: monitor)
        await ensure(Self.departureID, center: center, radius: settings.departureRadius, in: monitor)
    }

    // MARK: - Monitor

    private func openMonitor() async -> CLMonitor {
        if let monitor { return monitor }
        let opened = await CLMonitor(Self.monitorName)
        monitor = opened
        return opened
    }

    private func startEvents(from monitor: CLMonitor) {
        guard eventsTask == nil else { return }
        eventsTask = Task { [weak self] in
            do {
                for try await event in await monitor.events {
                    await self?.deliver(event)
                }
            } catch {}
        }
    }

    /// Mantém a condição se ela já está com o mesmo centro e raio (relançamento do app); senão recria.
    private func ensure(_ id: String, center: CLLocationCoordinate2D, radius: Double, in monitor: CLMonitor) async {
        if let record = await monitor.record(for: id),
           let current = record.condition as? CLMonitor.CircularGeographicCondition,
           abs(current.center.latitude - center.latitude) < 1e-7,
           abs(current.center.longitude - center.longitude) < 1e-7,
           abs(current.radius - radius) < 0.5 {
            return
        }
        await monitor.remove(id)
        setAwaitingFirstEvent(id, true)
        await monitor.add(CLMonitor.CircularGeographicCondition(center: center, radius: radius), identifier: id)
    }

    private func stop() async {
        eventsTask?.cancel()
        eventsTask = nil
        if let monitor {
            await monitor.remove(Self.arrivalID)
            await monitor.remove(Self.departureID)
        } else if UserDefaults.standard.bool(forKey: Self.installedKey) {
            // Aberto com o automático desligado (ou sem "Sempre"): apaga condições que sobraram de antes.
            let leftover = await CLMonitor(Self.monitorName)
            await leftover.remove(Self.arrivalID)
            await leftover.remove(Self.departureID)
        }
        monitor = nil
        UserDefaults.standard.set(false, forKey: Self.installedKey)
        session?.invalidate()
        session = nil
        setAwaitingFirstEvent(Self.arrivalID, false)
        setAwaitingFirstEvent(Self.departureID, false)
    }

    // MARK: - Eventos

    private func deliver(_ event: CLMonitor.Event) async {
        let satisfied: Bool
        switch event.state {
        case .satisfied: satisfied = true
        case .unsatisfied: satisfied = false
        default: return
        }
        // O primeiro evento de uma condição recém-adicionada só informa onde o iPhone está agora,
        // não uma entrada ou saída de verdade: é descartado. Assim, configurar a casa estando fora não
        // registra uma saída falsa (nem desliga o ar), e estando em casa não registra uma chegada falsa.
        if isAwaitingFirstEvent(event.identifier) {
            setAwaitingFirstEvent(event.identifier, false)
            return
        }
        let mapped: RegionEvent
        switch event.identifier {
        case Self.arrivalID: mapped = satisfied ? .enteredArrival : .exitedArrival
        case Self.departureID: mapped = satisfied ? .enteredDeparture : .exitedDeparture
        default: return
        }
        await onEvent(mapped, event.date)
    }

    private func isAwaitingFirstEvent(_ id: String) -> Bool {
        UserDefaults.standard.stringArray(forKey: Self.pendingKey)?.contains(id) ?? false
    }

    private func setAwaitingFirstEvent(_ id: String, _ awaiting: Bool) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: Self.pendingKey) ?? [])
        if awaiting { ids.insert(id) } else { ids.remove(id) }
        UserDefaults.standard.set(ids.sorted(), forKey: Self.pendingKey)
    }
}
