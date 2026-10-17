import Foundation

public enum MatchType: String, Codable {
    case directTransition = "Transition directe"
    case sameSongVariant  = "Variante morceau"
    case routineSequence  = "Routine enchaînée"
    case manualFavorite   = "Favori manuel"
    
    public var badgeIcon: String {
        switch self {
        case .directTransition: return "flame.fill"
        case .sameSongVariant:  return "arrow.triangle.swap"
        case .routineSequence:  return "repeat"
        case .manualFavorite:   return "heart.fill"
        }
    }
}

public struct Track: Identifiable, Hashable {
    public let id: String
    public let assetId: Int?
    public let historyEntryId: Int?
    public let title: String
    public let artist: String
    public let bpm: Double
    public let rawKey: String
    public let camelotKey: CamelotKey?
    public let filePath: String?
    public let fileName: String
    public let portableId: String
    public let deck: String?
    public let genre: String
    public let playedAt: Date?
    
    // Propriétés spécifiques aux suggestions d'enchaînement
    public var transitionCount: Int
    public var matchType: MatchType
    public var harmonicRelation: HarmonicRelation?
    public var bpmDiff: Double?
    public var isFavorite: Bool
    public var isPlayedInSession: Bool
    
    public init(
        id: String = UUID().uuidString,
        assetId: Int? = nil,
        historyEntryId: Int? = nil,
        title: String,
        artist: String = "",
        bpm: Double = 0.0,
        rawKey: String = "",
        filePath: String? = nil,
        fileName: String = "",
        portableId: String = "",
        deck: String? = nil,
        genre: String = "",
        playedAt: Date? = nil,
        transitionCount: Int = 0,
        matchType: MatchType = .directTransition,
        harmonicRelation: HarmonicRelation? = nil,
        bpmDiff: Double? = nil,
        isFavorite: Bool = false,
        isPlayedInSession: Bool = false
    ) {
        self.id = id
        self.assetId = assetId
        self.historyEntryId = historyEntryId
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.rawKey = rawKey
        self.camelotKey = CamelotKey.parse(rawKey)
        self.filePath = filePath
        self.fileName = fileName
        self.portableId = portableId
        self.deck = deck
        self.genre = genre
        self.playedAt = playedAt
        self.transitionCount = transitionCount
        self.matchType = matchType
        self.harmonicRelation = harmonicRelation
        self.bpmDiff = bpmDiff
        self.isFavorite = isFavorite
        self.isPlayedInSession = isPlayedInSession
    }
    
    // MARK: - Analyse & Nettoyage Intelligents Artiste / Titre
    
    public static func parseSmartArtistAndTitle(rawString: String) -> (artist: String?, title: String) {
        return TrackMetadataCleaner.parseSmartArtistAndTitle(rawString: rawString)
    }
    
    public static func isJunkOrPromoArtist(_ string: String) -> Bool {
        return TrackMetadataCleaner.isJunkOrPromoArtist(string)
    }
    
    public static func isKnownGenericGenre(_ string: String) -> Bool {
        return TrackMetadataCleaner.isKnownGenericGenre(string)
    }
    
    public static func cleanArtistName(_ string: String) -> String {
        return TrackMetadataCleaner.cleanArtistName(string)
    }
    
    public static func cleanTitleName(_ string: String) -> String {
        return TrackMetadataCleaner.cleanTitleName(string)
    }
    
    public static func extractPrimaryArtist(_ string: String) -> String {
        return TrackMetadataCleaner.extractPrimaryArtist(string)
    }
    
    public var smartParsed: (artist: String?, title: String) {
        return TrackMetadataCleaner.resolve(
            artist: artist,
            title: title,
            fileName: fileName,
            genre: genre
        )
    }
    
    public var displayTitle: String {
        let parsed = smartParsed
        if !parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return parsed.title
        }
        if !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (fileName as NSString).deletingPathExtension
        }
        return "Morceau inconnu"
    }
    
    public var displayArtist: String {
        let parsed = smartParsed
        if let art = parsed.artist, !art.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return art
        }
        let clean = TrackMetadataCleaner.cleanArtistName(artist)
        if !clean.isEmpty && !TrackMetadataCleaner.isJunkOrPromoArtist(clean) && !TrackMetadataCleaner.isKnownGenericGenre(clean) {
            return clean
        }
        return "Artiste inconnu"
    }
    
    public var fullTooltip: String {
        let t = displayTitle
        let a = displayArtist
        if !a.isEmpty && a != "Artiste inconnu" {
            return "\(t)\n\(a)"
        } else {
            return t
        }
    }
    
    public var displayBpm: String {
        if bpm <= 0 { return "--" }
        if abs(bpm.rounded() - bpm) < 0.05 {
            return "\(Int(bpm.rounded()))"
        }
        return String(format: "%.1f", bpm)
    }
    
    public var displayKey: String {
        return displayKey(mode: UserSettings.shared.keyDisplayMode)
    }
    
    public func displayKey(mode: Int) -> String {
        if let camelot = camelotKey {
            return camelot.displayText(mode: mode)
        }
        if !rawKey.isEmpty {
            return rawKey
        }
        return "--"
    }
    
    public var isFileAvailable: Bool {
        guard let p = filePath, !p.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: p)
    }
    
    // MARK: - Extraction Intelligente du Titre de Base (Anti-Variantes / Edits / Remixes)
    
    /// Extrait le titre de base d'un morceau en retirant les descripteurs de version, remix, edit ou mentions de featuring.
    /// Ex: "Monalisa - Da Phonk Club Edit" -> "Monalisa"
    /// Ex: "Monalisa (Extended Mix By Fuvi Clan)" -> "Monalisa"
    public static func extractBaseTitle(_ fullTitle: String) -> String {
        var cleaned = fullTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return "" }
        
        // 1. Supprimer les parenthèses, crochets et accolades de version ou featuring
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\([^)]*\\)", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\[[^]]*\\]", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s*\\{[^}]*\\}", with: "", options: .regularExpression)
        
        // 2. Supprimer les mentions de featuring (feat., ft., featuring, with, vs.)
        let featRegex = "\\s+(feat\\.|ft\\.|featuring|with|vs\\.|pres\\.).*$"
        cleaned = cleaned.replacingOccurrences(of: featRegex, with: "", options: [.regularExpression, .caseInsensitive])
        
        // 3. Supprimer les suffixes de version / remix / edit séparés par un tiret
        let versionSuffixRegex = "\\s+[-–—]\\s+.*(remix|edit|mix|version|vip|dub|bootleg|rework|flip|extended|club|radio|intro|outro|clean|dirty|short|acapella|instrumental|mashup|refix|cut).*$"
        cleaned = cleaned.replacingOccurrences(of: versionSuffixRegex, with: "", options: [.regularExpression, .caseInsensitive])
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fullTitle : cleaned
    }
}
