import SwiftUI
import ArCore

/// Ajustes (spec §8). Os controles mexem num rascunho local e só gravam ao soltar,
/// para não disparar a reconfiguração do monitor a cada pixel do slider.
struct SettingsView: View {
    let model: AppModel
    @State private var draft = AutomationSettings()
    @State private var confirmSignOut = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 10) {
                    automaticSection
                    accountSection
                }
                .padding(16)
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = model.settings }
        .confirmationDialog("Sair da conta?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sair da conta", role: .destructive) { Task { await signOut() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("A senha guardada no Keychain será apagada.")
        }
    }

    private var automaticSection: some View {
        section("Automático") {
            Toggle(isOn: Binding(get: { draft.enabled }, set: { draft.enabled = $0; commit() })) {
                label("Ligar e desligar sozinho")
            }
            .tint(Theme.ok)

            slider(
                "Raio de chegada", value: Binding(get: { draft.arrivalRadius }, set: { draft.arrivalRadius = $0 }),
                range: AutomationSettings.radiusRange, step: 100, text: MainView.distance(draft.arrivalRadius))
            slider(
                "Raio de saída", value: Binding(get: { draft.departureRadius }, set: { draft.departureRadius = $0 }),
                range: AutomationSettings.radiusRange, step: 100, text: MainView.distance(draft.departureRadius))
            if draft.departureSmallerThanArrival {
                Text("O raio de saída é menor que o de chegada")
                    .font(Theme.font(11)).foregroundStyle(Theme.error)
            }
            slider(
                "Tempo fora para ligar", value: Binding(get: { draft.minAbsenceForArrival }, set: { draft.minAbsenceForArrival = $0 }),
                range: AutomationSettings.absenceRange, step: 300, text: MainView.minutes(draft.minAbsenceForArrival))

            Stepper(
                value: Binding(get: { draft.autoTemperature }, set: { draft.autoTemperature = $0; commit() }),
                in: ACCommand.temperatureRange
            ) {
                HStack {
                    label("Temperatura ao ligar")
                    Spacer()
                    Text("\(draft.autoTemperature) °C").font(Theme.font(13, weight: .medium))
                }
            }
        }
    }

    private var accountSection: some View {
        section("Conta SmartHome") {
            if let account = model.accountName {
                Text(account).font(Theme.font(12)).foregroundStyle(Theme.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(Theme.font(11)).foregroundStyle(Theme.error)
            }
            Button {
                confirmSignOut = true
            } label: {
                Text("Sair da conta")
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Theme.error)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Peças

    private func commit() {
        model.updateSettings { $0 = draft }
        draft = model.settings
    }

    private func signOut() async {
        do {
            try await model.signOut()
        } catch {
            errorMessage = "Não foi possível sair da conta"
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(Theme.font(13)).foregroundStyle(Theme.text)
    }

    private func slider(
        _ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                label(title)
                Spacer()
                Text(text).font(Theme.font(13, weight: .medium)).foregroundStyle(Theme.text)
            }
            Slider(value: value, in: range, step: step) { editing in
                if !editing { commit() }
            }
            .tint(Theme.inverse)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Theme.font(13, weight: .semibold)).foregroundStyle(Theme.text)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
