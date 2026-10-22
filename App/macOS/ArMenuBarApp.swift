import SwiftUI
import ArCore

@main
struct ArMenuBarApp: App {
    @State private var model = MacAppModel()

    init() {
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: model)
        } label: {
            MenuBarLabel(control: model.control)
        }
        .menuBarExtraStyle(.window)

        Window("Conta Midea", id: "conta") {
            AccountWindow(model: model)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}
