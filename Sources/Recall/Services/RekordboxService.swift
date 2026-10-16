import Foundation
import Combine
import SwiftUI
import AppKit
import ApplicationServices

/// État en direct des platines Rekordbox (morceaux chargés, BPM, Tonalité, état de lecture)
public struct RekordboxActiveDecksState: @unchecked Sendable {
    public let deck1: Track?
    public let deck2: Track?
    public let deck1ElapsedSeconds: Int
    public let deck2ElapsedSeconds: Int
    public let isDeck1Playing: Bool
    public let isDeck2Playing: Bool
    public let activeDeckNumber: String // "1" ou "2"
    
    public init(
        deck1: Track?,
        deck2: Track?,
        deck1ElapsedSeconds: Int = 0,
        deck2ElapsedSeconds: Int = 0,
        isDeck1Playing: Bool = false,
        isDeck2Playing: Bool = false,
        activeDeckNumber: String = "1"
    ) {
        self.deck1 = deck1
        self.deck2 = deck2
        self.deck1ElapsedSeconds = deck1ElapsedSeconds
        self.deck2ElapsedSeconds = deck2ElapsedSeconds
        self.isDeck1Playing = isDeck1Playing
        self.isDeck2Playing = isDeck2Playing
        self.activeDeckNumber = activeDeckNumber
    }
}

/// Service de gestion et d'analyse de la collection Pioneer DJ Rekordbox (via pont XML officiel)
/// - Lit et analyse l'ensemble des morceaux, clés Camelot et BPM
/// - Détecte toutes les routines d'enchaînements historiques à partir des playlists et historiques de sets
/// - Fonctionne à 100 % hors-ligne sans impact sur Rekordbox
@MainActor
public class RekordboxService: ObservableObject {
    public static let shared = RekordboxService()
    
    @Published public private(set) var isLoaded: Bool = false
    @Published public private(set) var isParsing: Bool = false
    @Published public private(set) var totalTracksCount: Int = 0
    @Published public private(set) var totalTransitionsCount: Int = 0
    @Published public private(set) var totalPlaylistsCount: Int = 0
    @Published public private(set) var currentXmlPath: String = ""
    @Published public private(set) var lastLoadedDate: Date? = nil
    @Published public private(set) var errorMessage: String? = nil
    
    @Published public private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    
    // Index en mémoire pour recherche instantanée (sub-milliseconde)
    private var tracksById: [String: Track] = [:]
    private var tracksList: [Track] = []
    // transitionMap[fromTrackId][toTrackId] = count
    private var transitionMap: [String: [String: Int]] = [:]
    private var lastXmlModificationDate: Date? = nil
    
    public init() {
        loadCollectionIfNeeded()
    }
    
    /// Ouvre les Réglages Système macOS directement sur le panneau d'Accessibilité
    public func openAccessibilityPreferences() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Charge la collection XML Rekordbox si elle n'est pas encore en mémoire ou si le fichier a changé
    public func loadCollectionIfNeeded() {
        let xmlPath = UserSettings.shared.effectiveRekordboxXmlPath
        guard !xmlPath.isEmpty else { return }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: xmlPath) else {
            errorMessage = "Fichier XML introuvable : \(xmlPath)"
            return
        }
        
        let fileAttrs = try? fm.attributesOfItem(atPath: xmlPath)
        let modDate = fileAttrs?[.modificationDate] as? Date
        
        if isLoaded && xmlPath == currentXmlPath && modDate == lastXmlModificationDate {
            return // Déjà à jour
        }
        
        reloadCollection(from: xmlPath)
    }
    
    /// Recharge la collection Rekordbox depuis un fichier XML en tâche de fond ultra-rapide
    public func reloadCollection(from path: String? = nil) {
        let targetPath = path ?? UserSettings.shared.effectiveRekordboxXmlPath
        guard !targetPath.isEmpty else {
            errorMessage = "Chemin Rekordbox XML vide"
            return
        }
        
        let fm = FileManager.default
        guard fm.fileExists(atPath: targetPath) else {
            errorMessage = "Fichier Rekordbox XML introuvable : \(targetPath)"
            return
        }
        
        isParsing = true
        errorMessage = nil
        
        let url = URL(fileURLWithPath: targetPath)
        let modDate = (try? fm.attributesOfItem(atPath: targetPath))?[.modificationDate] as? Date
        
        Task.detached(priority: .userInitiated) {
            let parserDelegate = RekordboxXmlParserDelegate()
            if let xmlParser = XMLParser(contentsOf: url) {
                xmlParser.delegate = parserDelegate
                xmlParser.shouldProcessNamespaces = false
                xmlParser.shouldReportNamespacePrefixes = false
                xmlParser.shouldResolveExternalEntities = false
                
                let success = xmlParser.parse()
                let parseErrorMsg = xmlParser.parserError?.localizedDescription
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isParsing = false
                    
                    if success {
                        self.tracksById = parserDelegate.tracksById
                        self.tracksList = parserDelegate.tracksList
                        self.transitionMap = parserDelegate.transitionMap
                        self.totalTracksCount = parserDelegate.tracksList.count
                        self.totalPlaylistsCount = parserDelegate.playlistCount
                        self.totalTransitionsCount = parserDelegate.totalTransitionsCount
                        self.currentXmlPath = targetPath
                        self.lastXmlModificationDate = modDate
                        self.lastLoadedDate = Date()
                        self.isLoaded = true
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = parseErrorMsg ?? "Erreur de lecture du XML Rekordbox"
                    }
                }
            } else {
                await MainActor.run { [weak self] in
                    self?.isParsing = false
                    self?.errorMessage = "Impossible d'ouvrir le fichier XML Rekordbox"
                }
            }
        }
    }
    
    /// Trouve les meilleures suggestions pour un morceau de référence dans Rekordbox
    public func findNextSuggestions(
        for currentTrack: Track,
        maxResults: Int = UserSettings.shared.maxSuggestions,
        minTransitions: Int = UserSettings.shared.minTransitionsCount,
        tolerancePercent: Double = UserSettings.shared.bpmTolerancePercent,
        harmonicFilter: Bool = UserSettings.shared.isHarmonicFilterActive,
        bpmFilter: Bool = UserSettings.shared.isBpmFilterActive,
        favoritesOnly: Bool = UserSettings.shared.isFavoritesFilterActive
    ) -> (routines: [Track], favorites: [Track], harmonic: [Track]) {
        guard isLoaded else { return ([], [], []) }
        
        // 1. Trouver le morceau correspondant dans l'index Rekordbox
        let refTrackId = resolveTrackId(for: currentTrack)
        
        var routineSuggestions: [Track] = []
        var favoriteSuggestions: [Track] = []
        var harmonicSuggestions: [Track] = []
        
        // --- 1. ROUTINES D'ENCHAÎNEMENTS (Historique Rekordbox) ---
        let cumulateVariants = UserSettings.shared.cumulateVariantSuggestions
        var cumulatedNextEntries: [String: Int] = [:]
        var variantTrackIds = Set<String>()
        if let refId = refTrackId {
            variantTrackIds.insert(refId)
        }
        
        if cumulateVariants {
            let refBase = Track.extractBaseTitle(currentTrack.displayTitle)
            let refCamelot = currentTrack.camelotKey
            let refBpm = currentTrack.bpm
            let refArtist = currentTrack.smartParsed.artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if refBase.count >= 3 {
                for candidate in tracksList {
                    let candBase = Track.extractBaseTitle(candidate.displayTitle)
                    guard candBase.lowercased() == refBase.lowercased() ||
                          candBase.localizedCaseInsensitiveContains(refBase) ||
                          refBase.localizedCaseInsensitiveContains(candBase) else { continue }
                    
                    // Même gamme harmonique
                    if let rc = refCamelot {
                        guard let cc = candidate.camelotKey, cc == rc else { continue }
                    } else if !currentTrack.rawKey.isEmpty {
                        guard candidate.rawKey.lowercased() == currentTrack.rawKey.lowercased() else { continue }
                    }
                    
                    // Sensiblement le même BPM (marge tolérée de 4% ou ±2 BPM)
                    if refBpm > 0 && candidate.bpm > 0 {
                        let diff = abs(candidate.bpm - refBpm)
                        let pct = diff / refBpm * 100.0
                        guard pct <= 4.0 || diff <= 2.0 else { continue }
                    }
                    
                    // Artiste compatible si renseigné des deux côtés
                    let candArtist = candidate.smartParsed.artist?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !refArtist.isEmpty && !candArtist.isEmpty {
                        guard candArtist.contains(refArtist) || refArtist.contains(candArtist) else { continue }
                    }
                    
                    variantTrackIds.insert(candidate.id)
                }
            }
        }
        
        for vId in variantTrackIds {
            if let entries = transitionMap[vId] {
                for (nextId, count) in entries {
                    // Ne pas suggérer une autre version du même morceau
                    guard !variantTrackIds.contains(nextId) else { continue }
                    cumulatedNextEntries[nextId, default: 0] += count
                }
            }
        }
        
        if !cumulatedNextEntries.isEmpty {
            for (nextId, count) in cumulatedNextEntries where count >= minTransitions {
                guard var targetTrack = tracksById[nextId] else { continue }
                
                // Calcul de la compatibilité harmonique et du BPM
                var rel: HarmonicRelation? = nil
                if let refCamelot = currentTrack.camelotKey, let targetCamelot = targetTrack.camelotKey {
                    rel = refCamelot.relationship(with: targetCamelot)
                }
                
                var bpmDiff: Double? = nil
                if currentTrack.bpm > 0 && targetTrack.bpm > 0 {
                    bpmDiff = targetTrack.bpm - currentTrack.bpm
                }
                
                // Filtre harmonique
                if harmonicFilter {
                    guard let r = rel, r.isCompatible else { continue }
                }
                
                // Filtre BPM
                if bpmFilter && currentTrack.bpm > 0 && targetTrack.bpm > 0 {
                    let pct = abs(targetTrack.bpm - currentTrack.bpm) / currentTrack.bpm * 100.0
                    guard pct <= tolerancePercent else { continue }
                }
                
                targetTrack.transitionCount = count
                targetTrack.matchType = MatchType.routineSequence
                targetTrack.harmonicRelation = rel
                targetTrack.bpmDiff = bpmDiff
                targetTrack.isFavorite = FavoriteCombosService.shared.isComboFavorite(track1: currentTrack, track2: targetTrack)
                targetTrack.isPlayedInSession = SessionHistoryService.shared.isPlayed(track: targetTrack)
                
                routineSuggestions.append(targetTrack)
            }
            
            // Tri par nombre d'enchaînements décroissant
            routineSuggestions.sort { a, b in
                if a.transitionCount != b.transitionCount {
                    return a.transitionCount > b.transitionCount
                }
                return (a.harmonicRelation?.isCompatible ?? false) && !(b.harmonicRelation?.isCompatible ?? false)
            }
        }
        
        // --- 2. FAVORIS MÉMORISÉS DANS RECALL ---
        let allFavorites = FavoriteCombosService.shared.getFavoriteTracks(for: currentTrack)
        for var fav in allFavorites {
            fav.isFavorite = true
            fav.matchType = MatchType.manualFavorite
            fav.isPlayedInSession = SessionHistoryService.shared.isPlayed(track: fav)
            favoriteSuggestions.append(fav)
        }
        
        // Si l'utilisateur demande exclusivement les favoris
        if favoritesOnly {
            return ([], favoriteSuggestions, [])
        }
        
        // --- 3. SUGGESTIONS HARMONIQUES GLOBALES DE LA COLLECTION ---
        // Utilisées pour compléter jusqu'au quota max de suggestions
        let neededCount = max(0, maxResults - routineSuggestions.count)
        if neededCount > 0, let refCamelot = currentTrack.camelotKey {
            let alreadyIds = Set(routineSuggestions.map { $0.id } + favoriteSuggestions.map { $0.id } + [currentTrack.id])
            
            for candidate in tracksList {
                guard !alreadyIds.contains(candidate.id) else { continue }
                guard let targetCamelot = candidate.camelotKey else { continue }
                
                let rel = refCamelot.relationship(with: targetCamelot)
                guard rel.isCompatible else { continue }
                
                var bpmDiff: Double? = nil
                if currentTrack.bpm > 0 && candidate.bpm > 0 {
                    bpmDiff = candidate.bpm - currentTrack.bpm
                    let pct = abs(candidate.bpm - currentTrack.bpm) / currentTrack.bpm * 100.0
                    if bpmFilter && pct > tolerancePercent {
                        continue
                    }
                } else if bpmFilter {
                    continue
                }
                
                var hTrack = candidate
                hTrack.transitionCount = 0
                hTrack.matchType = .sameSongVariant
                hTrack.harmonicRelation = rel
                hTrack.bpmDiff = bpmDiff
                hTrack.isFavorite = FavoriteCombosService.shared.isComboFavorite(track1: currentTrack, track2: hTrack)
                hTrack.isPlayedInSession = SessionHistoryService.shared.isPlayed(track: hTrack)
                
                harmonicSuggestions.append(hTrack)
                if harmonicSuggestions.count >= neededCount * 2 {
                    break
                }
            }
            
            // Tri harmonique : même clé > adjacent > relatif > boost
            harmonicSuggestions.sort { a, b in
                let orderA = harmonicScore(a.harmonicRelation)
                let orderB = harmonicScore(b.harmonicRelation)
                if orderA != orderB { return orderA > orderB }
                if let diffA = a.bpmDiff, let diffB = b.bpmDiff {
                    return abs(diffA) < abs(diffB)
                }
                return false
            }
        }
        
        return (routineSuggestions, favoriteSuggestions, harmonicSuggestions)
    }
    
    private func harmonicScore(_ rel: HarmonicRelation?) -> Int {
        switch rel {
        case .exact: return 4
        case .adjacent: return 3
        case .relative: return 2
        case .energyBoost: return 1
        default: return 0
        }
    }
    
    /// Recherche rapide de morceaux dans la collection Rekordbox
    public func searchTracks(query: String, limit: Int = 30) -> [Track] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        
        var results: [Track] = []
        for track in tracksList {
            if track.title.lowercased().contains(q) ||
               track.artist.lowercased().contains(q) ||
               track.fileName.lowercased().contains(q) {
                results.append(track)
                if results.count >= limit {
                    break
                }
            }
        }
        return results
    }
    
    /// Trouve un morceau de la collection Rekordbox par son chemin de fichier ou nom de fichier
    public func findTrackByFile(filePath: String, fileName: String) -> Track? {
        loadCollectionIfNeeded()
        let cleanFn = fileName.lowercased()
        let decodedFn = (fileName.removingPercentEncoding ?? fileName).lowercased()
        let cleanPath = filePath.lowercased()
        let decodedPath = (filePath.removingPercentEncoding ?? filePath).lowercased()
        
        for track in tracksList {
            if let p = track.filePath?.lowercased() {
                if p == cleanPath || p == decodedPath || (!cleanPath.isEmpty && p.hasSuffix(cleanPath)) || (!cleanFn.isEmpty && p.hasSuffix(cleanFn)) {
                    return track
                }
            }
            if !track.fileName.isEmpty {
                let tFn = track.fileName.lowercased()
                if tFn == cleanFn || tFn == decodedFn {
                    return track
                }
            }
        }
        return nil
    }
    
    /// Trouve un morceau de la collection Rekordbox par son titre et son artiste
    public func findTrack(title: String, artist: String = "") -> Track? {
        loadCollectionIfNeeded()
        let cleanTitle = FavoriteCombosService.normalize(title)
        let cleanArtist = FavoriteCombosService.normalize(artist)
        guard !cleanTitle.isEmpty else { return nil }
        
        // 1. Correspondance exacte titre + artiste
        if !cleanArtist.isEmpty {
            for track in tracksList {
                let tNorm = FavoriteCombosService.normalize(track.displayTitle)
                let aNorm = FavoriteCombosService.normalize(track.displayArtist)
                if tNorm == cleanTitle && (aNorm == cleanArtist || aNorm.contains(cleanArtist) || cleanArtist.contains(aNorm)) {
                    return track
                }
            }
        }
        
        // 2. Correspondance exacte titre
        for track in tracksList {
            let tNorm = FavoriteCombosService.normalize(track.displayTitle)
            if tNorm == cleanTitle {
                return track
            }
        }
        
        // 3. Correspondance partielle si titre assez long (ex: remix ou version radio)
        if cleanTitle.count >= 4 {
            for track in tracksList {
                let tNorm = FavoriteCombosService.normalize(track.displayTitle)
                if tNorm.contains(cleanTitle) || cleanTitle.contains(tNorm) {
                    return track
                }
            }
        }
        
        return nil
    }
    
    /// Résout l'identifiant Rekordbox correspondant à un morceau (par ID direct ou titre/artiste)
    private func resolveTrackId(for track: Track) -> String? {
        if let existing = tracksById[track.portableId] {
            return existing.portableId
        }
        let cleanTitle = FavoriteCombosService.normalize(track.displayTitle)
        let cleanArtist = FavoriteCombosService.normalize(track.displayArtist)
        
        for candidate in tracksList {
            if FavoriteCombosService.normalize(candidate.displayTitle) == cleanTitle {
                if cleanArtist.isEmpty || FavoriteCombosService.normalize(candidate.displayArtist) == cleanArtist {
                    return candidate.portableId
                }
            }
        }
        return nil
    }
    
    // MARK: - Détection en Direct des Platines Rekordbox (Accessibilité macOS)
    
    private var lastD1Elapsed: Int = -1
    private var lastD2Elapsed: Int = -1
    private var lastD1AdvancingTime: Date = .distantPast
    private var lastD2AdvancingTime: Date = .distantPast
    private var lastActiveDeck: String = "1"
    
    /// Détecte en direct et en temps réel les morceaux chargés et joués sur les platines de Rekordbox via l'API Accessibilité macOS
    public func fetchActiveDecks() -> RekordboxActiveDecksState? {
        let trusted = AXIsProcessTrusted()
        if self.isAccessibilityGranted != trusted {
            self.isAccessibilityGranted = trusted
        }
        guard trusted else {
            return nil
        }
        
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            let n = ($0.localizedName ?? "").lowercased()
            let bid = ($0.bundleIdentifier ?? "").lowercased()
            return n.contains("rekordbox") || bid.contains("com.pioneerdj.rekordbox")
        }) else {
            try? "error: rekordbox app not found\n".write(toFile: "/tmp/recall_rb_debug.log", atomically: false, encoding: .utf8)
            return nil
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsVal: CFTypeRef?
        let wRes = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsVal)
        guard wRes == .success, let windows = windowsVal as? [AXUIElement], let window = windows.first else {
            try? "error: windows copy failed: \(wRes.rawValue)\n".write(toFile: "/tmp/recall_rb_debug.log", atomically: false, encoding: .utf8)
            return nil
        }
        
        var windowSizeVal: CFTypeRef?
        var windowSize = CGSize(width: 1512, height: 982)
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &windowSizeVal) == .success, let sv = windowSizeVal {
            AXValueGetValue(sv as! AXValue, .cgSize, &windowSize)
        }
        let midX = windowSize.width / 2.0
        
        var childrenVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenVal) == .success,
              let children = childrenVal as? [AXUIElement] else { return nil }
        
        var playerGroup: AXUIElement? = nil
        for child in children {
            var roleVal: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleVal)
            guard (roleVal as? String) == "AXGroup" else { continue }
            var sizeVal: CFTypeRef?
            var sz = CGSize.zero
            if AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeVal) == .success, let sv = sizeVal {
                AXValueGetValue(sv as! AXValue, .cgSize, &sz)
            }
            var posVal: CFTypeRef?
            var pt = CGPoint.zero
            if AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &posVal) == .success, let pv = posVal {
                AXValueGetValue(pv as! AXValue, .cgPoint, &pt)
            }
            if sz.height > 250 && sz.height < 750 && pt.y < 200 {
                playerGroup = child
                break
            }
        }
        if playerGroup == nil && children.count > 1 {
            playerGroup = children[1]
        }
        guard let pGroup = playerGroup else { return nil }
        
        var gChildrenVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(pGroup, kAXChildrenAttribute as CFString, &gChildrenVal) == .success,
              let gChildren = gChildrenVal as? [AXUIElement] else { return nil }
        
        struct AxItem {
            let text: String
            let pt: CGPoint
        }
        
        var allItems: [AxItem] = []
        for el in gChildren {
            var roleVal: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleVal)
            guard (roleVal as? String) == "AXStaticText" else { continue }
            var valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &valRef)
            let text = (valRef as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            var posVal: CFTypeRef?
            var pt = CGPoint.zero
            if AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posVal) == .success, let pv = posVal {
                AXValueGetValue(pv as! AXValue, .cgPoint, &pt)
            }
            allItems.append(AxItem(text: text, pt: pt))
        }
        
        func parseDeck(isDeck1: Bool) -> (track: Track, elapsedSec: Int)? {
            let deckItems = allItems.filter { isDeck1 ? $0.pt.x < midX : $0.pt.x >= midX }
            
            var bpmVal = 0.0
            var bpmItem: AxItem? = nil
            for it in deckItems {
                if let b = Double(it.text), b >= 45.0 && b <= 240.0 && !it.text.contains(":") && !it.text.contains("%") {
                    bpmVal = b
                    bpmItem = it
                    break
                }
            }
            
            var keyStr = ""
            if let bp = bpmItem {
                let keyCandidates = deckItems.filter {
                    $0.pt.x > bp.pt.x && $0.pt.x <= bp.pt.x + 120 &&
                    abs($0.pt.y - bp.pt.y) <= 12 &&
                    Double($0.text) == nil && !$0.text.contains(":") && !$0.text.contains("%")
                }
                if let best = keyCandidates.min(by: { abs($0.pt.x - bp.pt.x) < abs($1.pt.x - bp.pt.x) }) {
                    keyStr = best.text
                }
            }
            
            var rawTitle = ""
            if let bp = bpmItem {
                let titleCandidates = deckItems.filter {
                    $0.pt.y < bp.pt.y && $0.pt.y >= bp.pt.y - 60 &&
                    $0.text.count >= 2 && Double($0.text) == nil && !$0.text.contains(":") &&
                    $0.text != "MIX" && $0.text != "LEVEL" && $0.text != "MUTE"
                }
                if let best = titleCandidates.min(by: { abs($0.pt.y - bp.pt.y) < abs($1.pt.y - bp.pt.y) }) {
                    rawTitle = best.text
                }
            }
            
            guard !rawTitle.isEmpty || bpmVal > 0 else { return nil }
            
            var elapsedSec = 0
            if let bp = bpmItem {
                let timeCandidates = deckItems.filter {
                    abs($0.pt.y - bp.pt.y) <= 15 &&
                    $0.text.contains(":") && !$0.text.hasPrefix("-") && $0.text.count >= 4 && $0.text.count <= 5
                }
                if let t = timeCandidates.first {
                    let parts = t.text.split(separator: ":")
                    if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
                        elapsedSec = m * 60 + s
                    }
                }
            }
            
            let deckNum = isDeck1 ? "1" : "2"
            let parsed = Track.parseSmartArtistAndTitle(rawString: rawTitle)
            
            // Enrichissement via la collection Rekordbox XML si disponible
            if let rbFound = findTrack(title: parsed.title, artist: parsed.artist ?? "") {
                let tr = Track(
                    id: "rb-deck-\(deckNum)-\(rbFound.id)",
                    title: rbFound.title,
                    artist: rbFound.artist,
                    bpm: bpmVal > 0 ? bpmVal : rbFound.bpm,
                    rawKey: !keyStr.isEmpty ? keyStr : rbFound.rawKey,
                    filePath: rbFound.filePath,
                    fileName: rbFound.fileName,
                    portableId: rbFound.portableId,
                    deck: deckNum
                )
                return (tr, elapsedSec)
            }
            
            let tr = Track(
                id: "rb-deck-\(deckNum)-\(abs(rawTitle.hashValue))",
                title: parsed.title,
                artist: parsed.artist ?? "",
                bpm: bpmVal,
                rawKey: keyStr,
                filePath: nil,
                fileName: rawTitle,
                portableId: rawTitle,
                deck: deckNum
            )
            return (tr, elapsedSec)
        }
        
        let d1Info = parseDeck(isDeck1: true)
        let d2Info = parseDeck(isDeck1: false)
        
        let now = Date()
        var isD1Playing = false
        var isD2Playing = false
        
        if let d1 = d1Info {
            if d1.elapsedSec != lastD1Elapsed && d1.elapsedSec > 0 {
                isD1Playing = true
                lastD1AdvancingTime = now
                lastActiveDeck = "1"
            } else if now.timeIntervalSince(lastD1AdvancingTime) < 2.5 {
                isD1Playing = true
                lastActiveDeck = "1"
            }
            lastD1Elapsed = d1.elapsedSec
        }
        
        if let d2 = d2Info {
            if d2.elapsedSec != lastD2Elapsed && d2.elapsedSec > 0 {
                isD2Playing = true
                lastD2AdvancingTime = now
                lastActiveDeck = "2"
            } else if now.timeIntervalSince(lastD2AdvancingTime) < 2.5 {
                isD2Playing = true
                lastActiveDeck = "2"
            }
            lastD2Elapsed = d2.elapsedSec
        }
        
        // Si aucun des deux n'avance (pause), orienter selon le temps écoulé
        if !isD1Playing && !isD2Playing {
            if let d1 = d1Info, let d2 = d2Info {
                if d1.elapsedSec > 0 && d2.elapsedSec == 0 {
                    lastActiveDeck = "1"
                } else if d2.elapsedSec > 0 && d1.elapsedSec == 0 {
                    lastActiveDeck = "2"
                }
            } else if d1Info != nil && d2Info == nil {
                lastActiveDeck = "1"
            } else if d2Info != nil && d1Info == nil {
                lastActiveDeck = "2"
            }
        }
        
        // Enregistrement automatique dans l'historique de session quand la durée dépasse le seuil
        let threshold = UserSettings.shared.playedMinDurationSeconds
        if let d1 = d1Info, d1.elapsedSec >= threshold {
            SessionHistoryService.shared.recordPlayedTrack(
                title: d1.track.displayTitle,
                artist: d1.track.artist,
                fileName: d1.track.fileName,
                durationSeconds: Double(d1.elapsedSec)
            )
        }
        if let d2 = d2Info, d2.elapsedSec >= threshold {
            SessionHistoryService.shared.recordPlayedTrack(
                title: d2.track.displayTitle,
                artist: d2.track.artist,
                fileName: d2.track.fileName,
                durationSeconds: Double(d2.elapsedSec)
            )
        }
        
        return RekordboxActiveDecksState(
            deck1: d1Info?.track,
            deck2: d2Info?.track,
            deck1ElapsedSeconds: d1Info?.elapsedSec ?? 0,
            deck2ElapsedSeconds: d2Info?.elapsedSec ?? 0,
            isDeck1Playing: isD1Playing,
            isDeck2Playing: isD2Playing,
            activeDeckNumber: lastActiveDeck
        )
    }
}

// MARK: - Parser SAX Rekordbox XML ultra optimisé

private final class RekordboxXmlParserDelegate: NSObject, XMLParserDelegate {
    var tracksById: [String: Track] = [:]
    var tracksList: [Track] = []
    // transitionMap[fromTrackId][toTrackId] = count
    var transitionMap: [String: [String: Int]] = [:]
    
    var playlistCount: Int = 0
    var totalTransitionsCount: Int = 0
    
    private var isInsidePlaylists: Bool = false
    private var currentPlaylistTracks: [String] = []
    
    private func sanitizeEncoding(_ str: String) -> String {
        guard str.contains("Ã") || str.contains("Â") else { return str }
        if let data = str.data(using: .isoLatin1), let fixed = String(data: data, encoding: .utf8) {
            return fixed
        }
        return str
    }
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        if elementName == "TRACK" {
            if isInsidePlaylists {
                // Élément de playlist
                if let key = attributeDict["Key"] {
                    currentPlaylistTracks.append(key)
                }
            } else {
                // Morceau de collection
                guard let trackId = attributeDict["TrackID"], !trackId.isEmpty else { return }
                let name = sanitizeEncoding(attributeDict["Name"] ?? "")
                let artist = sanitizeEncoding(attributeDict["Artist"] ?? "")
                let bpm = Double(attributeDict["AverageBpm"] ?? "") ?? 0.0
                let tonality = attributeDict["Tonality"] ?? ""
                let location = attributeDict["Location"] ?? ""
                
                let resolvedPath = decodeLocationUrl(location)
                let fileName = (resolvedPath as NSString).lastPathComponent
                
                let track = Track(
                    id: "rb-\(trackId)",
                    title: name,
                    artist: artist,
                    bpm: bpm,
                    rawKey: tonality,
                    filePath: resolvedPath.isEmpty ? nil : resolvedPath,
                    fileName: fileName,
                    portableId: trackId
                )
                
                tracksById[trackId] = track
                tracksList.append(track)
            }
        } else if elementName == "NODE" {
            if attributeDict["Type"] == "1" {
                currentPlaylistTracks.removeAll(keepingCapacity: true)
            }
        } else if elementName == "PLAYLISTS" {
            isInsidePlaylists = true
        }
    }
    
    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "NODE" && !currentPlaylistTracks.isEmpty {
            playlistCount += 1
            let count = currentPlaylistTracks.count
            if count >= 2 {
                for i in 0..<(count - 1) {
                    let fromKey = currentPlaylistTracks[i]
                    let toKey = currentPlaylistTracks[i + 1]
                    guard fromKey != toKey else { continue }
                    
                    var destMap = transitionMap[fromKey] ?? [:]
                    destMap[toKey, default: 0] += 1
                    transitionMap[fromKey] = destMap
                    totalTransitionsCount += 1
                }
            }
            currentPlaylistTracks.removeAll(keepingCapacity: true)
        }
    }
    
    private func decodeLocationUrl(_ location: String) -> String {
        guard !location.isEmpty else { return "" }
        var cleaned = location
        if cleaned.hasPrefix("file://localhost/") {
            cleaned = String(cleaned.dropFirst("file://localhost/".count))
        } else if cleaned.hasPrefix("file://localhost") {
            cleaned = String(cleaned.dropFirst("file://localhost".count))
        } else if cleaned.hasPrefix("file:///") {
            cleaned = String(cleaned.dropFirst("file://".count))
        }
        
        let decoded = cleaned.removingPercentEncoding ?? cleaned
        
        // Sur macOS, si le chemin commence par un lecteur Windows (ex: C:/), tenter de le nettoyer
        if !decoded.hasPrefix("/") && !decoded.contains(":") {
            return "/" + decoded
        }
        return decoded
    }
}
