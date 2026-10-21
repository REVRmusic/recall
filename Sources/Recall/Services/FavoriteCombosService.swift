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

/// Sens dans lequel un combo favori est proposé.
/// `forward` = le morceau 1, puis le morceau 2. `reverse` = l'inverse. `both` = les deux sens.
public enum FavoriteLinkDirection: String, Codable, Equatable, Hashable {
    case forward
    case reverse
    case both
}

/// Représente une association favorite entre deux morceaux
public struct FavoriteCombo: Codable, Identifiable, Hashable {
    public var id: String
    public var track1: SavedTrackData
    public var track2: SavedTrackData
    public var createdAt: Date
    public var notes: String?
    /// Sens relatif à `track1` / `track2`. Les anciens favoris, sans ce champ, restent dans les deux sens.
    public var direction: FavoriteLinkDirection
    
    public init(
        id: String = UUID().uuidString,
        track1: SavedTrackData,
        track2: SavedTrackData,
        createdAt: Date = Date(),
        notes: String? = nil,
        direction: FavoriteLinkDirection = .both
    ) {
        self.id = id
        self.track1 = track1
        self.track2 = track2
        self.createdAt = createdAt
        self.notes = notes
        self.direction = direction
    }
    
    /// Morceau joué en premier dans le sens enregistré. En bidirectionnel, c'est `track1`.
    public var leadingTrack: SavedTrackData {
        direction == .reverse ? track2 : track1
    }
    
    /// Morceau proposé ensuite. En bidirectionnel, c'est `track2`.
    public var followingTrack: SavedTrackData {
        direction == .reverse ? track1 : track2
    }
    
    public var linkSymbolName: String {
        direction == .both ? "arrow.left.and.right" : "arrow.right"
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, track1, track2, createdAt, notes, direction
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        track1 = try container.decode(SavedTrackData.self, forKey: .track1)
        track2 = try container.decode(SavedTrackData.self, forKey: .track2)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        if let raw = try container.decodeIfPresent(String.self, forKey: .direction),
           let parsed = FavoriteLinkDirection(rawValue: raw) {
            direction = parsed
        } else {
            direction = .both
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(track1, forKey: .track1)
        try container.encode(track2, forKey: .track2)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(direction, forKey: .direction)
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
            AppLogger.error("Erreur chargement favoris", category: .session, error: error)
            self.combos = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(combos)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error("Erreur sauvegarde favoris", category: .session, error: error)
        }
    }
    
    // MARK: - Actions Utilisateur
    
    /// Enregistre une combinaison entre deux morceaux.
    /// `direction` est relatif à l'ordre passé : `.forward` = track1 puis track2.
    /// L'ajout rapide (sans choix) reste bidirectionnel.
    @discardableResult
    public func saveCombo(
        track1: Track,
        track2: Track,
        notes: String? = nil,
        direction: FavoriteLinkDirection = .forward
    ) -> Bool {
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
            notes: notes,
            direction: direction
        )
        
        combos.insert(combo, at: 0)
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
        return true
    }
    
    /// Sens du combo tel qu'il doit s'afficher : morceau du haut (`trackA`) puis morceau du bas (`trackB`).
    public func displayedDirection(trackA: Track, trackB: Track) -> FavoriteLinkDirection? {
        guard let idx = comboIndex(matching: trackA, and: trackB) else { return nil }
        return displayedDirection(of: combos[idx], trackA: trackA, trackB: trackB)
    }
    
    /// Change le sens d'un combo déjà enregistré, sans perdre les infos des morceaux.
    @discardableResult
    public func updateDisplayedDirection(trackA: Track, trackB: Track, direction: FavoriteLinkDirection) -> Bool {
        guard let idx = comboIndex(matching: trackA, and: trackB) else { return false }
        let combo = combos[idx]
        let sameOrder = matches(trackA: combo.track1, trackB: trackA) && matches(trackA: combo.track2, trackB: trackB)
        let swapped = matches(trackA: combo.track1, trackB: trackB) && matches(trackA: combo.track2, trackB: trackA)
        
        if direction == .both || sameOrder {
            combos[idx].direction = direction
        } else if swapped {
            combos[idx].direction = direction == .forward ? .reverse : .forward
        } else {
            combos[idx].track1 = SavedTrackData(from: trackA)
            combos[idx].track2 = SavedTrackData(from: trackB)
            combos[idx].direction = direction
        }
        
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
    
    /// Morceaux à proposer pour le morceau en cours en tenant compte du sens enregistré et du mode d'affichage.
    /// Avec `respectingDirection: false`, renvoie le partenaire même si le sens enregistré ne correspond pas au mode
    /// (sert à garder le cœur allumé sur un morceau qui fait partie d'une transition favorite).
    public func getFavoriteTracks(
        for referenceTrack: Track,
        transitionMode: TransitionDirection = .next,
        respectingDirection: Bool = true
    ) -> [Track] {
        var results: [Track] = []
        var seenTitles = Set<String>()
        
        for combo in combos {
            guard let match = matchCombo(
                combo: combo,
                ref: referenceTrack,
                mode: transitionMode,
                respectingDirection: respectingDirection
            ) else {
                continue
            }
            let norm = Self.normalize(match.partner.title)
            guard !seenTitles.contains(norm) else { continue }
            seenTitles.insert(norm)
            var track = match.partner.toTrack(transitionCount: 0, referenceTrack: referenceTrack)
            track.direction = match.direction
            results.append(track)
        }
        return results
    }
    
    private func matchCombo(
        combo: FavoriteCombo,
        ref: Track,
        mode: TransitionDirection,
        respectingDirection: Bool
    ) -> (partner: SavedTrackData, direction: TransitionDirection)? {
        let refIs1 = matches(trackA: combo.track1, trackB: ref)
        let refIs2 = matches(trackA: combo.track2, trackB: ref)
        guard refIs1 || refIs2 else { return nil }
        
        let partner = refIs1 ? combo.track2 : combo.track1
        
        // Si on ne respecte pas la direction (utilisé uniquement pour vérifier l'existence du lien pour le cœur)
        if !respectingDirection {
            return (partner, .all)
        }
        
        // Si le combo est bidirectionnel (.both), valide dans tous les modes
        if combo.direction == .both {
            switch mode {
            case .next: return (partner, .next)
            case .previous: return (partner, .previous)
            case .all: return (partner, .all)
            }
        }
        
        // Combo directionnel :
        // .forward : track1 -> track2 (track1 en premier, track2 en second)
        // .reverse : track2 -> track1 (track2 en premier, track1 en second)
        let isTrack1First = (combo.direction == .forward)
        let firstTrack = isTrack1First ? combo.track1 : combo.track2
        let secondTrack = isTrack1First ? combo.track2 : combo.track1
        
        // ref est le premier morceau : le partenaire vient APRÈS ref
        if matches(trackA: firstTrack, trackB: ref) {
            if mode == .next || mode == .all {
                return (secondTrack, .next)
            } else {
                return nil
            }
        }
        
        // ref est le deuxième morceau : le partenaire vient AVANT ref
        if matches(trackA: secondTrack, trackB: ref) {
            if mode == .previous || mode == .all {
                return (firstTrack, .previous)
            } else {
                return nil
            }
        }
        
        return nil
    }
    
    private func comboIndex(matching trackA: Track, and trackB: Track) -> Int? {
        combos.firstIndex { combo in
            let sameOrder = matches(trackA: combo.track1, trackB: trackA) && matches(trackA: combo.track2, trackB: trackB)
            let swapped = matches(trackA: combo.track1, trackB: trackB) && matches(trackA: combo.track2, trackB: trackA)
            return sameOrder || swapped
        }
    }
    
    /// Traduit le sens stocké vers l'ordre affiché (haut = trackA, bas = trackB).
    private func displayedDirection(
        of combo: FavoriteCombo,
        trackA: Track,
        trackB: Track
    ) -> FavoriteLinkDirection {
        if combo.direction == .both { return .both }
        let sameOrder = matches(trackA: combo.track1, trackB: trackA) && matches(trackA: combo.track2, trackB: trackB)
        if sameOrder { return combo.direction }
        return combo.direction == .forward ? .reverse : .forward
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
