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
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "",
        fileName: String = "",
        playedAt: Date = Date(),
        durationSeconds: Double = 0.0,
        playCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.fileName = fileName
        self.playedAt = playedAt
        self.durationSeconds = durationSeconds
        self.playCount = playCount
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
            var validPlaysByTitle: [String: (title: String, artist: String, fileName: String, lastTime: Date, maxDuration: Double, count: Int)] = [:]
            
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
                    validPlaysByTitle[norm] = existing
                } else {
                    validPlaysByTitle[norm] = (
                        title: entry.title,
                        artist: entry.artist,
                        fileName: entry.fileName,
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
                        playCount: val.count
                    )
                }
                .sorted { $0.playedAt > $1.playedAt }
            
            let titlesSet = Set(validPlaysByTitle.keys)
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.playedTracks = sortedTracks
                self.playedNormalizedTitles = titlesSet
                self.playedCount = sortedTracks.count
                self.isSyncing = false
            }
        }
    }
}
