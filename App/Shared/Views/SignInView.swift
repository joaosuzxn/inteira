import SwiftUI
import ArCore

/// Entrada com a conta SmartHome (e-mail e senha) e escolha do aparelho quando há mais de um.
/// Não conhece o app: recebe as ações prontas. A senha só passa daqui para `signIn`.
struct SignInView: View {
    let signIn: (_ account: String, _ password: String) async throws -> [Appliance]
    let select: (Appliance) async throws -> Void
    let onDone: () -> Void

    @State private var account = ""
    @State private var password = ""
    @State private var appliances: [Appliance] = []
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ar").font(Theme.font(28, weight: .semibold))
                    Text("Entre com a conta do app SmartHome (MSmartHome).")
                        .font(Theme.font(12)).foregroundStyle(Theme.secondary)

                    if appliances.count > 1 { chooser } else { form }
                }
                .foregroundStyle(Theme.text)
                .padding(16)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            field {
                TextField("E-mail", text: $account)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            field {
                SecureField("Senha", text: $password)
                    .textContentType(.password)
            }

            Text("A conta precisa ter e-mail e senha. Quem criou a conta só com \"Entrar com a Apple\" precisa definir uma senha antes, no app SmartHome.")
                .font(Theme.font(11)).foregroundStyle(Theme.secondary)

            errorText

            Button {
                Task { await submit() }
            } label: {
                Text(isBusy ? "Entrando…" : "Entrar")
                    .font(Theme.font(13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x141414))
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(Theme.inverse, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(isBusy || account.isEmpty || password.isEmpty)
            .opacity(account.isEmpty || password.isEmpty ? 0.5 : 1)
        }
    }

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Qual aparelho?").font(Theme.font(13, weight: .semibold))
            ForEach(appliances) { appliance in
                Button {
                    Task { await choose(appliance) }
                } label: {
                    HStack {
                        Text(appliance.name).font(Theme.font(14))
                        Spacer()
                        Text(appliance.online ? "online" : "offline")
                            .font(Theme.font(10))
                            .foregroundStyle(appliance.online ? Theme.ok : Theme.secondary)
                    }
                    .padding(12)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }
            errorText
        }
    }

    @ViewBuilder private var errorText: some View {
        if let errorMessage {
            Text(errorMessage).font(Theme.font(11)).foregroundStyle(Theme.error)
        }
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(Theme.font(14))
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
    }

    private func submit() async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let list = try await signIn(account.trimmingCharacters(in: .whitespaces), password)
            if list.isEmpty {
                errorMessage = "Nenhum aparelho nessa conta"
            } else if list.count == 1 {
                password = ""
                onDone()
            } else {
                password = ""
                appliances = list
            }
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private func choose(_ appliance: Appliance) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await select(appliance)
            onDone()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        if let cloud = error as? MideaCloudError { return cloud.userMessage }
        if error is KeychainError { return "Não foi possível guardar a conta no Keychain" }
        return "Erro inesperado"
    }
}
