import Foundation
import Combine
import SwiftUI
import AppKit
import ApplicationServices
import CoreServices

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
    // reverseTransitionMap[toTrackId][fromTrackId] = count
    private var reverseTransitionMap: [String: [String: Int]] = [:]
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
                        self.reverseTransitionMap = parserDelegate.reverseTransitionMap
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
        direction: TransitionDirection = UserSettings.shared.transitionDirection,
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
        
        var nextEntries: [String: Int] = [:]
        var prevEntries: [String: Int] = [:]
        
        if direction == .next || direction == .all {
            for vId in variantTrackIds {
                if let entries = transitionMap[vId] {
                    for (nextId, count) in entries {
                        guard !variantTrackIds.contains(nextId) else { continue }
                        nextEntries[nextId, default: 0] += count
                    }
                }
            }
        }
        
        if direction == .previous || direction == .all {
            for vId in variantTrackIds {
                if let entries = reverseTransitionMap[vId] {
                    for (prevId, count) in entries {
                        guard !variantTrackIds.contains(prevId) else { continue }
                        prevEntries[prevId, default: 0] += count
                    }
                }
            }
        }
        
        let allCandidateIds = Set(nextEntries.keys).union(prevEntries.keys)
        if !allCandidateIds.isEmpty {
            for candId in allCandidateIds {
                let nextCount = nextEntries[candId] ?? 0
                let prevCount = prevEntries[candId] ?? 0
                let totalCount = nextCount + prevCount
                guard totalCount >= minTransitions else { continue }
                guard var targetTrack = tracksById[candId] else { continue }
                
                let trackDir: TransitionDirection
                if nextCount > 0 && prevCount > 0 {
                    trackDir = .all
                } else if prevCount > 0 {
                    trackDir = .previous
                } else {
                    trackDir = .next
                }
                
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
                
                targetTrack.transitionCount = totalCount
                targetTrack.direction = trackDir
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
        case .exact: return 6
        case .adjacent: return 5
        case .relative: return 4
        case .semitoneBoost: return 4
        case .wholeToneBoost: return 3
        case .diagonal: return 3
        case .semitoneDrop: return 2
        default: return 0
        }
    }
    
    // MARK: - Chemins Musicaux Standards & Métadonnées
    
    public static let knownMusicDirs: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Music/REVR BIBLIOTHEQUE",
            "\(home)/Music/REVR Morceaux",
            "\(home)/Music/LAUNCHMACHINE BIBLIOTHEQUE",
            "\(home)/Music"
        ]
    }()
    
    public static let commonAudioExts = ["mp3", "wav", "aiff", "flac", "m4a", "aac", "alac", "ogg"]
    
    /// Recherche rapide et tolérante de morceaux dans la collection Rekordbox et les dossiers musicaux locaux
    public func searchTracks(query: String, limit: Int = 30) -> [Track] {
        loadCollectionIfNeeded()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        
        let tokens = q
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .split(separator: " ")
            .map { String($0) }
            .filter { !$0.isEmpty }
        
        guard !tokens.isEmpty else { return [] }
        
        var results: [Track] = []
        var seenNames = Set<String>()
        
        // 1. Recherche dans la collection XML Rekordbox (si disponible)
        for track in tracksList {
            let searchable = "\(track.title) \(track.artist) \(track.fileName) \(track.displayTitle) \(track.displayArtist)"
                .folding(options: .diacriticInsensitive, locale: .current)
                .lowercased()
            
            if tokens.allSatisfy({ searchable.contains($0) }) {
                results.append(track)
                seenNames.insert(track.fileName.lowercased())
                if results.count >= limit {
                    return results
                }
            }
        }
        
        // 2. Recherche complémentaire dans les répertoires musicaux locaux
        // (permet de trouver instantanément les morceaux récents même si le XML n'a pas encore été ré-exporté)
        if results.count < limit {
            let localResults = searchLocalMusicFiles(tokens: tokens, limit: limit - results.count, excluding: seenNames)
            results.append(contentsOf: localResults)
        }
        
        return results
    }
    
    private var localFilesCache: [(dir: String, fileName: String)]? = nil
    private var localFilesCacheDate: Date? = nil
    
    private func getCachedLocalFiles() -> [(dir: String, fileName: String)] {
        if let cache = localFilesCache, let date = localFilesCacheDate, Date().timeIntervalSince(date) < 60 {
            return cache
        }
        let fm = FileManager.default
        var files: [(dir: String, fileName: String)] = []
        for dir in Self.knownMusicDirs {
            guard fm.fileExists(atPath: dir) else { continue }
            guard let fileNames = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for fileName in fileNames {
                let ext = (fileName as NSString).pathExtension.lowercased()
                if Self.commonAudioExts.contains(ext) {
                    files.append((dir, fileName))
                }
            }
        }
        localFilesCache = files
        localFilesCacheDate = Date()
        return files
    }
    
    private func searchLocalMusicFiles(tokens: [String], limit: Int, excluding: Set<String>) -> [Track] {
        guard !tokens.isEmpty && limit > 0 else { return [] }
        var localTracks: [Track] = []
        var seen = excluding
        
        let allLocal = getCachedLocalFiles()
        for item in allLocal {
            let lowerName = item.fileName.lowercased()
            guard !seen.contains(lowerName) else { continue }
            let norm = item.fileName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            if tokens.allSatisfy({ norm.contains($0) }) {
                let fullPath = "\(item.dir)/\(item.fileName)"
                let parsed = Track.parseSmartArtistAndTitle(rawString: item.fileName)
                let (mdBpm, mdKey) = readSpotlightAudioMetadata(filePath: fullPath)
                
                let track = Track(
                    id: "local-\(abs(item.fileName.hashValue))",
                    title: parsed.title,
                    artist: parsed.artist ?? "",
                    bpm: mdBpm ?? 0.0,
                    rawKey: mdKey ?? "",
                    filePath: fullPath,
                    fileName: item.fileName,
                    portableId: fullPath
                )
                localTracks.append(track)
                seen.insert(lowerName)
                if localTracks.count >= limit {
                    return localTracks
                }
            }
        }
        return localTracks
    }
    
    public func resolveLocalAudioFilePath(rawTitle: String, title: String) -> String? {
        let fm = FileManager.default
        let candidatesToTry = [rawTitle, title].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for dir in Self.knownMusicDirs {
            guard fm.fileExists(atPath: dir) else { continue }
            for base in candidatesToTry {
                for ext in Self.commonAudioExts {
                    let path = "\(dir)/\(base).\(ext)"
                    if fm.fileExists(atPath: path) {
                        return path
                    }
                }
            }
        }
        return nil
    }
    
    public func readSpotlightAudioMetadata(filePath: String) -> (bpm: Double?, key: String?) {
        let url = URL(fileURLWithPath: filePath)
        guard let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else {
            return (nil, nil)
        }
        var bpmResult: Double? = nil
        if let tempoNum = MDItemCopyAttribute(mdItem, kMDItemTempo) as? Double {
            bpmResult = tempoNum
        } else if let tempoInt = MDItemCopyAttribute(mdItem, kMDItemTempo) as? Int {
            bpmResult = Double(tempoInt)
        }
        let keyResult = MDItemCopyAttribute(mdItem, kMDItemKeySignature) as? String
        return (bpmResult, keyResult)
    }
    
    /// Trouve un morceau de la collection Rekordbox par son chemin de fichier ou nom de fichier
    public func findTrackByFile(filePath: String, fileName: String) -> Track? {
        loadCollectionIfNeeded()
        let cleanFn = fileName.lowercased()
        let decodedFn = (fileName.removingPercentEncoding ?? fileName).lowercased()
        let cleanPath = filePath.lowercased()
        let decodedPath = (filePath.removingPercentEncoding ?? filePath).lowercased()
        
        // 1. Recherche dans l'index XML en mémoire
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
        
        // 2. Recherche dans les dossiers musicaux locaux (REVR BIBLIOTHEQUE, etc.)
        let allLocal = getCachedLocalFiles()
        for item in allLocal {
            let lower = item.fileName.lowercased()
            if (!cleanFn.isEmpty && (lower == cleanFn || lower == decodedFn)) ||
               (!cleanPath.isEmpty && (item.dir.lowercased() + "/" + lower == cleanPath || item.dir.lowercased() + "/" + lower == decodedPath)) {
                let fullPath = "\(item.dir)/\(item.fileName)"
                let parsed = Track.parseSmartArtistAndTitle(rawString: item.fileName)
                let (mdBpm, mdKey) = readSpotlightAudioMetadata(filePath: fullPath)
                return Track(
                    id: "local-\(abs(item.fileName.hashValue))",
                    title: parsed.title,
                    artist: parsed.artist ?? "",
                    bpm: mdBpm ?? 0.0,
                    rawKey: mdKey ?? "",
                    filePath: fullPath,
                    fileName: item.fileName,
                    portableId: fullPath
                )
            }
        }
        
        // 3. Si le chemin physique existe directement sur le disque
        if !filePath.isEmpty && FileManager.default.fileExists(atPath: filePath) {
            let fName = (filePath as NSString).lastPathComponent
            let parsed = Track.parseSmartArtistAndTitle(rawString: fName)
            let (mdBpm, mdKey) = readSpotlightAudioMetadata(filePath: filePath)
            return Track(
                id: "local-\(abs(filePath.hashValue))",
                title: parsed.title,
                artist: parsed.artist ?? "",
                bpm: mdBpm ?? 0.0,
                rawKey: mdKey ?? "",
                filePath: filePath,
                fileName: fName,
                portableId: filePath
            )
        }
        
        return nil
    }
    
    /// Trouve un morceau de la collection Rekordbox par son titre et son artiste
    public func findTrack(title: String, artist: String = "") -> Track? {
        loadCollectionIfNeeded()
        let cleanTitle = FavoriteCombosService.normalize(title)
        let cleanArtist = FavoriteCombosService.normalize(artist)
        guard !cleanTitle.isEmpty else { return nil }
        
        let cleanBaseTitle = FavoriteCombosService.normalize(Track.extractBaseTitle(title))
        
        // SCÉNARIO A : L'artiste est renseigné (ex: "doechii")
        // Règle d'or : On n'accepte QUE les morceaux dont l'artiste concorde !
        // Interdiction absolue de faire correspondre Doechii avec Soft Cell ou tout autre artiste différent.
        if !cleanArtist.isEmpty {
            // 1. Correspondance exacte Titre + Artiste
            for track in tracksList {
                let aNorm = FavoriteCombosService.normalize(track.displayArtist)
                guard !aNorm.isEmpty && (aNorm == cleanArtist || aNorm.contains(cleanArtist) || cleanArtist.contains(aNorm)) else {
                    continue
                }
                let tNorm = FavoriteCombosService.normalize(track.displayTitle)
                if tNorm == cleanTitle {
                    return track
                }
            }
            
            // 2. Correspondance Base Titre + Artiste (ex: version remix/edit vs version originale)
            if cleanBaseTitle.count >= 3 {
                for track in tracksList {
                    let aNorm = FavoriteCombosService.normalize(track.displayArtist)
                    guard !aNorm.isEmpty && (aNorm == cleanArtist || aNorm.contains(cleanArtist) || cleanArtist.contains(aNorm)) else {
                        continue
                    }
                    let candBaseTitle = FavoriteCombosService.normalize(Track.extractBaseTitle(track.displayTitle))
                    if candBaseTitle == cleanBaseTitle {
                        return track
                    }
                }
            }
            
            // 3. Correspondance Préfixe de Titre + Artiste (ex: "What It Is" avec "What It Is (Soulely Edit)")
            if cleanBaseTitle.count >= 4 {
                for track in tracksList {
                    let aNorm = FavoriteCombosService.normalize(track.displayArtist)
                    guard !aNorm.isEmpty && (aNorm == cleanArtist || aNorm.contains(cleanArtist) || cleanArtist.contains(aNorm)) else {
                        continue
                    }
                    let tNorm = FavoriteCombosService.normalize(track.displayTitle)
                    let candBaseTitle = FavoriteCombosService.normalize(Track.extractBaseTitle(track.displayTitle))
                    if tNorm.hasPrefix(cleanBaseTitle) || cleanTitle.hasPrefix(candBaseTitle) {
                        return track
                    }
                }
            }
            
            // Artiste spécifié mais aucune concordance fiable trouvée dans le XML
            return nil
        }
        
        // SCÉNARIO B : Aucun artiste n'a été fourni ou détecté
        // 1. Correspondance exacte du titre complet
        if cleanTitle.count >= 3 {
            for track in tracksList {
                let tNorm = FavoriteCombosService.normalize(track.displayTitle)
                if tNorm == cleanTitle {
                    return track
                }
            }
        }
        
        // 2. Correspondance stricte de la base du titre (au moins 5 caractères)
        if cleanBaseTitle.count >= 5 {
            for track in tracksList {
                let candBaseTitle = FavoriteCombosService.normalize(Track.extractBaseTitle(track.displayTitle))
                if candBaseTitle == cleanBaseTitle {
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
        let cleanBase = FavoriteCombosService.normalize(Track.extractBaseTitle(track.displayTitle))
        
        // 1. Si artiste présent : recherche avec correspondance d'artiste impérative
        if !cleanArtist.isEmpty {
            for candidate in tracksList {
                let aNorm = FavoriteCombosService.normalize(candidate.displayArtist)
                guard !aNorm.isEmpty && (aNorm == cleanArtist || aNorm.contains(cleanArtist) || cleanArtist.contains(aNorm)) else {
                    continue
                }
                let tNorm = FavoriteCombosService.normalize(candidate.displayTitle)
                let candBase = FavoriteCombosService.normalize(Track.extractBaseTitle(candidate.displayTitle))
                if tNorm == cleanTitle || (cleanBase.count >= 3 && cleanBase == candBase) {
                    return candidate.portableId
                }
            }
            return nil
        }
        
        // 2. Si pas d'artiste
        for candidate in tracksList {
            let tNorm = FavoriteCombosService.normalize(candidate.displayTitle)
            if tNorm == cleanTitle {
                return candidate.portableId
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
                let resolvedTitle = !parsed.title.isEmpty ? parsed.title : rbFound.title
                let resolvedArtist = (parsed.artist != nil && !parsed.artist!.isEmpty) ? parsed.artist! : rbFound.artist
                let tr = Track(
                    id: "rb-deck-\(deckNum)-\(rbFound.id)",
                    title: resolvedTitle,
                    artist: resolvedArtist,
                    bpm: bpmVal > 0 ? bpmVal : rbFound.bpm,
                    rawKey: !keyStr.isEmpty ? keyStr : rbFound.rawKey,
                    filePath: rbFound.filePath,
                    fileName: rbFound.fileName,
                    portableId: rbFound.portableId,
                    deck: deckNum
                )
                return (tr, elapsedSec)
            }
            
            // Si non trouvé dans le XML, tentative de localiser le fichier audio sur le disque
            let localPath = resolveLocalAudioFilePath(rawTitle: rawTitle, title: parsed.title)
            let resolvedFileName = localPath != nil ? (localPath! as NSString).lastPathComponent : rawTitle
            
            var finalBpm = bpmVal
            var finalKey = keyStr
            if (finalBpm <= 0 || finalKey.isEmpty), let lp = localPath {
                let (mdBpm, mdKey) = readSpotlightAudioMetadata(filePath: lp)
                if finalBpm <= 0, let b = mdBpm { finalBpm = b }
                if finalKey.isEmpty, let k = mdKey { finalKey = k }
            }
            
            let tr = Track(
                id: "rb-deck-\(deckNum)-\(abs(rawTitle.hashValue))",
                title: parsed.title,
                artist: parsed.artist ?? "",
                bpm: finalBpm,
                rawKey: finalKey,
                filePath: localPath,
                fileName: resolvedFileName,
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
                durationSeconds: Double(d1.elapsedSec),
                bpm: d1.track.bpm,
                rawKey: d1.track.rawKey,
                isCurrentlyPlaying: d1.elapsedSec > 0
            )
        }
        if let d2 = d2Info, d2.elapsedSec >= threshold {
            SessionHistoryService.shared.recordPlayedTrack(
                title: d2.track.displayTitle,
                artist: d2.track.artist,
                fileName: d2.track.fileName,
                durationSeconds: Double(d2.elapsedSec),
                bpm: d2.track.bpm,
                rawKey: d2.track.rawKey,
                isCurrentlyPlaying: d2.elapsedSec > 0
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
    // reverseTransitionMap[toTrackId][fromTrackId] = count
    var reverseTransitionMap: [String: [String: Int]] = [:]
    
    var playlistCount: Int = 0
    var totalTransitionsCount: Int = 0
    
    private var isInsidePlaylists: Bool = false
    private var currentPlaylistTracks: [String] = []
    // Le XML Rekordbox ne contient pas l'heure de lecture : la durée d'une session
    // est estimée par la somme des durées (TotalTime) de ses morceaux.
    private var trackDurationsById: [String: Int] = [:]
    
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
                let genre = sanitizeEncoding(attributeDict["Genre"] ?? "")
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
                    portableId: trackId,
                    genre: genre
                )
                
                tracksById[trackId] = track
                tracksList.append(track)
                if let totalTime = Int(attributeDict["TotalTime"] ?? ""), totalTime > 0 {
                    trackDurationsById[trackId] = totalTime
                }
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
            let estimatedDuration = currentPlaylistTracks.reduce(0) { $0 + (trackDurationsById[$1] ?? 180) }
            if count >= UserSettings.minimumSessionTracksCount && estimatedDuration >= UserSettings.minimumSessionDurationSeconds {
                for i in 0..<(count - 1) {
                    let fromKey = currentPlaylistTracks[i]
                    let toKey = currentPlaylistTracks[i + 1]
                    guard fromKey != toKey else { continue }
                    
                    var destMap = transitionMap[fromKey] ?? [:]
                    destMap[toKey, default: 0] += 1
                    transitionMap[fromKey] = destMap
                    
                    var revMap = reverseTransitionMap[toKey] ?? [:]
                    revMap[fromKey, default: 0] += 1
                    reverseTransitionMap[toKey] = revMap
                    
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
