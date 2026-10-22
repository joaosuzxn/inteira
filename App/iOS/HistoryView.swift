import SwiftUI
import ArCore

/// Contas puras do histórico, separadas das telas.
enum HistoryFormat {
    /// 28 dias, do mais antigo ao de hoje (14 por linha). Dia "ligado" = ligou, sozinho ou à mão, com sucesso.
    static func usageDays(
        from entries: [HistoryEntry], now: Date = Date(), calendar: Calendar = .current
    ) -> [Bool] {
        let today = calendar.startOfDay(for: now)
        let onDays = Set(entries.filter { isTurnOn($0) }.map { calendar.startOfDay(for: $0.date) })
        return (0..<28).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 27, to: today) else { return false }
            return onDays.contains(day)
        }
    }

    private static func isTurnOn(_ entry: HistoryEntry) -> Bool {
        guard entry.outcome == .ok else { return false }
        switch entry.event {
        case .autoTurnOn, .manual(.turnOn): return true
        default: return false
        }
    }

    static func eventText(_ event: HistoryEvent) -> String {
        switch event {
        case .enteredArrival: "entrou no raio de chegada"
        case .exitedArrival: "saiu do raio de chegada"
        case .exitedDeparture: "saiu do raio de saída"
        case .autoTurnOn(let temperature): "ligou ao chegar (\(temperature)°)"
        case .autoTurnOff: "desligou ao sair"
        case .manual(.turnOn(let temperature)): "ligou (manual, \(temperature)°)"
        case .manual(.turnOff): "desligou (manual)"
        case .manual(.setTemperature(let temperature)): "ajustou para \(temperature)° (manual)"
        }
    }

    /// Texto curto do resultado e se é sucesso, erro ou neutro.
    static func outcome(_ outcome: HistoryOutcome) -> (text: String, color: Color) {
        switch outcome {
        case .ok: ("ok", Theme.ok)
        case .skipped: ("ignorado", Theme.secondary)
        case .failed: ("erro", Theme.error)
        }
    }

    /// Motivo completo, quando houver.
    static func detail(_ outcome: HistoryOutcome) -> String? {
        switch outcome {
        case .ok: nil
        case .skipped(let reason): reason
        case .failed(let message): message
        }
    }

    static func time(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        if calendar.isDate(date, inSameDayAs: now) { return hour }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ontem \(hour)"
        }
        return date.formatted(.dateTime.day(.twoDigits).month(.twoDigits)) + " " + hour
    }
}

/// Histórico completo (spec §9), mais recente primeiro.
struct HistoryView: View {
    let model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                if model.entries.isEmpty {
                    Text("Nada registrado ainda")
                        .font(Theme.font(12)).foregroundStyle(Theme.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(model.entries) { entry in
                            row(entry)
                        }
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    .padding(16)
                }
            }
        }
        .navigationTitle("Histórico")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.reloadHistory() }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let result = HistoryFormat.outcome(entry.outcome)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Text("\(HistoryFormat.time(entry.date)) \(HistoryFormat.eventText(entry.event))")
                    .font(Theme.font(11)).foregroundStyle(Theme.text)
                Spacer(minLength: 8)
                Text(result.text).font(Theme.font(11)).foregroundStyle(result.color)
            }
            if let detail = HistoryFormat.detail(entry.outcome) {
                Text(detail).font(Theme.font(10)).foregroundStyle(Theme.secondary)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .top) {
            Rectangle().stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
        }
    }
}
