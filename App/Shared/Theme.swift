import SwiftUI

/// Identidade visual do app (spec §6.4): escuro, monoespaçado, sem decoração.
enum Theme {
    static let background = Color(hex: 0x121314)
    static let card = Color(hex: 0x17181A)
    static let border = Color(hex: 0x2A2C2E)
    static let text = Color(hex: 0xE6EAEB)
    static let secondary = Color(hex: 0x7C8486)
    static let inverse = Color(hex: 0xD8E0E2)
    static let altSurface = Color(hex: 0x282C2C)
    static let ok = Color(hex: 0x6FA892)
    static let error = Color(hex: 0xC8645A)

    /// Fonte monoespaçada usada em todo o app.
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    /// Cor a partir de um valor RGB hexadecimal (ex.: 0x121314).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
