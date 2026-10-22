import SwiftUI
import ArCore

@main
struct ArMenuBarApp: App {
    /// Referência a um símbolo do ArCore, só para provar o vínculo do pacote.
    private let temperatureRange = ACCommand.temperatureRange

    var body: some Scene {
        MenuBarExtra {
            Button("Sair do app") { NSApplication.shared.terminate(nil) }
        } label: {
            Text("❄︎")
        }
    }
}
