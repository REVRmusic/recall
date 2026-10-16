import Foundation

/// Modes et préréglages pour les raccourcis clavier globaux système (Hotkeys)
public enum HotKeyModifierPreset: String, CaseIterable, Identifiable {
    case both = "both"           // Les deux (⌥⌘ et ⇧⌘ simultanément)
    case cmdOption = "cmdOption" // ⌥⌘ (Cmd + Option) - Garanti zéro conflit Serato & Rekordbox
    case cmdShift = "cmdShift"   // ⇧⌘ (Cmd + Shift) - Dédié Rekordbox
    case disabled = "disabled"   // Désactivé
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .both:
            return "Les deux (⇧⌘ & ⌥⌘)"
        case .cmdOption:
            return "⌥⌘ (Cmd + Option)"
        case .cmdShift:
            return "⇧⌘ (Cmd + Shift)"
        case .disabled:
            return "Désactivé"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .both:
            return "Flexibilité maximale • Compatible tous logiciels"
        case .cmdOption:
            return "Anti-conflit garanti Serato DJ Pro & Rekordbox (Recommandé)"
        case .cmdShift:
            return "Idéal Rekordbox (sans écraser la recherche de caisse Serato)"
        case .disabled:
            return "Aucun raccourci global n'intercepte vos touches"
        }
    }
    
    public var toggleSymbol: String {
        switch self {
        case .both: return "⇧⌘R ou ⌥⌘R"
        case .cmdOption: return "⌥⌘R"
        case .cmdShift: return "⇧⌘R"
        case .disabled: return "—"
        }
    }
    
    public var compactSymbol: String {
        switch self {
        case .both: return "⇧⌘C ou ⌥⌘C"
        case .cmdOption: return "⌥⌘C"
        case .cmdShift: return "⇧⌘C"
        case .disabled: return "—"
        }
    }
    
    public var searchSymbol: String {
        switch self {
        case .both: return "⇧⌘F ou ⌥⌘F"
        case .cmdOption: return "⌥⌘F"
        case .cmdShift: return "⇧⌘F"
        case .disabled: return "—"
        }
    }
}
