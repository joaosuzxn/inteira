import SwiftUI
import ArCore

/// Tela principal: cabeçalho, controle, automático e uso.
struct MainView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 10) {
                        header
                        ControlCard(control: model.control)
                        automaticCard
                        usageCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .refreshable { await model.control.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .settings: SettingsView(model: model)
                case .history: HistoryView(model: model)
                }
            }
        }
        .task {
            await model.control.refresh()
            await model.reloadHistory()
            await model.refreshAutomationStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await model.control.refresh()
                await model.reloadHistory()
                await model.refreshAutomationStatus()
            }
        }
        // O controle grava no histórico; relê quando o estado ou o erro mudam.
        .onChange(of: model.control.status) { _, _ in Task { await model.reloadHistory() } }
        .onChange(of: model.control.errorMessage) { _, _ in Task { await model.reloadHistory() } }
    }

    private enum Destination: Hashable { case settings, history }

    // MARK: Cabeçalho

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.applianceName ?? "Ar").font(Theme.font(15, weight: .semibold))
                statusLine
            }
            Spacer()
            NavigationLink(value: Destination.history) { iconBox("clock") }
                .accessibilityLabel("Histórico")
            NavigationLink(value: Destination.settings) { iconBox("gearshape") }
                .accessibilityLabel("Ajustes")
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 4)
    }

    private var statusLine: some View {
        HStack(spacing: 4) {
            if let status = model.control.status {
                Text("●").foregroundStyle(status.isOn ? Theme.ok : Theme.secondary)
                Text(status.isOn ? "ligado" : "desligado")
                if let indoor = status.indoorTemperature {
                    Text("· ambiente \(Int(indoor.rounded()))°")
                }
            } else {
                Text("lendo o estado…")
            }
        }
        .font(Theme.font(11))
        .foregroundStyle(Theme.secondary)
    }

    private func iconBox(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .light))
            .foregroundStyle(Theme.secondary)
            .frame(width: 30, height: 30)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: Automático

    private var automaticCard: some View {
        let settings = model.settings
        let active = settings.enabled && settings.home != nil && !model.needsAlwaysPermission
        return card(title: "Automático") {
            if model.needsAlwaysPermission {
                chip("sem permissão", color: Theme.error)
            } else {
                chip(active ? "● ativo" : "desligado", color: active ? Theme.ok : Theme.secondary)
            }
        } content: {
            HStack(alignment: .top, spacing: 6) {
                kv("Chegada", Self.distance(settings.arrivalRadius))
                kv("Saída", Self.distance(settings.departureRadius))
                kv("Fora", Self.minutes(settings.minAbsenceForArrival))
            }
            if settings.home != nil {
                HStack(alignment: .top, spacing: 6) {
                    kv("Casa a", model.distanceToHome.map(AutomationCoordinator.radiusText) ?? "—")
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        kv("Fora há", model.lastArrivalExit.map {
                            Self.minutes(max(0, context.date.timeIntervalSince($0)))
                        } ?? "—")
                    }
                }
            }
            if settings.home == nil {
                Text("Configure a casa nos ajustes")
                    .font(Theme.font(11)).foregroundStyle(Theme.secondary)
            }
            if model.needsAlwaysPermission {
                Text("Permissão de localização 'Sempre' necessária")
                    .font(Theme.font(11)).foregroundStyle(Theme.error)
                Button("Abrir Ajustes do iPhone") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(Theme.font(11, weight: .semibold))
                .foregroundStyle(Theme.text)
            }
            if settings.departureSmallerThanArrival {
                Text("O raio de saída é menor que o de chegada")
                    .font(Theme.font(11)).foregroundStyle(Theme.error)
            }
        }
    }

    private func kv(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Theme.font(10)).foregroundStyle(Theme.secondary)
            Text(value).font(Theme.font(16, weight: .medium)).foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Uso

    private var usageCard: some View {
        let days = HistoryFormat.usageDays(from: model.entries)
        return card(title: "Uso nas últimas semanas") {
            chip("4S", color: Theme.secondary)
        } content: {
            VStack(spacing: 3) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<14, id: \.self) { column in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(days[row * 14 + column] ? Theme.inverse : Theme.altSurface)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(model.entries.prefix(3)) { entry in
                    let result = HistoryFormat.outcome(entry.outcome)
                    HStack {
                        Text("\(HistoryFormat.time(entry.date)) \(HistoryFormat.eventText(entry.event))")
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(result.text).foregroundStyle(result.color)
                    }
                    .font(Theme.font(11))
                    .padding(.vertical, 6)
                    .overlay(alignment: .top) {
                        Rectangle().stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
                    }
                }
                if model.entries.isEmpty {
                    Text("Sem eventos ainda").font(Theme.font(11)).foregroundStyle(Theme.secondary)
                }
            }
            .foregroundStyle(Theme.text)
        }
    }

    // MARK: Peças

    private func card<Trailing: View, Content: View>(
        title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(Theme.font(13, weight: .semibold))
                Spacer()
                trailing()
            }
            content()
        }
        .foregroundStyle(Theme.text)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Theme.font(10))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
    }

    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters)) m" }
        let km = meters / 1000
        return km == km.rounded() ? "\(Int(km)) km" : String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
    }

    static func minutes(_ seconds: Double) -> String {
        let total = Int(seconds / 60)
        if total < 60 { return "\(total) min" }
        return total % 60 == 0 ? "\(total / 60) h" : "\(total / 60) h \(total % 60)"
    }
}
