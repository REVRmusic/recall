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
        self.playedAt = playedAt
        self.transitionCount = transitionCount
        self.matchType = matchType
        self.harmonicRelation = harmonicRelation
        self.bpmDiff = bpmDiff
        self.isFavorite = isFavorite
        self.isPlayedInSession = isPlayedInSession
    }
    
    // MARK: - Analyse Intelligente Artiste / Titre (Anti Faux-Positifs)
    
    private static let audioExtRegex = try! NSRegularExpression(
        pattern: "\\.(mp3|wav|aiff|flac|m4a|aac|ogg|alac)$",
        options: .caseInsensitive
    )
    
    private static let trackNoPrefixRegex = try! NSRegularExpression(
        pattern: "^[0-9]{1,3}[A-Za-z]?\\s*[\\.-]\\s+",
        options: []
    )
    
    private static let spacedDashRegex = try! NSRegularExpression(
        pattern: "\\s+[-–—]\\s+",
        options: []
    )
    
    private static let techMarkerRegex = try! NSRegularExpression(
        pattern: "^(track|side\\s*[ab]|cd\\s*[0-9]+)$",
        options: .caseInsensitive
    )
    
    private static let genericVersionRegex = try! NSRegularExpression(
        pattern: "^(instrumental|acapella|accapella|extended mix|original mix|clean|dirty|radio edit|dub mix|club mix|club edit|remix|edit|bootleg|intro|outro)$",
        options: .caseInsensitive
    )
    
    public static func parseSmartArtistAndTitle(rawString: String) -> (artist: String?, title: String) {
        var raw = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return (nil, "")
        }
        
        // 1. Supprimer l'extension de fichier audio
        raw = audioExtRegex.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: raw.utf16.count),
            withTemplate: ""
        )
        
        // 2. Nettoyer les numéros de piste en préfixe avec ponctuation (ex: "01. ", "03A. ", "01 - ")
        // Préserve scrupuleusement les artistes débutant par des chiffres (ex: "50 Cent", "2Pac", "6ix9ine")
        let cleaned = trackNoPrefixRegex.stringByReplacingMatches(
            in: raw,
            options: [],
            range: NSRange(location: 0, length: raw.utf16.count),
            withTemplate: ""
        )
        
        // 3. Détecter le séparateur "Artiste - Titre" (tiret entouré d'espaces strict : " - ", " – ", " — ")
        let nsCleaned = cleaned as NSString
        let match = spacedDashRegex.firstMatch(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: nsCleaned.length)
        )
        
        guard let sepMatch = match else {
            return (nil, raw)
        }
        
        let artistCandidate = nsCleaned.substring(to: sepMatch.range.location)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let titleCandidate = nsCleaned.substring(from: sepMatch.range.location + sepMatch.range.length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 4. Règles de validation strictes anti faux-positifs :
        // a. Longueurs cohérentes (artiste de 1 à 60 car, titre au moins 1 car)
        guard artistCandidate.count >= 1 && artistCandidate.count <= 60 && titleCandidate.count >= 1 else {
            return (nil, raw)
        }
        
        // b. L'artiste candidat ne doit pas être purement numérique
        if artistCandidate.range(of: "^[0-9]+$", options: .regularExpression) != nil {
            return (nil, raw)
        }
        
        // c. L'artiste candidat ne doit pas être un préfixe technique d'album / face
        if techMarkerRegex.firstMatch(
            in: artistCandidate,
            options: [],
            range: NSRange(location: 0, length: (artistCandidate as NSString).length)
        ) != nil {
            return (nil, raw)
        }
        
        // d. Le titre candidat ne doit pas être uniquement un descripteur de version générique (ex: "Satisfaction - Club Mix")
        if genericVersionRegex.firstMatch(
            in: titleCandidate,
            options: [],
            range: NSRange(location: 0, length: (titleCandidate as NSString).length)
        ) != nil {
            return (nil, raw)
        }
        
        return (artistCandidate, titleCandidate)
    }
    
    public var smartParsed: (artist: String?, title: String) {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedArtist.isEmpty &&
           trimmedArtist.lowercased() != "artiste inconnu" &&
           trimmedArtist.lowercased() != "unknown artist" &&
           trimmedArtist.lowercased() != "unknown" {
            let directTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                title.trimmingCharacters(in: .whitespacesAndNewlines) :
                (!fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                    (fileName as NSString).deletingPathExtension : "Morceau inconnu")
            return (trimmedArtist, directTitle)
        }
        
        let sourceString = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
            title : (!fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                (fileName as NSString).deletingPathExtension : "")
        
        return Self.parseSmartArtistAndTitle(rawString: sourceString)
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
        if !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return artist
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
}
