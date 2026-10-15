import Foundation
import Combine
import SwiftUI

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
    
    // Index en mémoire pour recherche instantanée (sub-milliseconde)
    private var tracksById: [String: Track] = [:]
    private var tracksList: [Track] = []
    // transitionMap[fromTrackId][toTrackId] = count
    private var transitionMap: [String: [String: Int]] = [:]
    private var lastXmlModificationDate: Date? = nil
    
    public init() {
        loadCollectionIfNeeded()
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
        if let refId = refTrackId, let nextEntries = transitionMap[refId] {
            for (nextId, count) in nextEntries where count >= minTransitions {
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
                let name = attributeDict["Name"] ?? ""
                let artist = attributeDict["Artist"] ?? ""
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
