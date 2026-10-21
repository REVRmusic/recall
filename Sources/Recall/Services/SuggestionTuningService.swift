import Foundation
import SwiftUI
import Combine

/// État de réglage manuel d'une transition entre deux morceaux
public enum SuggestionTuningState: String, Codable, Equatable, Hashable, Sendable {
    case neutral
    case boosted   // Poussé plus haut dans les suggestions
    case demoted   // Moins proposé (pour casser la routine)
    case hidden    // Retiré des suggestions pour ce morceau
}

/// Enregistrement d'un réglage manuel pour une transition orientée
public struct TransitionTuningRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: String { "\(fromNormalized)__to__\(toNormalized)" }
    public let fromNormalized: String
    public let toNormalized: String
    public let fromTitle: String
    public let fromArtist: String
    public let toTitle: String
    public let toArtist: String
    public var state: SuggestionTuningState
    public var updatedAt: Date
    
    public init(
        fromTitle: String,
        fromArtist: String = "",
        toTitle: String,
        toArtist: String = "",
        state: SuggestionTuningState,
        updatedAt: Date = Date()
    ) {
        self.fromNormalized = SuggestionTuningService.normalize(fromTitle)
        self.toNormalized = SuggestionTuningService.normalize(toTitle)
        self.fromTitle = fromTitle
        self.fromArtist = fromArtist
        self.toTitle = toTitle
        self.toArtist = toArtist
        self.state = state
        self.updatedAt = updatedAt
    }
}

/// Instané thread-safe utilisable dans les tâches d'arrière-plan pour trier et filtrer les suggestions
public struct SuggestionTuningSnapshot: Sendable {
    public let records: [String: TransitionTuningRecord]
    
    public func state(reference: Track, candidate: Track, mode: TransitionDirection) -> SuggestionTuningState {
        let (from, to) = SuggestionTuningService.directionalPair(reference: reference, candidate: candidate, mode: mode)
        let key = SuggestionTuningService.recordKey(fromTitle: from.displayTitle, toTitle: to.displayTitle)
        return records[key]?.state ?? .neutral
    }
    
    public func isHidden(reference: Track, candidate: Track, mode: TransitionDirection) -> Bool {
        return state(reference: reference, candidate: candidate, mode: mode) == .hidden
    }
    
    public func scoreDelta(reference: Track, candidate: Track, mode: TransitionDirection) -> Double {
        switch state(reference: reference, candidate: candidate, mode: mode) {
        case .boosted:
            return 100.0
        case .demoted:
            return -100.0
        case .hidden, .neutral:
            return 0.0
        }
    }
}

/// Service de gestion et de persistance des ajustements manuels de score et de visibilité des suggestions
@MainActor
public class SuggestionTuningService: ObservableObject {
    public static let shared = SuggestionTuningService()
    
    @Published public private(set) var records: [String: TransitionTuningRecord] = [:]
    
    private let storageURL: URL
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recallDir = appSupport.appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: recallDir, withIntermediateDirectories: true)
        self.storageURL = recallDir.appendingPathComponent("suggestion_tunings.json")
        loadRecords()
    }
    
    // MARK: - Normalisation
    
    nonisolated public static func normalize(_ str: String) -> String {
        return FavoriteCombosService.normalize(str)
    }
    
    nonisolated public static func recordKey(fromTitle: String, toTitle: String) -> String {
        return "\(normalize(fromTitle))__to__\(normalize(toTitle))"
    }
    
    // MARK: - Direction orientée selon le mode d'affichage
    
    nonisolated public static func directionalPair(
        reference: Track,
        candidate: Track,
        mode: TransitionDirection
    ) -> (from: Track, to: Track) {
        switch mode {
        case .next:
            return (from: reference, to: candidate)
        case .previous:
            return (from: candidate, to: reference)
        case .all:
            if candidate.direction == .previous {
                return (from: candidate, to: reference)
            } else {
                return (from: reference, to: candidate)
            }
        }
    }
    
    // MARK: - Actions Utilisateur
    
    public func boost(reference: Track, candidate: Track, mode: TransitionDirection) {
        let (from, to) = Self.directionalPair(reference: reference, candidate: candidate, mode: mode)
        setRecord(from: from, to: to, state: .boosted)
        if mode == .all && candidate.direction == .all {
            setRecord(from: to, to: from, state: .boosted)
        }
        notifyAndSave()
    }
    
    public func demote(reference: Track, candidate: Track, mode: TransitionDirection) {
        let (from, to) = Self.directionalPair(reference: reference, candidate: candidate, mode: mode)
        setRecord(from: from, to: to, state: .demoted)
        if mode == .all && candidate.direction == .all {
            setRecord(from: to, to: from, state: .demoted)
        }
        notifyAndSave()
    }
    
    public func hide(reference: Track, candidate: Track, mode: TransitionDirection) {
        let (from, to) = Self.directionalPair(reference: reference, candidate: candidate, mode: mode)
        setRecord(from: from, to: to, state: .hidden)
        if mode == .all && candidate.direction == .all {
            setRecord(from: to, to: from, state: .hidden)
        }
        notifyAndSave()
    }
    
    public func reset(reference: Track, candidate: Track, mode: TransitionDirection) {
        let (from, to) = Self.directionalPair(reference: reference, candidate: candidate, mode: mode)
        removeRecord(from: from, to: to)
        if mode == .all && candidate.direction == .all {
            removeRecord(from: to, to: from)
        }
        notifyAndSave()
    }
    
    public func removeRecord(byId id: String) {
        records.removeValue(forKey: id)
        notifyAndSave()
    }
    
    public func clearAll() {
        records.removeAll()
        notifyAndSave()
    }
    
    // MARK: - Consultation
    
    public func state(reference: Track, candidate: Track, mode: TransitionDirection) -> SuggestionTuningState {
        let (from, to) = Self.directionalPair(reference: reference, candidate: candidate, mode: mode)
        let key = Self.recordKey(fromTitle: from.displayTitle, toTitle: to.displayTitle)
        return records[key]?.state ?? .neutral
    }
    
    public func isHidden(reference: Track, candidate: Track, mode: TransitionDirection) -> Bool {
        return state(reference: reference, candidate: candidate, mode: mode) == .hidden
    }
    
    public func scoreDelta(reference: Track, candidate: Track, mode: TransitionDirection) -> Double {
        switch state(reference: reference, candidate: candidate, mode: mode) {
        case .boosted:
            return 100.0
        case .demoted:
            return -100.0
        case .hidden, .neutral:
            return 0.0
        }
    }
    
    public func snapshot() -> SuggestionTuningSnapshot {
        return SuggestionTuningSnapshot(records: records)
    }
    
    // MARK: - Interne
    
    private func setRecord(from: Track, to: Track, state: SuggestionTuningState) {
        let key = Self.recordKey(fromTitle: from.displayTitle, toTitle: to.displayTitle)
        let record = TransitionTuningRecord(
            fromTitle: from.displayTitle,
            fromArtist: from.displayArtist,
            toTitle: to.displayTitle,
            toArtist: to.displayArtist,
            state: state
        )
        records[key] = record
    }
    
    private func removeRecord(from: Track, to: Track) {
        let key = Self.recordKey(fromTitle: from.displayTitle, toTitle: to.displayTitle)
        records.removeValue(forKey: key)
    }
    
    private func notifyAndSave() {
        saveToDisk()
        SeratoMonitorService.shared.refreshSuggestions()
    }
    
    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            self.records = [:]
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([TransitionTuningRecord].self, from: data)
            var map: [String: TransitionTuningRecord] = [:]
            for rec in decoded {
                map[rec.id] = rec
            }
            self.records = map
        } catch {
            AppLogger.error("Erreur chargement tunings", category: .session, error: error)
            self.records = [:]
        }
    }
    
    private func saveToDisk() {
        do {
            let list = Array(records.values)
            let data = try JSONEncoder().encode(list)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error("Erreur sauvegarde tunings", category: .session, error: error)
        }
    }
}
