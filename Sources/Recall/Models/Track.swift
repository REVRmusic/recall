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
    
    public var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if !fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (fileName as NSString).deletingPathExtension
        }
        return "Morceau inconnu"
    }
    
    public var displayArtist: String {
        if !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return artist
        }
        return "Artiste inconnu"
    }
    
    public var displayBpm: String {
        if bpm <= 0 { return "--" }
        if abs(bpm.rounded() - bpm) < 0.05 {
            return "\(Int(bpm.rounded()))"
        }
        return String(format: "%.1f", bpm)
    }
    
    public var displayKey: String {
        if let camelot = camelotKey {
            return camelot.code
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
