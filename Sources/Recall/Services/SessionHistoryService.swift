import Foundation
import Combine
import SwiftUI

/// Représente un morceau confirmé comme ayant été joué pendant la session en cours
public struct SessionPlayedTrack: Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let artist: String
    public let fileName: String
    public let playedAt: Date
    public let durationSeconds: Double
    public let playCount: Int
    public let bpm: Double
    public let rawKey: String
    public let genre: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "",
        fileName: String = "",
        playedAt: Date = Date(),
        durationSeconds: Double = 0.0,
        playCount: Int = 1,
        bpm: Double = 0.0,
        rawKey: String = "",
        genre: String = ""
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.playedAt = playedAt
        self.durationSeconds = durationSeconds
        self.playCount = playCount
        self.bpm = bpm
        self.rawKey = rawKey
        self.genre = genre
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = (try? container.decode(String.self, forKey: .artist)) ?? ""
        fileName = (try? container.decode(String.self, forKey: .fileName)) ?? ""
        playedAt = try container.decode(Date.self, forKey: .playedAt)
        durationSeconds = (try? container.decode(Double.self, forKey: .durationSeconds)) ?? 0.0
        playCount = (try? container.decode(Int.self, forKey: .playCount)) ?? 1
        bpm = (try? container.decode(Double.self, forKey: .bpm)) ?? 0.0
        rawKey = (try? container.decode(String.self, forKey: .rawKey)) ?? ""
        genre = (try? container.decode(String.self, forKey: .genre)) ?? ""
    }
    
    public var camelotKey: CamelotKey? {
        return CamelotKey.parse(rawKey)
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
        return title.isEmpty ? "Morceau inconnu" : title
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
        return ""
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
            return camelot.displayText(mode: UserSettings.shared.keyDisplayMode)
        }
        if !rawKey.isEmpty {
            return rawKey
        }
        return "--"
    }
}

/// Service de suivi de la session en cours :
/// - Mémorise tous les morceaux joués depuis le début de la session.
/// - Écarte automatiquement les pré-écoutes temporaires (morceaux chargés et éjectés en moins de 25 secondes).
/// - Fournit un bouton de remise à zéro pour démarrer un nouveau set en live.
@MainActor
public class SessionHistoryService: ObservableObject {
    public static let shared = SessionHistoryService()
    
    @Published public private(set) var playedTracks: [SessionPlayedTrack] = []
    @Published public private(set) var playedNormalizedTitles: Set<String> = []
    @Published public private(set) var sessionStartTime: Date
    @Published public private(set) var playedCount: Int = 0
    @Published public private(set) var lastResetTime: Date? = nil
    
    private let dbService: SeratoDatabaseService
    private var isSyncing: Bool = false
    
    public init(dbService: SeratoDatabaseService = SeratoDatabaseService()) {
        self.dbService = dbService
        
        let def = UserDefaults.standard
        let savedTimestamp = def.double(forKey: "recall_session_start_time")
        
        if savedTimestamp > 0 {
            let savedDate = Date(timeIntervalSince1970: savedTimestamp)
            // Si le timestamp sauvegardé date de moins de 24 heures, on conserve la session
            if Date().timeIntervalSince(savedDate) < 24 * 3600 {
                self.sessionStartTime = savedDate
            } else {
                self.sessionStartTime = Date()
                def.set(self.sessionStartTime.timeIntervalSince1970, forKey: "recall_session_start_time")
            }
        } else {
            // Détection automatique du début de la dernière session Serato si disponible et récente (< 24h)
            if let seratoSessionStart = dbService.fetchLatestSessionStartTime(),
               Date().timeIntervalSince(seratoSessionStart) < 24 * 3600 {
                self.sessionStartTime = seratoSessionStart
            } else {
                self.sessionStartTime = Date()
            }
            def.set(self.sessionStartTime.timeIntervalSince1970, forKey: "recall_session_start_time")
        }
        
        // Synchronisation initiale
        syncWithDatabase(dbService: dbService)
    }
    
    // MARK: - Actions Utilisateur
    
    /// Remet à zéro la session pour considérer qu'on débute un nouveau mix / set
    public func resetSession() {
        let now = Date()
        self.sessionStartTime = now
        self.lastResetTime = now
        self.playedTracks = []
        self.playedNormalizedTitles = []
        self.playedCount = 0
        
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "recall_session_start_time")
        
        // Rafraîchir immédiatement l'interface et les suggestions
        SeratoMonitorService.shared.refreshSuggestions()
    }
    
    /// Vérifie si un morceau a déjà été joué lors de cette session
    public func isPlayed(track: Track) -> Bool {
        let normTitle = FavoriteCombosService.normalize(track.displayTitle)
        if playedNormalizedTitles.contains(normTitle) {
            return true
        }
        if !track.fileName.isEmpty {
            let normFile = FavoriteCombosService.normalize(track.fileName)
            if playedNormalizedTitles.contains(normFile) {
                return true
            }
        }
        return false
    }
    
    /// Vérifie si un titre quelconque a déjà été joué lors de cette session
    public func isPlayed(title: String) -> Bool {
        let norm = FavoriteCombosService.normalize(title)
        return playedNormalizedTitles.contains(norm)
    }
    
    /// Enregistre un morceau confirmé comme ayant été joué pendant la session (utilisé pour Rekordbox et les ajouts directs)
    public func recordPlayedTrack(
        title: String,
        artist: String = "",
        fileName: String = "",
        durationSeconds: Double = 30.0,
        bpm: Double = 0.0,
        rawKey: String = "",
        genre: String = ""
    ) {
        let norm = FavoriteCombosService.normalize(title)
        guard !norm.isEmpty else { return }
        
        let now = Date()
        playedNormalizedTitles.insert(norm)
        if !fileName.isEmpty {
            playedNormalizedTitles.insert(FavoriteCombosService.normalize(fileName))
        }
        
        if let idx = playedTracks.firstIndex(where: { FavoriteCombosService.normalize($0.title) == norm }) {
            let existing = playedTracks[idx]
            playedTracks[idx] = SessionPlayedTrack(
                id: existing.id,
                title: existing.title,
                artist: !artist.isEmpty ? artist : existing.artist,
                fileName: !fileName.isEmpty ? fileName : existing.fileName,
                playedAt: now,
                durationSeconds: max(existing.durationSeconds, durationSeconds),
                playCount: existing.playCount + 1,
                bpm: bpm > 0 ? bpm : existing.bpm,
                rawKey: !rawKey.isEmpty ? rawKey : existing.rawKey,
                genre: !genre.isEmpty ? genre : existing.genre
            )
        } else {
            let newPlayed = SessionPlayedTrack(
                id: "session_\(norm)",
                title: title,
                artist: artist,
                fileName: fileName,
                playedAt: now,
                durationSeconds: durationSeconds,
                playCount: 1,
                bpm: bpm,
                rawKey: rawKey,
                genre: genre
            )
            playedTracks.insert(newPlayed, at: 0)
        }
        playedCount = playedTracks.count
    }
    
    // MARK: - Synchronisation & Détection Pré-écoute vs Lecture Réelle
    
    /// Interroge l'historique Serato et filtre strictement les morceaux joués (durée >= seuil paramétré)
    public func syncWithDatabase(dbService: SeratoDatabaseService) {
        guard !isSyncing else { return }
        isSyncing = true
        
        let start = sessionStartTime
        let thresholdSeconds = Double(UserSettings.shared.playedMinDurationSeconds)
        let playedFlagThreshold = max(5.0, thresholdSeconds * 0.8)
        
        Task.detached(priority: .utility) { [dbService, start, thresholdSeconds, playedFlagThreshold] in
            let rawEntries = dbService.fetchSessionEntries(since: start)
            
            // FILTRAGE INTELLIGENT PRÉ-ÉCOUTE :
            // Un morceau est considéré "JOUÉ" uniquement s'il a tourné pendant au moins thresholdSeconds
            // (ou s'il a le flag 'played == 1' ET au moins playedFlagThreshold de lecture).
            // Les morceaux chargés puis éjectés après une brève pré-écoute au casque sont rejetés.
            var validPlaysByTitle: [String: (title: String, artist: String, fileName: String, bpm: Double, rawKey: String, genre: String, lastTime: Date, maxDuration: Double, count: Int)] = [:]
            
            for entry in rawEntries {
                let duration = entry.durationSeconds
                let isGenuinePlay: Bool
                
                if entry.isCurrentlyPlaying {
                    // En cours de lecture sur la platine : doit tourner depuis au moins thresholdSeconds
                    isGenuinePlay = duration >= thresholdSeconds
                } else {
                    // Lecture terminée : durée effective requise >= thresholdSeconds (ou played=1 avec >= playedFlagThreshold)
                    isGenuinePlay = duration >= thresholdSeconds || (entry.playedFlag == 1 && duration >= playedFlagThreshold)
                }
                
                guard isGenuinePlay else { continue }
                
                let norm = FavoriteCombosService.normalize(entry.title)
                guard !norm.isEmpty else { continue }
                
                if var existing = validPlaysByTitle[norm] {
                    existing.lastTime = max(existing.lastTime, entry.startTime)
                    existing.maxDuration = max(existing.maxDuration, duration)
                    existing.count += 1
                    if existing.bpm <= 0 && entry.bpm > 0 { existing.bpm = entry.bpm }
                    if existing.rawKey.isEmpty && !entry.rawKey.isEmpty { existing.rawKey = entry.rawKey }
                    if existing.genre.isEmpty && !entry.genre.isEmpty { existing.genre = entry.genre }
                    validPlaysByTitle[norm] = existing
                } else {
                    validPlaysByTitle[norm] = (
                        title: entry.title,
                        artist: entry.artist,
                        fileName: entry.fileName,
                        bpm: entry.bpm,
                        rawKey: entry.rawKey,
                        genre: entry.genre,
                        lastTime: entry.startTime,
                        maxDuration: duration,
                        count: 1
                    )
                }
            }
            
            let sortedTracks = validPlaysByTitle.values
                .map { val in
                    SessionPlayedTrack(
                        id: "session_\(FavoriteCombosService.normalize(val.title))",
                        title: val.title,
                        artist: val.artist,
                        fileName: val.fileName,
                        playedAt: val.lastTime,
                        durationSeconds: val.maxDuration,
                        playCount: val.count,
                        bpm: val.bpm,
                        rawKey: val.rawKey,
                        genre: val.genre
                    )
                }
                .sorted { a, b in
                    if a.playedAt != b.playedAt {
                        return a.playedAt > b.playedAt
                    }
                    return a.title < b.title
                }
            
            let titlesSet = Set(validPlaysByTitle.keys)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                // Ne republie que si le contenu des morceaux a réellement changé (évite les rafraîchissements permanents en boucle)
                let hasChanged = self.playedTracks.count != sortedTracks.count ||
                    zip(self.playedTracks, sortedTracks).contains { t1, t2 in
                        t1.id != t2.id ||
                        t1.title != t2.title ||
                        t1.artist != t2.artist ||
                        t1.playCount != t2.playCount ||
                        t1.bpm != t2.bpm ||
                        t1.rawKey != t2.rawKey ||
                        t1.genre != t2.genre
                    }
                
                if hasChanged {
                    self.playedTracks = sortedTracks
                    self.playedNormalizedTitles = titlesSet
                    self.playedCount = sortedTracks.count
                }
                self.isSyncing = false
            }
        }
    }
}
