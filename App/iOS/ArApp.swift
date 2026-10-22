import SwiftUI
import ArCore

@main
struct ArApp: App {
    @State private var model: AppModel

    init() {
        // Criado aqui, na abertura do processo, e não quando uma tela aparece: se o iOS relançar o app
        // em segundo plano por entrada ou saída de região, o monitor já está aberto para receber o evento.
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.isSignedIn {
                    MainView(model: model)
                } else {
                    SignInView(
                        signIn: { try await model.service.signIn(account: $0, password: $1) },
                        select: { try await model.service.select($0) },
                        onDone: { model.reloadSession() }
                    )
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
