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
    @Published public var activeDJSoftware: DJSoftwareMode = .serato
    @Published public var isSeratoConnected: Bool = false
    @Published public var isRekordboxConnected: Bool = false
    @Published public var lastCheckTime: Date = Date()
    @Published public var manualTrackOverride: Track? = nil
    @Published public var previousTrack: Track? = nil
    @Published public var pendingComboConfirmation: ComboConfirmationData? = nil
    
    private let dbService: SeratoDatabaseService
    private var timer: Timer?
    private var lastKnownMaxEntryId: Int = -1
    private var cancellables = Set<AnyCancellable>()
    private var isCheckingDatabase: Bool = false
    private var lastHistorySyncTime: Date = .distantPast
    
    public init(dbService: SeratoDatabaseService = SeratoDatabaseService()) {
        self.dbService = dbService
        startMonitoring()
        
        // Surveillance active de l'extinction de Serato (Point 6 : zéro conflit de fermeture)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleApplicationTermination(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // Rafraîchir les suggestions quand les paramètres changent
        UserSettings.shared.$djSoftwareMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkDatabaseUpdates()
                }
            }
            .store(in: &cancellables)
            
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
            
        UserSettings.shared.$cumulateVariantSuggestions
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
            
        UserSettings.shared.$transitionDirection
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshSuggestions()
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
    
    /// Vérifie si de nouveaux morceaux ont été joués dans Serato ou Rekordbox avec détection automatique
    public func checkDatabaseUpdates() {
        lastCheckTime = Date()
        
        // 1. Détection des applications DJ en cours d'exécution sur macOS (Point 6 : ignore immédiatement les apps en cours d'extinction)
        let runningApps = NSWorkspace.shared.runningApplications
        let isSeratoRunning = runningApps.contains { app in
            guard !app.isTerminated else { return false }
            let name = app.localizedName?.lowercased() ?? ""
            let id = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains("serato") || id.contains("com.serato")
        }
        let isRekordboxRunning = runningApps.contains { app in
            guard !app.isTerminated else { return false }
            let name = app.localizedName?.lowercased() ?? ""
            let id = app.bundleIdentifier?.lowercased() ?? ""
            return name.contains("rekordbox") || id.contains("com.pioneerdj.rekordboxdj")
        }
        
        if self.isSeratoConnected != isSeratoRunning {
            self.isSeratoConnected = isSeratoRunning
            AppLogger.info("Statut connexion Serato DJ Pro : \(isSeratoRunning ? "Connecté" : "Déconnecté")", category: .seratoDB)
        }
        if self.isRekordboxConnected != isRekordboxRunning {
            self.isRekordboxConnected = isRekordboxRunning
            AppLogger.info("Statut connexion Rekordbox : \(isRekordboxRunning ? "Connecté" : "Déconnecté")", category: .rekordbox)
        }
        
        // 2. Détermination du mode logiciel effectif
        let mode = UserSettings.shared.djSoftwareMode
        let effective: DJSoftwareMode
        switch mode {
        case .auto:
            let frontId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() ?? ""
            let frontName = NSWorkspace.shared.frontmostApplication?.localizedName?.lowercased() ?? ""
            if isRekordboxRunning && !isSeratoRunning {
                effective = .rekordbox
            } else if isSeratoRunning && !isRekordboxRunning {
                effective = .serato
            } else if isRekordboxRunning && isSeratoRunning {
                if frontId.contains("rekordbox") || frontName.contains("rekordbox") {
                    effective = .rekordbox
                } else if frontId.contains("serato") || frontName.contains("serato") {
                    effective = .serato
                } else {
                    effective = activeDJSoftware
                }
            } else {
                effective = .serato
            }
        case .serato:
            effective = .serato
        case .rekordbox:
            effective = .rekordbox
        }
        
        if activeDJSoftware != effective {
            AppLogger.info("Basculement logiciel DJ actif : \(effective.label)", category: .system)
            activeDJSoftware = effective
            if effective == .rekordbox {
                RekordboxService.shared.loadCollectionIfNeeded()
            }
            refreshSuggestions()
        }
        
        // --- BRANCHE REKORDBOX (Détection Temps Réel) ---
        if effective == .rekordbox {
            RekordboxService.shared.loadCollectionIfNeeded()
            
            guard isRekordboxRunning else {
                deck1Track = nil
                deck2Track = nil
                if manualTrackOverride == nil && currentTrack != nil {
                    currentTrack = nil
                    suggestions = []
                    historySuggestions = []
                    favoriteSuggestions = []
                }
                return
            }
            
            if let activeState = RekordboxService.shared.fetchActiveDecks() {
                self.deck1Track = activeState.deck1
                self.deck2Track = activeState.deck2
                
                // Si la platine sélectionnée manuellement n'a plus de morceau, retour automatique en mode AUTO
                if self.activeDeckSelection == "1" && self.deck1Track == nil {
                    self.activeDeckSelection = "AUTO"
                } else if self.activeDeckSelection == "2" && self.deck2Track == nil {
                    self.activeDeckSelection = "AUTO"
                }
                
                // Déterminer la piste de référence active selon la sélection du DJ
                let newRefTrack: Track?
                if let manual = self.manualTrackOverride {
                    newRefTrack = manual
                } else if self.activeDeckSelection == "1" {
                    newRefTrack = self.deck1Track
                } else if self.activeDeckSelection == "2" {
                    newRefTrack = self.deck2Track
                } else {
                    // Mode AUTO :
                    if activeState.activeDeckNumber == "2" {
                        newRefTrack = self.deck2Track ?? self.deck1Track
                    } else {
                        newRefTrack = self.deck1Track ?? self.deck2Track
                    }
                }
                
                let trackChanged = (self.currentTrack?.id != newRefTrack?.id) ||
                                   (self.currentTrack?.displayTitle != newRefTrack?.displayTitle)
                
                if trackChanged {
                    if let track = newRefTrack {
                        let artistPrefix = track.artist.isEmpty ? "" : "\(track.artist) – "
                        AppLogger.info("Morceau Rekordbox détecté : \(artistPrefix)\(track.title) [\(track.displayKey)]", category: .rekordbox)
                    }
                    self.currentTrack = newRefTrack
                    self.refreshSuggestions()
                }
            } else if let manual = manualTrackOverride {
                if currentTrack?.id != manual.id {
                    currentTrack = manual
                    refreshSuggestions()
                }
            }
            return
        }
        
        // --- BRANCHE SERATO DJ PRO ---
        guard isSeratoRunning else {
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
        
        guard !isCheckingDatabase else { return }
        isCheckingDatabase = true
        
        Task.detached(priority: .userInitiated) { [dbService, lastKnownMaxEntryId] in
            let activeState = dbService.fetchActiveDecks()
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                defer { self.isCheckingDatabase = false }
                
                let decksChanged = (self.deck1Track?.id != activeState.deck1?.id) ||
                                   (self.deck1Track?.displayTitle != activeState.deck1?.displayTitle) ||
                                   (self.deck2Track?.id != activeState.deck2?.id) ||
                                   (self.deck2Track?.displayTitle != activeState.deck2?.displayTitle)
                
                let latestEntryId = activeState.latestEntryId
                let entryChanged = (latestEntryId > 0 && latestEntryId != self.lastKnownMaxEntryId)
                
                self.deck1Track = activeState.deck1
                self.deck2Track = activeState.deck2
                
                // Optimisation anti-sollicitation disque Serato (Point 3) :
                // On synchronise l'historique complet UNIQUEMENT si un morceau change de platine,
                // si une nouvelle entrée est écrite par Serato, ou en battement périodique à basse fréquence (toutes les 15s).
                let now = Date()
                let shouldSyncHistory = decksChanged || entryChanged || (now.timeIntervalSince(self.lastHistorySyncTime) >= 15.0)
                if shouldSyncHistory {
                    self.lastHistorySyncTime = now
                    SessionHistoryService.shared.syncWithDatabase(dbService: self.dbService)
                }
                
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
                    if trackChanged, let track = newRefTrack {
                        let artistPrefix = track.artist.isEmpty ? "" : "\(track.artist) – "
                        AppLogger.info("Morceau Serato détecté : \(artistPrefix)\(track.title) [\(track.displayKey)]", category: .seratoDB)
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
            isLoading = false
            return
        }
        
        isLoading = true
        
        // --- 1. Mode Rekordbox ---
        if activeDJSoftware == .rekordbox {
            let maxResults = UserSettings.shared.maxSuggestions
            let minTransitions = UserSettings.shared.minTransitionsCount
            let bpmTol = UserSettings.shared.bpmTolerancePercent
            let harmFilter = UserSettings.shared.isHarmonicFilterActive
            let bpmFilter = UserSettings.shared.isBpmFilterActive
            let favOnly = UserSettings.shared.isFavoritesFilterActive
            let direction = UserSettings.shared.transitionDirection
            
            let (routines, favs, harmonic) = RekordboxService.shared.findNextSuggestions(
                for: ref,
                direction: direction,
                maxResults: maxResults,
                minTransitions: minTransitions,
                tolerancePercent: bpmTol,
                harmonicFilter: harmFilter,
                bpmFilter: bpmFilter,
                favoritesOnly: favOnly
            )
            
            self.historySuggestions = routines
            self.favoriteSuggestions = favs
            
            if favOnly {
                self.suggestions = favs
            } else {
                var combined = routines
                for f in favs {
                    let norm = FavoriteCombosService.normalize(f.displayTitle)
                    if let idx = combined.firstIndex(where: { FavoriteCombosService.normalize($0.displayTitle) == norm }) {
                        combined[idx].isFavorite = true
                    } else {
                        combined.append(f)
                    }
                }
                
                let existingIds = Set(combined.map { $0.id })
                for h in harmonic where !existingIds.contains(h.id) {
                    combined.append(h)
                    if combined.count >= maxResults { break }
                }
                
                func rekordboxRankingScore(for trk: Track) -> Double {
                    if trk.transitionCount >= 2 {
                        return Double(trk.transitionCount) + (trk.isFavorite ? 0.05 : 0.0)
                    }
                    if trk.isFavorite {
                        return trk.transitionCount == 1 ? 1.55 : 1.50
                    }
                    if trk.transitionCount == 1 {
                        return 1.0
                    }
                    return 0.0
                }
                
                combined.sort(by: { (t1: Track, t2: Track) -> Bool in
                    let s1 = rekordboxRankingScore(for: t1)
                    let s2 = rekordboxRankingScore(for: t2)
                    if abs(s1 - s2) > 0.001 { return s1 > s2 }
                    let time1 = t1.playedAt?.timeIntervalSince1970 ?? 0
                    let time2 = t2.playedAt?.timeIntervalSince1970 ?? 0
                    if time1 != time2 { return time1 > time2 }
                    return t1.displayTitle < t2.displayTitle
                })
                
                self.historySuggestions = combined
                self.suggestions = combined
            }
            
            // Secours intelligent : si la collection XML Rekordbox n'a pas encore de routines enregistrées,
            // proposer les transitions historiques connues depuis la base locale Serato
            if self.suggestions.isEmpty {
                let seratoTransitions = self.dbService.fetchTransitions(for: ref, direction: direction, daysLookback: 365, maxResults: maxResults)
                if !seratoTransitions.isEmpty {
                    self.suggestions = seratoTransitions
                }
            }
            
            self.isLoading = false
            return
        }
        
        // --- 2. Mode Serato DJ Pro ---
        let days = UserSettings.shared.historyDaysLookback
        let maxResults = UserSettings.shared.maxSuggestions
        let direction = UserSettings.shared.transitionDirection
        
        Task.detached(priority: .userInitiated) { [dbService] in
            let historyResults = dbService.fetchTransitions(
                for: ref,
                direction: direction,
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
            
            // 3. Intégration et priorisation des combos favoris dans la liste classique :
            // Les combos favoris sont intégrés et classés juste au-dessus des enchaînements
            // réalisés une seule fois (1x) pour s'inscrire naturellement dans la routine du DJ.
            var combinedClassic = pureHistoryList
            for fav in finalFavorites {
                let norm = FavoriteCombosService.normalize(fav.displayTitle)
                if let existingIndex = combinedClassic.firstIndex(where: {
                    FavoriteCombosService.normalize($0.displayTitle) == norm ||
                    (!fav.fileName.isEmpty && !$0.fileName.isEmpty && FavoriteCombosService.normalize($0.fileName) == FavoriteCombosService.normalize(fav.fileName))
                }) {
                    combinedClassic[existingIndex].isFavorite = true
                } else {
                    combinedClassic.append(fav)
                }
            }
            
            func rankingScore(for trk: Track) -> Double {
                if trk.transitionCount >= 2 {
                    return Double(trk.transitionCount) + (trk.isFavorite ? 0.05 : 0.0)
                }
                if trk.isFavorite {
                    // Les combos favoris (1x ou 0x) sont positionnés au-dessus des 1x (score 1.0)
                    return trk.transitionCount == 1 ? 1.55 : 1.50
                }
                if trk.transitionCount == 1 {
                    return 1.0
                }
                return 0.0
            }
            
            combinedClassic.sort(by: { (t1: Track, t2: Track) -> Bool in
                let s1 = rankingScore(for: t1)
                let s2 = rankingScore(for: t2)
                if abs(s1 - s2) > 0.001 {
                    return s1 > s2
                }
                let time1 = t1.playedAt?.timeIntervalSince1970 ?? 0
                let time2 = t2.playedAt?.timeIntervalSince1970 ?? 0
                if time1 != time2 {
                    return time1 > time2
                }
                return t1.displayTitle < t2.displayTitle
            })
            
            let finalHistory = combinedClassic
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.historySuggestions = finalHistory
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
        if activeDJSoftware == .rekordbox {
            currentTrack = nil
            suggestions = []
            historySuggestions = []
            favoriteSuggestions = []
        }
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
    
    // MARK: - Gestion de l'extinction de Serato (Zéro conflit)
    
    @objc private func handleApplicationTermination(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        let name = app.localizedName?.lowercased() ?? ""
        let id = app.bundleIdentifier?.lowercased() ?? ""
        if name.contains("serato") || id.contains("com.serato") {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSeratoConnected = false
                self.deck1Track = nil
                self.deck2Track = nil
                if self.manualTrackOverride == nil && self.currentTrack != nil {
                    self.currentTrack = nil
                    self.suggestions = []
                    self.historySuggestions = []
                    self.favoriteSuggestions = []
                }
            }
        }
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
