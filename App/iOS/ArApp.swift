import SwiftUI
import ArCore

@main
struct ArApp: App {
    /// Referência a um símbolo do ArCore, só para provar o vínculo do pacote.
    private let temperatureRange = ACCommand.temperatureRange

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.background.ignoresSafeArea()
                Text("Ar")
                    .font(Theme.font(28, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .preferredColorScheme(.dark)
        }
    }
}
