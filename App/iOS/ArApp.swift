import SwiftUI
import ArCore

@main
struct ArApp: App {
    @State private var model = AppModel()

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
