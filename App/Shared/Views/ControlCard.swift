import SwiftUI
import ArCore

/// Cartão "Controle": temperatura com − / +, bloco claro ligar/desligar e o resultado da ação.
struct ControlCard: View {
    let control: ControlViewModel
    @State private var showSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Controle").font(Theme.font(13, weight: .semibold))
                Spacer()
                Text(chipText)
                    .font(Theme.font(10))
                    .foregroundStyle(Theme.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
            }

            HStack {
                stepButton("−", label: "Diminuir temperatura") { control.decrement() }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(control.displayedTemperature.map(String.init) ?? "--")
                        .font(Theme.font(64, weight: .light))
                    Text("°C").font(Theme.font(22)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                stepButton("+", label: "Aumentar temperatura") { control.increment() }
            }
            .foregroundStyle(Theme.text)

            Button {
                Task { await control.togglePower() }
            } label: {
                Text(control.isBusy ? "Enviando…" : powerTitle)
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x141414))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.inverse, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(control.isBusy || control.status == nil)
            .opacity(control.status == nil ? 0.5 : 1)

            feedback
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        .onChange(of: control.isBusy) { wasBusy, isBusy in
            guard wasBusy, !isBusy, control.errorMessage == nil else { return }
            showSent = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                showSent = false
            }
        }
    }

    private var powerTitle: String {
        guard let status = control.status else { return "Aguardando o ar…" }
        return status.isOn ? "⏻  Desligar" : "⏻  Ligar"
    }

    private var chipText: String {
        guard let status = control.status else { return "—" }
        return "\(Self.modeName(status.mode)) · vent. auto"
    }

    @ViewBuilder private var feedback: some View {
        if let message = control.errorMessage {
            Text(message).font(Theme.font(11)).foregroundStyle(Theme.error)
        } else if control.isBusy {
            Text("Enviando…").font(Theme.font(11)).foregroundStyle(Theme.secondary)
        } else if control.pendingTemperature != nil {
            Text("Enviando a temperatura em instantes…").font(Theme.font(11)).foregroundStyle(Theme.secondary)
        } else if showSent {
            Text("Enviado").font(Theme.font(11)).foregroundStyle(Theme.ok)
        }
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(Theme.font(22))
                .foregroundStyle(Theme.text)
                .frame(width: 46, height: 46)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(control.status == nil)
        .accessibilityLabel(label)
    }

    private static func modeName(_ mode: String) -> String {
        switch mode {
        case "cool": "Refrigerar"
        case "heat": "Aquecer"
        case "dry": "Desumidificar"
        case "fan_only": "Ventilar"
        case "auto": "Automático"
        default: mode
        }
    }
}
