import SwiftUI
import AppKit
import ArCore

/// Rótulo da barra de menus: "❄︎ 23°" quando ligado; símbolo apagado quando desligado ou desconhecido.
struct MenuBarLabel: View {
    let control: ControlViewModel

    var body: some View {
        if control.status?.isOn == true, let temperature = control.displayedTemperature {
            Text("❄︎ \(temperature)°")
        } else {
            Text("❄︎").foregroundStyle(.secondary)
        }
    }
}

/// Painel da barra de menus: estado, temperatura, ligar/desligar e atalhos.
struct MenuPanel: View {
    let model: MacAppModel
    @Environment(\.openWindow) private var openWindow

    private var control: ControlViewModel { model.control }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if model.isSignedIn {
                controls
            } else {
                Text("Entre com a conta Midea para controlar o ar.")
                    .font(Theme.font(11)).foregroundStyle(Theme.secondary)
            }
            if let message = control.errorMessage {
                Text(message).font(Theme.font(11)).foregroundStyle(Theme.error)
            }
            Divider().overlay(Theme.border)
            VStack(alignment: .leading, spacing: 8) {
                row("Conta Midea…") {
                    NSApp.activate()
                    openWindow(id: "conta")
                }
                Toggle("Abrir ao iniciar o Mac", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.checkbox)
                .font(Theme.font(12))
                if let message = model.loginItemError {
                    Text(message).font(Theme.font(11)).foregroundStyle(Theme.error)
                }
                row("Sair do app") { NSApplication.shared.terminate(nil) }
            }
        }
        .foregroundStyle(Theme.text)
        .padding(14)
        .frame(width: 260)
        .background(Theme.background)
        .onAppear { Task { await model.refresh() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.applianceName ?? "Ar").font(Theme.font(14, weight: .semibold))
            Text(stateLine).font(Theme.font(11)).foregroundStyle(Theme.secondary)
        }
    }

    private var stateLine: String {
        guard model.isSignedIn else { return "Sem conta" }
        guard let status = control.status else { return "Aguardando o ar…" }
        return status.isOn ? "Ligado" : "Desligado"
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                step("−", label: "Diminuir temperatura") { control.decrement() }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(control.displayedTemperature.map(String.init) ?? "--")
                        .font(Theme.font(40, weight: .light))
                    Text("°C").font(Theme.font(15)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                step("+", label: "Aumentar temperatura") { control.increment() }
            }
            Button {
                Task { await control.togglePower() }
            } label: {
                Text(control.isBusy ? "Enviando…" : powerTitle)
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x141414))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(Theme.inverse, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(control.isBusy || control.status == nil)
            .opacity(control.status == nil ? 0.5 : 1)
        }
    }

    private var powerTitle: String {
        guard let status = control.status else { return "Aguardando o ar…" }
        return status.isOn ? "⏻  Desligar" : "⏻  Ligar"
    }

    private func step(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol).font(Theme.font(20))
                .frame(width: 38, height: 38)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(control.status == nil)
        .accessibilityLabel(label)
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.font(12)).frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Janela "Conta Midea": entrar ou sair da conta.
struct AccountWindow: View {
    let model: MacAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?

    var body: some View {
        VStack(spacing: 0) {
            SignInView(
                signIn: { try await model.service.signIn(account: $0, password: $1) },
                select: { try await model.service.select($0) },
                onDone: {
                    model.reloadSession()
                    dismiss()
                }
            )
            if model.isSignedIn {
                VStack(spacing: 6) {
                    Button("Sair da conta") {
                        Task {
                            do { try await model.signOut() } catch { signOutError = "Não foi possível sair da conta" }
                        }
                    }
                    if let signOutError {
                        Text(signOutError).font(Theme.font(11)).foregroundStyle(Theme.error)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
            }
        }
        .frame(width: 340, height: 420)
    }
}
