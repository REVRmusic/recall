import Foundation
import Combine
import SwiftUI

/// Données sauvegardées pour un morceau dans une combinaison favorite
public struct SavedTrackData: Codable, Hashable {
    public var title: String
    public var artist: String
    public var bpm: Double
    public var rawKey: String
    public var filePath: String?
    public var fileName: String
    public var portableId: String
    
    public init(
        title: String,
        artist: String = "",
        bpm: Double = 0.0,
        rawKey: String = "",
        filePath: String? = nil,
        fileName: String = "",
        portableId: String = ""
    ) {
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.rawKey = rawKey
        self.filePath = filePath
        self.fileName = fileName
        self.portableId = portableId
    }
    
    public init(from track: Track) {
        self.title = track.title
        self.artist = track.artist
        self.bpm = track.bpm
        self.rawKey = track.rawKey
        self.filePath = track.filePath
        self.fileName = track.fileName
        self.portableId = track.portableId
    }
    
    public func toTrack(
        transitionCount: Int = 0,
        referenceTrack: Track? = nil
    ) -> Track {
        var harmonicRel: HarmonicRelation? = nil
        var bpmDifference: Double? = nil
        
        let parsedCamelot = CamelotKey.parse(rawKey)
        if let ref = referenceTrack {
            if let refCamelot = ref.camelotKey, let targetCamelot = parsedCamelot {
                harmonicRel = refCamelot.relationship(with: targetCamelot)
            }
            if ref.bpm > 0 && bpm > 0 {
                bpmDifference = bpm - ref.bpm
            }
        }
        
        return Track(
            id: "fav_\(title.hashValue)_\(artist.hashValue)",
            assetId: nil,
            historyEntryId: nil,
            title: title,
            artist: artist,
            bpm: bpm,
            rawKey: rawKey,
            filePath: filePath,
            fileName: fileName,
            portableId: portableId,
            deck: nil,
            playedAt: nil,
            transitionCount: transitionCount,
            matchType: .manualFavorite,
            harmonicRelation: harmonicRel,
            bpmDiff: bpmDifference,
            isFavorite: true
        )
    }
}

/// Représente une association favorite entre deux morceaux
public struct FavoriteCombo: Codable, Identifiable, Hashable {
    public var id: String
    public var track1: SavedTrackData
    public var track2: SavedTrackData
    public var createdAt: Date
    public var notes: String?
    
    public init(
        id: String = UUID().uuidString,
        track1: SavedTrackData,
        track2: SavedTrackData,
        createdAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.track1 = track1
        self.track2 = track2
        self.createdAt = createdAt
        self.notes = notes
    }
}

/// Service de gestion et de persistance des enchaînements et combinaisons favorites
@MainActor
public class FavoriteCombosService: ObservableObject {
    public static let shared = FavoriteCombosService()
    
    @Published public private(set) var combos: [FavoriteCombo] = []
    
    private let storageURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recallDir = appSupport.appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: recallDir, withIntermediateDirectories: true)
        self.storageURL = recallDir.appendingPathComponent("favorite_combos.json")
        loadCombos()
    }
    
    // MARK: - Normalisation pour recherche tolérante
    
    nonisolated public static func normalize(_ str: String) -> String {
        return str
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func matches(trackA: SavedTrackData, trackB: Track) -> Bool {
        let normA = Self.normalize(trackA.title)
        let normB = Self.normalize(trackB.displayTitle)
        let normBRaw = Self.normalize(trackB.title)
        if !normA.isEmpty && (!normB.isEmpty && normA == normB || !normBRaw.isEmpty && normA == normBRaw) {
            return true
        }
        if !trackA.fileName.isEmpty && !trackB.fileName.isEmpty &&
           Self.normalize(trackA.fileName) == Self.normalize(trackB.fileName) {
            return true
        }
        return false
    }
    
    // MARK: - Persistance
    
    private func loadCombos() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            self.combos = []
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([FavoriteCombo].self, from: data)
            self.combos = decoded
        } catch {
            print("Erreur chargement favoris: \(error)")
            self.combos = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(combos)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erreur sauvegarde favoris: \(error)")
        }
    }
    
    // MARK: - Actions Utilisateur
    
    /// Enregistre une combinaison entre deux morceaux (bidirectionnelle)
    @discardableResult
    public func saveCombo(track1: Track, track2: Track, notes: String? = nil) -> Bool {
        // Ne pas enregistrer un morceau avec lui-même
        guard Self.normalize(track1.displayTitle) != Self.normalize(track2.displayTitle) else {
            return false
        }
        
        // Vérifier si la combinaison existe déjà dans un sens ou dans l'autre
        if isComboFavorite(track1: track1, track2: track2) {
            return false
        }
        
        let combo = FavoriteCombo(
            track1: SavedTrackData(from: track1),
            track2: SavedTrackData(from: track2),
            createdAt: Date(),
            notes: notes
        )
        
        combos.insert(combo, at: 0)
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
        return true
    }
    
    /// Supprime une combinaison existante
    public func removeCombo(track1: Track, track2: Track) {
        let norm1 = Self.normalize(track1.displayTitle)
        let norm2 = Self.normalize(track2.displayTitle)
        
        combos.removeAll { combo in
            let c1 = Self.normalize(combo.track1.title)
            let c2 = Self.normalize(combo.track2.title)
            return (c1 == norm1 && c2 == norm2) || (c1 == norm2 && c2 == norm1)
        }
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
    }
    
    /// Bascule l'état favori d'une combinaison (True si ajouté, False si retiré)
    @discardableResult
    public func toggleCombo(track1: Track, track2: Track) -> Bool {
        if isComboFavorite(track1: track1, track2: track2) {
            removeCombo(track1: track1, track2: track2)
            return false
        } else {
            return saveCombo(track1: track1, track2: track2)
        }
    }
    
    /// Vérifie si deux morceaux forment une combinaison favorite connue
    public func isComboFavorite(track1: Track, track2: Track) -> Bool {
        let norm1 = Self.normalize(track1.displayTitle)
        let norm2 = Self.normalize(track2.displayTitle)
        
        for combo in combos {
            let c1 = Self.normalize(combo.track1.title)
            let c2 = Self.normalize(combo.track2.title)
            if (c1 == norm1 && c2 == norm2) || (c1 == norm2 && c2 == norm1) {
                return true
            }
        }
        return false
    }
    
    /// Récupère tous les morceaux enregistrés en combinaison avec le morceau de référence
    public func getFavoriteTracks(for referenceTrack: Track) -> [Track] {
        var results: [Track] = []
        var seenTitles = Set<String>()
        
        for combo in combos {
            if matches(trackA: combo.track1, trackB: referenceTrack) {
                let norm = Self.normalize(combo.track2.title)
                if !seenTitles.contains(norm) {
                    seenTitles.insert(norm)
                    let track = combo.track2.toTrack(transitionCount: 0, referenceTrack: referenceTrack)
                    results.append(track)
                }
            } else if matches(trackA: combo.track2, trackB: referenceTrack) {
                let norm = Self.normalize(combo.track1.title)
                if !seenTitles.contains(norm) {
                    seenTitles.insert(norm)
                    let track = combo.track1.toTrack(transitionCount: 0, referenceTrack: referenceTrack)
                    results.append(track)
                }
            }
        }
        return results
    }
    
    /// Supprime un favori par son identifiant unique
    public func deleteCombo(byId id: String) {
        combos.removeAll { $0.id == id }
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
    }
    
    /// Supprime tous les favoris
    public func clearAllCombos() {
        combos.removeAll()
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
    }
}
