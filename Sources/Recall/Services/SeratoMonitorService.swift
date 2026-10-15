import Foundation
import Combine
import SwiftUI
import AppKit

@MainActor
public class SeratoMonitorService: ObservableObject {
    public static let shared = SeratoMonitorService()
    
    @Published public var currentTrack: Track?
    @Published public var deck1Track: Track?
    @Published public var deck2Track: Track?
    @Published public var activeDeckSelection: String = "AUTO" // "AUTO", "1", "2"
    @Published public var suggestions: [Track] = []
    @Published public var historySuggestions: [Track] = []
    @Published public var favoriteSuggestions: [Track] = []
    @Published public var isLoading: Bool = false
    @Published public var isSeratoConnected: Bool = false
    @Published public var lastCheckTime: Date = Date()
    @Published public var manualTrackOverride: Track? = nil
    @Published public var previousTrack: Track? = nil
    @Published public var pendingComboConfirmation: ComboConfirmationData? = nil
    
    private let dbService: SeratoDatabaseService
    private var timer: Timer?
    private var lastKnownMaxEntryId: Int = -1
    private var cancellables = Set<AnyCancellable>()
    
    public init(dbService: SeratoDatabaseService = SeratoDatabaseService()) {
        self.dbService = dbService
        startMonitoring()
        
        // Rafraîchir les suggestions quand les paramètres changent
        UserSettings.shared.$historyDaysLookback
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshSuggestions()
                }
            }
            .store(in: &cancellables)
            
        UserSettings.shared.$maxSuggestions
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshSuggestions()
                }
            }
            .store(in: &cancellables)
            
        UserSettings.shared.$isFavoritesFilterActive
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateActiveSuggestions()
                }
            }
            .store(in: &cancellables)
    }
    
    public func startMonitoring() {
        stopMonitoring()
        checkDatabaseUpdates()
        
        // Sondage léger toutes les 1.5 secondes
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkDatabaseUpdates()
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Vérifie si de nouveaux morceaux ont été joués dans Serato avec détection stricte des platines actives
    public func checkDatabaseUpdates() {
        lastCheckTime = Date()
        
        // 1. Vérifier si l'application Serato DJ est activement lancée sur macOS
        let runningApps = NSWorkspace.shared.runningApplications
        let isSeratoRunning = runningApps.contains { app in
            let name = app.localizedName?.lowercased() ?? ""
            let id = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains("serato") || id.contains("com.serato")
        }
        
        guard isSeratoRunning else {
            if isSeratoConnected {
                isSeratoConnected = false
            }
            deck1Track = nil
            deck2Track = nil
            if manualTrackOverride == nil {
                if currentTrack != nil {
                    currentTrack = nil
                    suggestions = []
                    historySuggestions = []
                    favoriteSuggestions = []
                }
            }
            return
        }
        
        if !isSeratoConnected {
            isSeratoConnected = true
        }
        
        Task.detached(priority: .userInitiated) { [dbService, lastKnownMaxEntryId] in
            let activeState = dbService.fetchActiveDecks()
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                self.deck1Track = activeState.deck1
                self.deck2Track = activeState.deck2
                
                // Synchronisation de l'historique de session
                SessionHistoryService.shared.syncWithDatabase(dbService: self.dbService)
                
                let latestEntryId = activeState.latestEntryId
                
                // Si la platine sélectionnée manuellement n'est plus active, retour automatique en mode AUTO
                if self.activeDeckSelection == "1" && self.deck1Track == nil {
                    self.activeDeckSelection = "AUTO"
                } else if self.activeDeckSelection == "2" && self.deck2Track == nil {
                    self.activeDeckSelection = "AUTO"
                }
                
                // Déterminer la piste de référence active
                let newRefTrack: Track?
                if let manual = self.manualTrackOverride {
                    newRefTrack = manual
                } else if self.activeDeckSelection == "1" {
                    newRefTrack = self.deck1Track
                } else if self.activeDeckSelection == "2" {
                    newRefTrack = self.deck2Track
                } else {
                    // Mode AUTO :
                    if let d1 = self.deck1Track, let d2 = self.deck2Track {
                        let d1Time = d1.playedAt?.timeIntervalSince1970 ?? 0
                        let d2Time = d2.playedAt?.timeIntervalSince1970 ?? 0
                        newRefTrack = d1Time >= d2Time ? d1 : d2
                    } else {
                        newRefTrack = self.deck1Track ?? self.deck2Track
                    }
                }
                
                let trackChanged = (self.currentTrack?.id != newRefTrack?.id) ||
                                   (self.currentTrack?.displayTitle != newRefTrack?.displayTitle)
                
                if trackChanged || (latestEntryId > 0 && latestEntryId != lastKnownMaxEntryId) {
                    if latestEntryId > 0 {
                        self.lastKnownMaxEntryId = latestEntryId
                    }
                    if trackChanged, let old = self.currentTrack, old.displayTitle != newRefTrack?.displayTitle {
                        self.previousTrack = old
                    }
                    self.currentTrack = newRefTrack
                    self.refreshSuggestions()
                }
            }
        }
    }
    
    /// Met à jour `suggestions` selon le filtre favoris actif
    public func updateActiveSuggestions() {
        if UserSettings.shared.isFavoritesFilterActive {
            self.suggestions = self.favoriteSuggestions
        } else {
            self.suggestions = self.historySuggestions
        }
    }
    
    /// Recalcule les suggestions pour la piste de référence actuelle
    public func refreshSuggestions() {
        guard let ref = currentTrack else {
            suggestions = []
            historySuggestions = []
            favoriteSuggestions = []
            return
        }
        
        isLoading = true
        let days = UserSettings.shared.historyDaysLookback
        let maxResults = UserSettings.shared.maxSuggestions
        
        Task.detached(priority: .userInitiated) { [dbService] in
            let historyResults = dbService.fetchTransitions(
                for: ref,
                daysLookback: days,
                maxResults: maxResults
            )
            
            // Récupération des favoris manuels enregistrés pour ce morceau
            let manualFavorites = await MainActor.run {
                FavoriteCombosService.shared.getFavoriteTracks(for: ref)
            }
            
            // Marquage des morceaux déjà joués lors de la session en cours
            let sessionPlayedSet = await MainActor.run {
                SessionHistoryService.shared.playedNormalizedTitles
            }
            
            let favTitlesSet = Set(manualFavorites.map { FavoriteCombosService.normalize($0.displayTitle) })
            let favFilesSet = Set(manualFavorites.filter { !$0.fileName.isEmpty }.map { FavoriteCombosService.normalize($0.fileName) })
            
            func isFavTrack(_ trk: Track) -> Bool {
                let normTitle = FavoriteCombosService.normalize(trk.displayTitle)
                if favTitlesSet.contains(normTitle) { return true }
                if !trk.fileName.isEmpty && favFilesSet.contains(FavoriteCombosService.normalize(trk.fileName)) { return true }
                return false
            }
            
            func isSessionPlayedTrack(_ trk: Track) -> Bool {
                let normTitle = FavoriteCombosService.normalize(trk.displayTitle)
                if sessionPlayedSet.contains(normTitle) { return true }
                if !trk.fileName.isEmpty && sessionPlayedSet.contains(FavoriteCombosService.normalize(trk.fileName)) { return true }
                return false
            }
            
            // 1. Liste PUREMENT historique : ordonnée strictement par transitionCount DESC comme dans Serato
            // Si une transition fait partie des combos favoris, elle conserve son classement naturel et reçoit isFavorite = true
            let pureHistoryList: [Track] = historyResults.map { trk in
                var updated = trk
                if isFavTrack(trk) {
                    updated.isFavorite = true
                }
                if isSessionPlayedTrack(trk) {
                    updated.isPlayedInSession = true
                }
                return updated
            }
            
            // 2. Liste PUREMENT des favoris pour ce morceau
            // Contient exclusivement les combinaisons favorites mémorisées pour cette piste
            var pureFavoritesList: [Track] = []
            var seenFavTitles = Set<String>()
            
            for fav in manualFavorites {
                let norm = FavoriteCombosService.normalize(fav.displayTitle)
                guard !seenFavTitles.contains(norm) else { continue }
                seenFavTitles.insert(norm)
                
                var trackToAdd: Track
                // Si la combinaison favorite existe aussi dans l'historique Serato, on récupère ses statistiques réelles
                if let existingInHistory = pureHistoryList.first(where: {
                    FavoriteCombosService.normalize($0.displayTitle) == norm ||
                    (!fav.fileName.isEmpty && !$0.fileName.isEmpty && FavoriteCombosService.normalize($0.fileName) == FavoriteCombosService.normalize(fav.fileName))
                }) {
                    trackToAdd = existingInHistory
                    trackToAdd.isFavorite = true
                } else {
                    trackToAdd = fav
                    trackToAdd.isFavorite = true
                    if isSessionPlayedTrack(trackToAdd) {
                        trackToAdd.isPlayedInSession = true
                    }
                }
                pureFavoritesList.append(trackToAdd)
            }
            
            let finalFavorites = pureFavoritesList
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.historySuggestions = pureHistoryList
                self.favoriteSuggestions = finalFavorites
                self.updateActiveSuggestions()
                self.isLoading = false
            }
        }
    }
    
    public func selectDeck(_ deck: String) {
        activeDeckSelection = deck
        manualTrackOverride = nil
        
        if deck == "1", let d1 = deck1Track {
            currentTrack = d1
        } else if deck == "2", let d2 = deck2Track {
            currentTrack = d2
        } else {
            checkDatabaseUpdates()
            return
        }
        refreshSuggestions()
    }
    
    /// Force une synchronisation immédiate des morceaux joués selon les critères de session et rafraîchit
    public func triggerSessionResync() {
        SessionHistoryService.shared.syncWithDatabase(dbService: self.dbService)
        refreshSuggestions()
    }
    
    public func setManualReferenceTrack(_ track: Track) {
        manualTrackOverride = track
        currentTrack = track
        activeDeckSelection = "MANUAL"
        refreshSuggestions()
    }
    
    public func clearManualOverride() {
        manualTrackOverride = nil
        activeDeckSelection = "AUTO"
        checkDatabaseUpdates()
    }
    
    // MARK: - Gestion de la confirmation de combo favori
    
    public func requestComboConfirmation(trackA: Track, trackB: Track, source: String? = nil) {
        let isSaved = FavoriteCombosService.shared.isComboFavorite(track1: trackA, track2: trackB)
        self.pendingComboConfirmation = ComboConfirmationData(
            trackA: trackA,
            trackB: trackB,
            isAlreadySaved: isSaved,
            sourceDescription: source
        )
    }
    
    public func dismissComboConfirmation() {
        self.pendingComboConfirmation = nil
    }
    
    public func confirmPendingCombo() {
        guard let pending = pendingComboConfirmation else { return }
        if pending.isAlreadySaved {
            FavoriteCombosService.shared.removeCombo(track1: pending.trackA, track2: pending.trackB)
        } else {
            FavoriteCombosService.shared.saveCombo(track1: pending.trackA, track2: pending.trackB)
        }
        self.pendingComboConfirmation = nil
    }
}

/// Modèle pour les données de confirmation d'une combinaison favorite
public struct ComboConfirmationData: Identifiable, Equatable {
    public let id = UUID()
    public let trackA: Track
    public let trackB: Track
    public let isAlreadySaved: Bool
    public let sourceDescription: String?
    
    public init(trackA: Track, trackB: Track, isAlreadySaved: Bool, sourceDescription: String? = nil) {
        self.trackA = trackA
        self.trackB = trackB
        self.isAlreadySaved = isAlreadySaved
        self.sourceDescription = sourceDescription
    }
    
    public static func == (lhs: ComboConfirmationData, rhs: ComboConfirmationData) -> Bool {
        lhs.id == rhs.id
    }
}
