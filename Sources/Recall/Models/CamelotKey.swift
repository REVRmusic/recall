import Foundation
import SwiftUI

/// Représentation standardisée d'une clé harmonique selon la roue de Camelot
public struct CamelotKey: Hashable, Codable, Equatable {
    public let number: Int      // 1 à 12
    public let letter: String   // "A" (Mineur) ou "B" (Majeur)
    public let musicalName: String // ex: "Em", "G", etc.
    
    public init(number: Int, letter: String, musicalName: String = "") {
        self.number = max(1, min(12, number))
        self.letter = letter.uppercased() == "B" ? "B" : "A"
        if !musicalName.isEmpty {
            self.musicalName = musicalName
        } else {
            self.musicalName = CamelotKey.defaultMusicalName(number: number, letter: letter)
        }
    }
    
    public var code: String {
        return "\(number)\(letter)"
    }
    
    public var isMinor: Bool {
        return letter == "A"
    }
    
    /// Parse n'importe quelle notation Serato (Camelot "9A", ou musicale "Em", "G#m", etc.)
    public static func parse(_ raw: String?) -> CamelotKey? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        
        let cleaned = raw.replacingOccurrences(of: "\"", with: "")
                         .replacingOccurrences(of: "'", with: "")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Vérification format Camelot direct (ex: "9A", "12B", "1A")
        let camelotRegex = try? NSRegularExpression(pattern: "^([0-9]{1,2})([ABab])$")
        if let match = camelotRegex?.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
            if let numRange = Range(match.range(at: 1), in: cleaned),
               let letterRange = Range(match.range(at: 2), in: cleaned),
               let num = Int(cleaned[numRange]) {
                let letter = String(cleaned[letterRange]).uppercased()
                return CamelotKey(number: num, letter: letter)
            }
        }
        
        // 2. Table de conversion Musicale -> Camelot
        let normalized = cleaned
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch normalized {
        // --- Clés Mineures (A) ---
        case "Abm", "G#m", "Sol#m", "Labm": return CamelotKey(number: 1, letter: "A", musicalName: "G#m")
        case "Ebm", "D#m", "Re#m", "Mibm":  return CamelotKey(number: 2, letter: "A", musicalName: "Ebm")
        case "Bbm", "A#m", "La#m", "Sibm":  return CamelotKey(number: 3, letter: "A", musicalName: "Bbm")
        case "Fm", "Fam":                   return CamelotKey(number: 4, letter: "A", musicalName: "Fm")
        case "Cm", "Dom":                   return CamelotKey(number: 5, letter: "A", musicalName: "Cm")
        case "Gm", "Solm":                  return CamelotKey(number: 6, letter: "A", musicalName: "Gm")
        case "Dm", "Rem":                   return CamelotKey(number: 7, letter: "A", musicalName: "Dm")
        case "Am", "Lam":                   return CamelotKey(number: 8, letter: "A", musicalName: "Am")
        case "Em", "Mim":                   return CamelotKey(number: 9, letter: "A", musicalName: "Em")
        case "Bm", "Sim":                   return CamelotKey(number: 10, letter: "A", musicalName: "Bm")
        case "F#m", "Gbm", "Fa#m", "Solbm": return CamelotKey(number: 11, letter: "A", musicalName: "F#m")
        case "C#m", "Dbm", "Do#m", "Rebm":  return CamelotKey(number: 12, letter: "A", musicalName: "C#m")
            
        // --- Clés Majeures (B) ---
        case "B", "Si":                     return CamelotKey(number: 1, letter: "B", musicalName: "B")
        case "F#", "Gb", "Fa#", "Solb":     return CamelotKey(number: 2, letter: "B", musicalName: "F#")
        case "Db", "C#", "Reb", "Do#":      return CamelotKey(number: 3, letter: "B", musicalName: "Db")
        case "Ab", "G#", "Lab", "Sol#":     return CamelotKey(number: 4, letter: "B", musicalName: "Ab")
        case "Eb", "D#", "Mib", "Re#":      return CamelotKey(number: 5, letter: "B", musicalName: "Eb")
        case "Bb", "A#", "Sib", "La#":      return CamelotKey(number: 6, letter: "B", musicalName: "Bb")
        case "F", "Fa":                     return CamelotKey(number: 7, letter: "B", musicalName: "F")
        case "C", "Do":                     return CamelotKey(number: 8, letter: "B", musicalName: "C")
        case "G", "Sol":                    return CamelotKey(number: 9, letter: "B", musicalName: "G")
        case "D", "Re":                     return CamelotKey(number: 10, letter: "B", musicalName: "D")
        case "A", "La":                     return CamelotKey(number: 11, letter: "B", musicalName: "A")
        case "E", "Mi":                     return CamelotKey(number: 12, letter: "B", musicalName: "E")
            
        default:
            return nil
        }
    }
    
    private static func defaultMusicalName(number: Int, letter: String) -> String {
        if letter == "A" {
            switch number {
            case 1: return "G#m"
            case 2: return "Ebm"
            case 3: return "Bbm"
            case 4: return "Fm"
            case 5: return "Cm"
            case 6: return "Gm"
            case 7: return "Dm"
            case 8: return "Am"
            case 9: return "Em"
            case 10: return "Bm"
            case 11: return "F#m"
            case 12: return "C#m"
            default: return ""
            }
        } else {
            switch number {
            case 1: return "B"
            case 2: return "F#"
            case 3: return "Db"
            case 4: return "Ab"
            case 5: return "Eb"
            case 6: return "Bb"
            case 7: return "F"
            case 8: return "C"
            case 9: return "G"
            case 10: return "D"
            case 11: return "A"
            case 12: return "E"
            default: return ""
            }
        }
    }
    
    /// Évalue la relation harmonique avec une autre clé
    public func relationship(with other: CamelotKey) -> HarmonicRelation {
        if self == other {
            return .exact
        }
        
        // Même lettre (A ou B)
        if self.letter == other.letter {
            let diff = abs(self.number - other.number)
            if diff == 1 || diff == 11 {
                return .adjacent
            } else if (self.number + 2 - 1) % 12 + 1 == other.number {
                return .energyBoost
            } else if (self.number - 2 + 11) % 12 + 1 == other.number {
                return .energyDrop
            }
        }
        
        // Clé relative (même chiffre, lettre opposée : ex 9A <-> 9B)
        if self.number == other.number && self.letter != other.letter {
            return .relative
        }
        
        return .incompatible
    }
    
    public var isHarmonicallyCompatible: (CamelotKey) -> Bool {
        return { other in
            let rel = self.relationship(with: other)
            return rel == .exact || rel == .adjacent || rel == .relative || rel == .energyBoost
        }
    }
    
    /// Couleur officielle de la vraie roue de Camelot (Serato DJ Pro / Mixed In Key)
    public var color: Color {
        if isMinor {
            // Anneau intérieur "A" (Mineur - Tonalités douces Serato)
            switch number {
            case 1:  return Color(hex: "#6EF3E0") // Menthe / Seafoam (G#m)
            case 2:  return Color(hex: "#8BF3B3") // Vert clair (Ebm)
            case 3:  return Color(hex: "#BAF797") // Vert lime clair (Bbm)
            case 4:  return Color(hex: "#F9DE93") // Jaune pastel (Fm)
            case 5:  return Color(hex: "#F9C7AD") // Pêche orangé clair (Cm)
            case 6:  return Color(hex: "#F8B8BC") // Corail rosé clair (Gm)
            case 7:  return Color(hex: "#F8B5CD") // Rose / Magenta pastel (Dm)
            case 8:  return Color(hex: "#F3B4E6") // Mauve / Orchidée clair (Am)
            case 9:  return Color(hex: "#E2BCFF") // Lavande / Violet clair (Em)
            case 10: return Color(hex: "#C5D5FF") // Pervenche / Bleu doux (Bm)
            case 11: return Color(hex: "#9BE7FB") // Bleu ciel clair (F#m)
            case 12: return Color(hex: "#6BF4F3") // Aqua / Turquoise clair (C#m)
            default: return Color.gray
            }
        } else {
            // Anneau extérieur "B" (Majeur - Tonalités vives Serato)
            switch number {
            case 1:  return Color(hex: "#55ECCC") // Menthe vif (B)
            case 2:  return Color(hex: "#4FEE81") // Vert émeraude vif (F#)
            case 3:  return Color(hex: "#88F34C") // Vert lime vif (Db)
            case 4:  return Color(hex: "#F7CB4B") // Jaune doré vif (Ab)
            case 5:  return Color(hex: "#F6A47E") // Pêche / Orange vif (Eb)
            case 6:  return Color(hex: "#F58895") // Corail / Rouge rosé vif (Bb)
            case 7:  return Color(hex: "#F580B4") // Magenta vif (F)
            case 8:  return Color(hex: "#EC83DB") // Violet / Orchidée vif (C)
            case 9:  return Color(hex: "#CD8DFF") // Violet bleu vif (G)
            case 10: return Color(hex: "#A0B5FF") // Bleu pervenche vif (D)
            case 11: return Color(hex: "#5BD7F8") // Bleu ciel vif (A)
            case 12: return Color(hex: "#58EBEC") // Turquoise vif (E)
            default: return Color.gray
            }
        }
    }
}

public enum HarmonicRelation: String, CaseIterable {
    case exact = "Même clé"
    case adjacent = "±1 Adjacent"
    case relative = "Relative (Maj/Min)"
    case energyBoost = "+2 Boost d'énergie"
    case energyDrop = "-2 Drop d'énergie"
    case incompatible = "Différente"
    
    public var isCompatible: Bool {
        return self == .exact || self == .adjacent || self == .relative || self == .energyBoost
    }
    
    public var badgeText: String {
        switch self {
        case .exact: return "Identique"
        case .adjacent: return "Parfait"
        case .relative: return "Relatif"
        case .energyBoost: return "+2 Boost"
        case .energyDrop: return "-2 Drop"
        case .incompatible: return ""
        }
    }
}
