import SwiftUI

/// Thèmes visuels pour l'ambiance de Recall (accents de couleur adaptés au setup du DJ)
public enum DJTheme: String, CaseIterable, Identifiable {
    case cyanNeon = "cyanNeon"
    case electricPurple = "electricPurple"
    case sunsetAmber = "sunsetAmber"
    case acidGreen = "acidGreen"
    
    public var id: String { rawValue }
    
    /// Nom affiché du thème
    public var name: String {
        switch self {
        case .cyanNeon:
            return "Cyan Neon"
        case .electricPurple:
            return "Electric Purple"
        case .sunsetAmber:
            return "Sunset Amber"
        case .acidGreen:
            return "Acid Green"
        }
    }
    
    /// Sous-titre évocateur du style visuel
    public var subtitle: String {
        switch self {
        case .cyanNeon:
            return "Signature Recall • Cyber Cyan"
        case .electricPurple:
            return "Vibe Nocturne • Violet Laser & Deep"
        case .sunsetAmber:
            return "Chaleur Analogique • Or & Ambre"
        case .acidGreen:
            return "Énergie Club • Vert Acide & Rave"
        }
    }
    
    /// Couleur d'accent principale
    public var accentColor: Color {
        switch self {
        case .cyanNeon:
            // Couleur signature par défaut de Recall (#00D9E6)
            return Color(red: 0.0, green: 0.85, blue: 0.90)
        case .electricPurple:
            // Violet électrique punchy et moderne (#B859FF)
            return Color(red: 0.72, green: 0.35, blue: 1.0)
        case .sunsetAmber:
            // Ambre coucher de soleil doré et chaleureux (#FF9E14)
            return Color(red: 1.0, green: 0.62, blue: 0.08)
        case .acidGreen:
            // Vert acide / lime fluo énergique (#38EB61)
            return Color(red: 0.22, green: 0.92, blue: 0.38)
        }
    }
    
    /// Couleur d'accent secondaire (pour dégradés, glow et surbrillances)
    public var secondaryColor: Color {
        switch self {
        case .cyanNeon:
            // Bleu électrique complémentaire (#3399FF)
            return Color(red: 0.20, green: 0.60, blue: 1.0)
        case .electricPurple:
            // Magenta / rose néon complémentaire (#EB47CC)
            return Color(red: 0.92, green: 0.28, blue: 0.80)
        case .sunsetAmber:
            // Rouge orangé solaire complémentaire (#FF592E)
            return Color(red: 1.0, green: 0.35, blue: 0.18)
        case .acidGreen:
            // Cyan menthe complémentaire (#0DD9CC)
            return Color(red: 0.05, green: 0.85, blue: 0.80)
        }
    }
    
    /// Code hexadécimal représentatif pour affichage ou debug
    public var hexCode: String {
        switch self {
        case .cyanNeon: return "#00D9E6"
        case .electricPurple: return "#B859FF"
        case .sunsetAmber: return "#FF9E14"
        case .acidGreen: return "#38EB61"
        }
    }
    
    /// Icône SF Symbol associée
    public var icon: String {
        switch self {
        case .cyanNeon: return "waveform.path"
        case .electricPurple: return "sparkles"
        case .sunsetAmber: return "sun.max.fill"
        case .acidGreen: return "bolt.fill"
        }
    }
}

#if os(macOS)
import AppKit

extension DJTheme {
    /// Couleur native NSColor de l'accent principal
    public var nsAccentColor: NSColor {
        switch self {
        case .cyanNeon:
            return NSColor(red: 0.0, green: 0.85, blue: 0.90, alpha: 1.0)
        case .electricPurple:
            return NSColor(red: 0.72, green: 0.35, blue: 1.0, alpha: 1.0)
        case .sunsetAmber:
            return NSColor(red: 1.0, green: 0.62, blue: 0.08, alpha: 1.0)
        case .acidGreen:
            return NSColor(red: 0.22, green: 0.92, blue: 0.38, alpha: 1.0)
        }
    }
    
    /// Couleur native NSColor de l'accent secondaire (pour dégradés)
    public var nsSecondaryColor: NSColor {
        switch self {
        case .cyanNeon:
            return NSColor(red: 0.20, green: 0.60, blue: 1.0, alpha: 1.0)
        case .electricPurple:
            return NSColor(red: 0.92, green: 0.28, blue: 0.80, alpha: 1.0)
        case .sunsetAmber:
            return NSColor(red: 1.0, green: 0.35, blue: 0.18, alpha: 1.0)
        case .acidGreen:
            return NSColor(red: 0.05, green: 0.85, blue: 0.80, alpha: 1.0)
        }
    }

    /// Image native de l'icône de l'application adaptée aux couleurs de ce thème
    public var iconImage: NSImage? {
        let resourceName = "AppIcon_\(rawValue)"
        
        // 1. Recherche dans les ressources du bundle de l'application
        if let path = Bundle.main.path(forResource: resourceName, ofType: "png"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        
        // 2. Recherche directe dans le dossier Resources/ (support environnement de dev local)
        let localPath = "Resources/\(resourceName).png"
        if let icon = NSImage(contentsOfFile: localPath) {
            return icon
        }
        
        // 3. Fallback sur l'icône standard
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        
        return NSApp.applicationIconImage
    }
}
#endif

