import SwiftUI

public extension Color {
    static let darkBg = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let cardBg = Color(red: 0.13, green: 0.14, blue: 0.18)
    static let cardHoverBg = Color(red: 0.18, green: 0.20, blue: 0.25)
    // Couleurs statiques de référence
    static let recallCyan = Color(red: 0.0, green: 0.85, blue: 0.90)
    static let recallBlue = Color(red: 0.20, green: 0.60, blue: 1.0)
    
    // Accents dynamiques réactifs synchronisés avec le thème DJ actif choisi par l'utilisateur
    static var accentCyan: Color {
        UserSettings.shared.accentColor
    }
    static var accentBlue: Color {
        UserSettings.shared.accentSecondaryColor
    }
    static let accentPurple = Color(red: 0.65, green: 0.35, blue: 1.0)
    static let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.45)
    static let accentOrange = Color(red: 1.0, green: 0.55, blue: 0.15)
    static let accentFire = Color(red: 1.0, green: 0.30, blue: 0.20)
    static let borderSubtle = Color(white: 1.0, opacity: 0.10)
    static let borderActive = Color(white: 1.0, opacity: 0.25)
    
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
    
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Float(components.redComponent)
        let g = Float(components.greenComponent)
        let b = Float(components.blueComponent)
        return String(format: "#%02X%02X%02X", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
