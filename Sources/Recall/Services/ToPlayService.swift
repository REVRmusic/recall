import Foundation
import Combine
import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

/// Modèle représentant un morceau mis de côté dans le répertoire des morceaux à jouer prochainement
public struct ToPlayTrack: Codable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var artist: String
    public var bpm: Double
    public var rawKey: String
    public var filePath: String?
    public var fileName: String
    public var portableId: String
    public var addedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "",
        bpm: Double = 0.0,
        rawKey: String = "",
        filePath: String? = nil,
        fileName: String = "",
        portableId: String = "",
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.bpm = bpm
        self.rawKey = rawKey
        self.filePath = filePath
        self.fileName = fileName
        self.portableId = portableId
        self.addedAt = addedAt
    }
    
    public init(from track: Track) {
        self.id = UUID().uuidString
        self.title = track.title
        self.artist = track.artist
        self.bpm = track.bpm
        self.rawKey = track.rawKey
        self.filePath = track.filePath
        self.fileName = track.fileName
        self.portableId = track.portableId
        self.addedAt = Date()
    }
    
    public var camelotKey: CamelotKey? {
        return CamelotKey.parse(rawKey)
    }
    
    public var smartParsed: (artist: String?, title: String) {
        return TrackMetadataCleaner.resolve(artist: artist, title: title, fileName: fileName)
    }
    
    public var displayTitle: String {
        let parsed = smartParsed
        if !parsed.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return parsed.title
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !fileName.isEmpty {
            return (fileName as NSString).deletingPathExtension
        }
        return "Morceau inconnu"
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
        guard bpm > 0 else { return "--" }
        if abs(bpm.rounded() - bpm) < 0.05 {
            return "\(Int(bpm.rounded()))"
        }
        return String(format: "%.1f", bpm)
    }
    
    public var displayKey: String {
        if let camelot = camelotKey {
            return camelot.displayText(mode: UserSettings.shared.keyDisplayMode)
        }
        return rawKey.isEmpty ? "--" : rawKey
    }
    
    /// Convertit le morceau en objet Track pour réutiliser les composants d'affichage et de glisser-déposer
    @MainActor
    public func toTrack(referenceTrack: Track? = nil) -> Track {
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
        
        let playedInSession = SessionHistoryService.shared.playedNormalizedTitles.contains(
            FavoriteCombosService.normalize(displayTitle)
        ) || (!fileName.isEmpty && SessionHistoryService.shared.playedNormalizedTitles.contains(
            FavoriteCombosService.normalize(fileName)
        ))
        
        var isFav = false
        if let ref = referenceTrack {
            let candidateTrack = Track(
                id: id,
                assetId: nil,
                historyEntryId: nil,
                title: title,
                artist: artist,
                bpm: bpm,
                rawKey: rawKey,
                filePath: filePath,
                fileName: fileName,
                portableId: portableId
            )
            isFav = FavoriteCombosService.shared.isComboFavorite(track1: ref, track2: candidateTrack)
        }
        
        return Track(
            id: id,
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
            transitionCount: 0,
            matchType: .directTransition,
            harmonicRelation: harmonicRel,
            bpmDiff: bpmDifference,
            isFavorite: isFav,
            isPlayedInSession: playedInSession
        )
    }
}

/// Service de gestion et de persistance des morceaux à jouer prochainement
/// Permet l'ajout direct par glisser-déposer depuis Serato DJ Pro, Rekordbox ou le Finder
@MainActor
public class ToPlayService: ObservableObject {
    public static let shared = ToPlayService()
    
    @Published public private(set) var tracks: [ToPlayTrack] = []
    @Published public var isDraggingFileOver: Bool = false
    @Published public var toastMessage: String? = nil
    
    private let storageURL: URL
    private var toastTimer: Timer?
    
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let recallDir = appSupport.appendingPathComponent("Recall", isDirectory: true)
        try? FileManager.default.createDirectory(at: recallDir, withIntermediateDirectories: true)
        self.storageURL = recallDir.appendingPathComponent("to_play_tracks.json")
        loadTracks()
    }
    
    // MARK: - Persistance
    
    private func loadTracks() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            self.tracks = []
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode([ToPlayTrack].self, from: data)
            self.tracks = decoded
        } catch {
            AppLogger.error("Erreur chargement des morceaux à jouer", category: .session, error: error)
            self.tracks = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            AppLogger.error("Erreur sauvegarde des morceaux à jouer", category: .session, error: error)
        }
    }
    
    // MARK: - Gestion des Morceaux
    
    /// Ajoute un morceau directement depuis un objet Track
    @discardableResult
    public func addTrack(_ track: Track, isSilentIfAlreadyPresent: Bool = false) -> Bool {
        let normTitle = FavoriteCombosService.normalize(track.displayTitle)
        
        // Si le morceau est déjà présent, on le déplace en tête de liste
        if let existingIndex = tracks.firstIndex(where: {
            FavoriteCombosService.normalize($0.displayTitle) == normTitle ||
            (!track.fileName.isEmpty && !$0.fileName.isEmpty && FavoriteCombosService.normalize($0.fileName) == FavoriteCombosService.normalize(track.fileName))
        }) {
            if isSilentIfAlreadyPresent {
                if tracks[existingIndex].filePath == nil, let p = track.filePath {
                    tracks[existingIndex].filePath = p
                    saveToDisk()
                }
                return true
            }
            let existing = tracks.remove(at: existingIndex)
            tracks.insert(existing, at: 0)
            saveToDisk()
            showToast("« \(track.displayTitle) » déjà dans votre Sélec")
            UserSettings.shared.isToPlayFilterActive = true
            return true
        }
        
        let toPlay = ToPlayTrack(from: track)
        tracks.insert(toPlay, at: 0)
        saveToDisk()
        showToast("« \(track.displayTitle) » ajouté à votre Sélec")
        UserSettings.shared.isToPlayFilterActive = true
        NSSound(named: "Pop")?.play()
        return true
    }
    
    /// Ajoute un morceau depuis un chemin de fichier local
    @discardableResult
    public func addTrack(fromPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return addTrack(fromURL: url)
    }
    
    /// Ajoute un morceau depuis une URL de fichier local (glisser depuis Serato, Rekordbox ou Finder)
    @discardableResult
    public func addTrack(fromURL url: URL, isSilentIfAlreadyPresent: Bool = false) -> Bool {
        guard url.isFileURL else { return false }
        let filePath = url.path
        let fileName = url.lastPathComponent
        
        // 1. Recherche prioritaire selon le mode logiciel actif
        if UserSettings.shared.djSoftwareMode == .rekordbox {
            // Priorité Rekordbox XML
            if let rekordboxTrack = RekordboxService.shared.findTrackByFile(filePath: filePath, fileName: fileName) {
                return addTrack(rekordboxTrack, isSilentIfAlreadyPresent: isSilentIfAlreadyPresent)
            }
            // Secours Serato SQLite
            let seratoService = SeratoDatabaseService(databasePath: UserSettings.shared.effectiveDatabasePath)
            if let seratoTrack = seratoService.findTrackByFile(filePath: filePath, fileName: fileName) {
                return addTrack(seratoTrack, isSilentIfAlreadyPresent: isSilentIfAlreadyPresent)
            }
        } else {
            // Priorité Serato SQLite (par défaut ou mode Serato)
            let seratoService = SeratoDatabaseService(databasePath: UserSettings.shared.effectiveDatabasePath)
            if let seratoTrack = seratoService.findTrackByFile(filePath: filePath, fileName: fileName) {
                return addTrack(seratoTrack, isSilentIfAlreadyPresent: isSilentIfAlreadyPresent)
            }
            // Secours Rekordbox XML
            if let rekordboxTrack = RekordboxService.shared.findTrackByFile(filePath: filePath, fileName: fileName) {
                return addTrack(rekordboxTrack, isSilentIfAlreadyPresent: isSilentIfAlreadyPresent)
            }
        }
        
        // 2. Ajout immédiat avec analyse intelligente du nom de fichier
        let parsed = Track.parseSmartArtistAndTitle(rawString: (fileName as NSString).deletingPathExtension)
        let initialTrack = Track(
            title: parsed.title,
            artist: parsed.artist ?? "",
            bpm: 0.0,
            rawKey: "",
            filePath: filePath,
            fileName: fileName,
            portableId: filePath
        )
        
        addTrack(initialTrack, isSilentIfAlreadyPresent: isSilentIfAlreadyPresent)
        
        // 4. Enrichissement asynchrone moderne des métadonnées ID3 via AVURLAsset
        Task {
            let asset = AVURLAsset(url: url)
            var titleCandidate: String? = nil
            var artistCandidate: String? = nil
            var bpmCandidate: Double = 0.0
            var keyCandidate: String = ""
            
            if let common = try? await asset.load(.commonMetadata) {
                for item in common {
                    if item.commonKey == .commonKeyTitle, let s = try? await item.load(.stringValue), !s.isEmpty {
                        titleCandidate = s
                    } else if item.commonKey == .commonKeyArtist, let s = try? await item.load(.stringValue), !s.isEmpty {
                        artistCandidate = s
                    }
                }
            }
            
            if let formats = try? await asset.load(.availableMetadataFormats) {
                for format in formats {
                    if let meta = try? await asset.loadMetadata(for: format) {
                        for item in meta {
                            let keyStr = (item.identifier?.rawValue ?? (item.key as? String ?? "")).lowercased()
                            if (keyStr.contains("tit2") || keyStr.contains("title")) && titleCandidate == nil {
                                titleCandidate = try? await item.load(.stringValue)
                            }
                            if (keyStr.contains("tpe1") || keyStr.contains("artist")) && artistCandidate == nil {
                                artistCandidate = try? await item.load(.stringValue)
                            }
                            if (keyStr.contains("tbpm") || keyStr.contains("bpm")), let val = try? await item.load(.stringValue) {
                                bpmCandidate = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
                            }
                            if (keyStr.contains("tkey") || keyStr.contains("initialkey")), let val = try? await item.load(.stringValue) {
                                keyCandidate = val.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            }
            
            if titleCandidate != nil || artistCandidate != nil || bpmCandidate > 0 || !keyCandidate.isEmpty {
                await MainActor.run { [weak self] in
                    self?.updateTrackMetadata(
                        filePath: filePath,
                        title: titleCandidate,
                        artist: artistCandidate,
                        bpm: bpmCandidate,
                        rawKey: keyCandidate
                    )
                }
            }
        }
        
        return true
    }
    
    /// Recherche et ajoute un morceau selon son Titre et son Artiste (résolution Rekordbox / Serato)
    @discardableResult
    public func lookupAndAddTrack(title: String, artist: String = "") -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return false }
        
        if UserSettings.shared.djSoftwareMode == .rekordbox {
            if let rbTrack = RekordboxService.shared.findTrack(title: cleanTitle, artist: artist) {
                return addTrack(rbTrack)
            }
            let seratoService = SeratoDatabaseService(databasePath: UserSettings.shared.effectiveDatabasePath)
            if let sTrack = seratoService.findTrackByTitleArtist(title: cleanTitle, artist: artist) {
                return addTrack(sTrack)
            }
        } else {
            let seratoService = SeratoDatabaseService(databasePath: UserSettings.shared.effectiveDatabasePath)
            if let sTrack = seratoService.findTrackByTitleArtist(title: cleanTitle, artist: artist) {
                return addTrack(sTrack)
            }
            if let rbTrack = RekordboxService.shared.findTrack(title: cleanTitle, artist: artist) {
                return addTrack(rbTrack)
            }
        }
        
        // Morceau virtuel si absent des bases locales
        let track = Track(
            title: cleanTitle,
            artist: artist,
            bpm: 0.0,
            rawKey: "",
            filePath: nil,
            fileName: "",
            portableId: UUID().uuidString
        )
        return addTrack(track)
    }
    
    /// Met à jour les métadonnées après chargement asynchrone des tags ID3
    private func updateTrackMetadata(
        filePath: String,
        title: String?,
        artist: String?,
        bpm: Double,
        rawKey: String
    ) {
        guard let index = tracks.firstIndex(where: { $0.filePath == filePath }) else { return }
        if let t = title, !t.isEmpty { tracks[index].title = t }
        if let a = artist, !a.isEmpty { tracks[index].artist = a }
        if bpm > 0 { tracks[index].bpm = bpm }
        if !rawKey.isEmpty { tracks[index].rawKey = rawKey }
        saveToDisk()
    }
    
    /// Supprime un morceau par son ID
    public func removeTrack(id: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tracks.removeAll { $0.id == id }
            saveToDisk()
        }
    }
    
    /// Supprime des morceaux par leurs index
    public func removeTracks(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tracks.remove(atOffsets: offsets)
            saveToDisk()
        }
    }
    
    /// Vide intégralement la liste des morceaux à jouer
    public func clearAll() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tracks.removeAll()
            saveToDisk()
        }
        showToast("Sélec vidée")
    }
    
    /// Récupère la liste sous forme de [Track] avec les relations harmoniques et de BPM calculées,
    /// ordonnée intelligemment par affinité ("match") avec le morceau en cours de lecture.
    public func toTrackList(referenceTrack: Track? = nil) -> [Track] {
        let list = tracks.map { $0.toTrack(referenceTrack: referenceTrack) }
        guard let ref = referenceTrack, (ref.bpm > 0 || ref.camelotKey != nil) else {
            return list
        }
        return sortTracksByMatch(list, referenceTrack: ref)
    }
    
    /// Trie les morceaux de la sélection selon la qualité de match avec le morceau en cours :
    /// - Le BPM est le paramètre prépondérant (proximité directe et demi/double tempo)
    /// - La gamme harmonique intervient en paramètre secondaire pour départager les morceaux proches
    private func sortTracksByMatch(_ tracks: [Track], referenceTrack: Track) -> [Track] {
        let indexed = tracks.enumerated().map { (index: $0.offset, track: $0.element, score: calculateMatchScore(for: $0.element, reference: referenceTrack)) }
        
        return indexed.sorted { a, b in
            // Différence de score significative
            if abs(a.score - b.score) > 0.0001 {
                return a.score < b.score
            }
            // En cas d'égalité quasi parfaite, conserver l'ordre d'ajout initial
            return a.index < b.index
        }.map { $0.track }
    }
    
    private func calculateMatchScore(for track: Track, reference: Track) -> Double {
        // 1. Écart de BPM (facteur prépondérant)
        let bpmPenalty: Double
        if reference.bpm > 0 && track.bpm > 0 {
            let bRef = reference.bpm
            let bCand = track.bpm
            
            // Distance relative directe
            let diffDirect = abs(bCand - bRef) / bRef
            
            // Distance demi-tempo (ex: 65 vs 130 bpm) avec une pénalité fixe de 4%
            let diffHalf = abs((bCand * 2.0) - bRef) / bRef + 0.04
            
            // Distance double-tempo (ex: 180 vs 90 bpm) avec une pénalité fixe de 4%
            let diffDouble = abs((bCand / 2.0) - bRef) / bRef + 0.04
            
            bpmPenalty = min(diffDirect, diffHalf, diffDouble)
        } else {
            // Pas de BPM disponible pour l'un ou l'autre
            bpmPenalty = 0.50
        }
        
        // 2. Compatibilité Harmonique (gamme, paramètre secondaire dans la balance)
        // Bonus équivalent à environ 1.5% à 2.5% de BPM :
        // permet à un morceau dans la clé de passer devant un morceau hors clé si leurs tempos sont proches (ex: 128 vs 129 bpm),
        // sans jamais passer devant un morceau ayant un écart de tempo ingérable (ex: 128 vs 180 ou 80 bpm).
        let harmonicBonus: Double
        switch track.harmonicRelation {
        case .exact:
            harmonicBonus = 0.025
        case .adjacent:
            harmonicBonus = 0.020
        case .relative:
            harmonicBonus = 0.018
        case .semitoneBoost:
            harmonicBonus = 0.017
        case .wholeToneBoost:
            harmonicBonus = 0.015
        case .diagonal:
            harmonicBonus = 0.012
        case .semitoneDrop:
            harmonicBonus = 0.008
        case .incompatible, .none:
            harmonicBonus = 0.0
        }
        
        // 3. Petit bonus si le combo fait partie des favoris du DJ
        let favoriteBonus = track.isFavorite ? 0.005 : 0.0
        
        return bpmPenalty - harmonicBonus - favoriteBonus
    }
    
    /// Traite les éléments déposés via SwiftUI (NSItemProvider)
    @discardableResult
    public func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                    guard let url = url else { return }
                    DispatchQueue.main.async {
                        self?.addTrack(fromURL: url)
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { [weak self] item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            self?.addTrack(fromURL: url)
                        }
                    } else if let url = item as? URL {
                        DispatchQueue.main.async {
                            self?.addTrack(fromURL: url)
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    
    // MARK: - Notifications Toast
    
    public func showToast(_ message: String) {
        toastMessage = message
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.toastMessage = nil
                }
            }
        }
    }
    
    // MARK: - Types et Gestionnaires Universels de Glisser-Déposer (Serato & Rekordbox)
    
    /// Types concrets seulement. Pas de texte générique, pas de « fichier promis ».
    /// Serato annonce le type privé `NSFilePromiseID` sans jamais y mettre de donnée.
    /// Si Recall s'inscrit à tout (y compris le texte) et lit le presse-papiers pendant
    /// le survol, macOS réclame cette donnée et tue Serato.
    public static var universalDragTypes: [NSPasteboard.PasteboardType] {
        return [
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x6974756E"),
            NSPasteboard.PasteboardType("itun"),
            NSPasteboard.PasteboardType("com.apple.itunes.metadata"),
            NSPasteboard.PasteboardType("com.apple.itunes.pboard"),
            NSPasteboard.PasteboardType("public.tabular-text"),
            NSPasteboard.PasteboardType("com.pioneer.rekordbox.track")
        ]
    }
    
    /// Traite l'ensemble des éléments déposés depuis le presse-papier macOS (Serato, Rekordbox, Finder)
    @discardableResult
    public func handleDroppedPasteboard(_ pasteboard: NSPasteboard, sender: NSDraggingInfo? = nil) -> Bool {
        var addedAny = false
        
        // Chemins déjà écrits par Serato ou le Finder.
        // On ne lit pas les promesses de fichier : Serato les annonce sans donnée.
        if let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String], !files.isEmpty {
            for file in files {
                let url = URL(fileURLWithPath: file)
                if addTrack(fromURL: url) {
                    addedAny = true
                }
            }
            if addedAny { return true }
        }
        
        // 3. Chaîne d'URL directe public.file-url
        if let str = pasteboard.string(forType: NSPasteboard.PasteboardType("public.file-url")), let url = URL(string: str), url.isFileURL {
            if addTrack(fromURL: url) {
                return true
            }
        }
        
        // 4. Format d'export Rekordbox / iTunes CorePasteboardFlavorType 0x6974756E / itun
        let itunTypes = [
            NSPasteboard.PasteboardType("CorePasteboardFlavorType 0x6974756E"),
            NSPasteboard.PasteboardType("itun"),
            NSPasteboard.PasteboardType("com.apple.itunes.metadata"),
            NSPasteboard.PasteboardType("com.apple.itunes.pboard")
        ]
        for itunType in itunTypes {
            if let data = pasteboard.data(forType: itunType) {
                if parseItunData(data) {
                    addedAny = true
                    break
                }
            }
        }
        if addedAny { return true }
        
        // Texte tabulaire (lignes Rekordbox). Types nommés uniquement.
        let textTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("public.tabular-text"),
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("com.apple.traditional-mac-plain-text")
        ]
        for tType in textTypes {
            if let text = pasteboard.string(forType: tType), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if parseDroppedText(text) {
                    addedAny = true
                    break
                }
            }
        }
        return addedAny
    }
    
    /// Décode les données de métadonnées du format iTunes / Rekordbox (0x6974756E)
    private func parseItunData(_ data: Data) -> Bool {
        var added = false
        
        // 1. Désérialisation Plist (format binaire ou XML Apple)
        if let rawObj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            if let plist = rawObj as? [String: Any] {
                if let tracksDict = plist["Tracks"] as? [String: [String: Any]] {
                    for (_, trackInfo) in tracksDict {
                        if let location = trackInfo["Location"] as? String, let url = URL(string: location) {
                            let fileURL = URL(fileURLWithPath: url.path)
                            if addTrack(fromURL: fileURL) {
                                added = true
                                continue
                            }
                        }
                        let title = trackInfo["Name"] as? String ?? ""
                        let artist = trackInfo["Artist"] as? String ?? ""
                        if !title.isEmpty && lookupAndAddTrack(title: title, artist: artist) {
                            added = true
                        }
                    }
                } else if let tracksList = plist["Tracks"] as? [[String: Any]] {
                    for trackInfo in tracksList {
                        if let location = trackInfo["Location"] as? String, let url = URL(string: location) {
                            let fileURL = URL(fileURLWithPath: url.path)
                            if addTrack(fromURL: fileURL) {
                                added = true
                                continue
                            }
                        }
                        let title = trackInfo["Name"] as? String ?? ""
                        let artist = trackInfo["Artist"] as? String ?? ""
                        if !title.isEmpty && lookupAndAddTrack(title: title, artist: artist) {
                            added = true
                        }
                    }
                }
            } else if let tracksList = rawObj as? [[String: Any]] {
                for trackInfo in tracksList {
                    if let location = trackInfo["Location"] as? String, let url = URL(string: location) {
                        let fileURL = URL(fileURLWithPath: url.path)
                        if addTrack(fromURL: fileURL) {
                            added = true
                            continue
                        }
                    }
                    let title = trackInfo["Name"] as? String ?? ""
                    let artist = trackInfo["Artist"] as? String ?? ""
                    if !title.isEmpty && lookupAndAddTrack(title: title, artist: artist) {
                        added = true
                    }
                }
            }
        }
        
        // 2. Décodage texte multi-encodages (UTF-8, UTF-16, Latin-1, ASCII)
        let stringCandidate = String(data: data, encoding: .utf8) ??
                             String(data: data, encoding: .utf16) ??
                             String(data: data, encoding: .utf16LittleEndian) ??
                             String(data: data, encoding: .utf16BigEndian) ??
                             String(data: data, encoding: .isoLatin1) ??
                             String(data: data, encoding: .ascii)
        
        if let stringContent = stringCandidate {
            // Détection de snippets XML Rekordbox (<TRACK ... Location="file://..." Name="..." Artist="..." />)
            if stringContent.range(of: "<track", options: .caseInsensitive) != nil {
                let pattern = "(?i)<TRACK[^>]+>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = stringContent as NSString
                    let matches = regex.matches(in: stringContent, options: [], range: NSRange(location: 0, length: nsString.length))
                    for match in matches {
                        let tag = nsString.substring(with: match.range)
                        let location = Self.extractAttribute("Location", from: tag)
                        let name = Self.extractAttribute("Name", from: tag)
                        let artist = Self.extractAttribute("Artist", from: tag)
                        
                        if !location.isEmpty, let url = URL(string: location) {
                            let fileURL = URL(fileURLWithPath: url.path)
                            if addTrack(fromURL: fileURL) {
                                added = true
                                continue
                            }
                        }
                        if !name.isEmpty && lookupAndAddTrack(title: name, artist: artist) {
                            added = true
                        }
                    }
                }
            }
            
            // 3. Scanner de secours pour URI file:// encodé dans le buffer
            let fileUriPattern = "file://[^<\"'\\r\\n\\t]+"
            if let regex = try? NSRegularExpression(pattern: fileUriPattern, options: []) {
                let nsString = stringContent as NSString
                let matches = regex.matches(in: stringContent, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    let matchedStr = nsString.substring(with: match.range)
                    if let decoded = matchedStr.removingPercentEncoding {
                        let cleanDecoded = decoded.replacingOccurrences(of: "file://localhost", with: "").replacingOccurrences(of: "file://", with: "")
                        let fileURL = URL(fileURLWithPath: cleanDecoded)
                        if FileManager.default.fileExists(atPath: fileURL.path) {
                            if addTrack(fromURL: fileURL) {
                                added = true
                            }
                        }
                    }
                }
            }
            
            // 4. Scanner universel de chemins de fichiers audio bruts (/Users/...)
            let rawPathPattern = #"(/Users/[^\x00\r\n\t\"\']+\.(?:mp3|wav|aif|aiff|flac|m4a|aac))"#
            if let regex = try? NSRegularExpression(pattern: rawPathPattern, options: [.caseInsensitive]) {
                let nsString = stringContent as NSString
                let matches = regex.matches(in: stringContent, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches {
                    let path = nsString.substring(with: match.range)
                    if FileManager.default.fileExists(atPath: path) {
                        if addTrack(fromURL: URL(fileURLWithPath: path)) {
                            added = true
                        }
                    }
                }
            }
        }
        
        return added
    }
    
    private static func extractAttribute(_ attr: String, from tag: String) -> String {
        let pattern = "(?i)\(attr)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: tag.utf16.count)),
              match.numberOfRanges > 1 else { return "" }
        let nsTag = tag as NSString
        return nsTag.substring(with: match.range(at: 1))
    }
    
    /// Parse une chaîne de texte déposée (chemins de fichiers ou colonnes tabulaires Rekordbox)
    private func parseDroppedText(_ text: String) -> Bool {
        var added = false
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.hasPrefix("file://") {
                if let url = URL(string: trimmed) {
                    let fileURL = URL(fileURLWithPath: url.path)
                    if addTrack(fromURL: fileURL) {
                        added = true
                        continue
                    }
                }
            } else if trimmed.hasPrefix("/") && FileManager.default.fileExists(atPath: trimmed) {
                if addTrack(fromURL: URL(fileURLWithPath: trimmed)) {
                    added = true
                    continue
                }
            }
            
            let columns = trimmed.components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if columns.count >= 2 {
                if Int(columns[0]) != nil && columns.count >= 3 {
                    if lookupAndAddTrack(title: columns[1], artist: columns[2]) {
                        added = true
                        continue
                    }
                    if lookupAndAddTrack(title: columns[2], artist: columns[1]) {
                        added = true
                        continue
                    }
                }
                if lookupAndAddTrack(title: columns[0], artist: columns[1]) {
                    added = true
                    continue
                }
                if lookupAndAddTrack(title: columns[1], artist: columns[0]) {
                    added = true
                    continue
                }
            } else if columns.count == 1 {
                let parsed = Track.parseSmartArtistAndTitle(rawString: columns[0])
                if lookupAndAddTrack(title: parsed.title, artist: parsed.artist ?? "") {
                    added = true
                    continue
                }
            }
        }
        
        return added
    }
}

// MARK: - Dépôt vers la Sélec sans participer au drag de Serato

/// Serato annonce le type privé `NSFilePromiseID` sans donnée. Dès qu'une autre
/// application s'inscrit comme cible du glisser, macOS réclame cette donnée et tue Serato.
/// Recall ne s'inscrit donc jamais. Au lâcher de la souris sur sa fenêtre, il lit
/// uniquement le chemin de fichier déjà écrit, jamais la liste des types.
@MainActor
public final class ExternalDropMonitor {
    public static let shared = ExternalDropMonitor()
    
    private var monitors: [Any] = []
    private var dragStartedInsideRecall = false
    private var cachedURLs: [URL] = []
    private var started = false
    
    private init() {}
    
    public func start() {
        guard !started else { return }
        started = true
        
        if let down = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown], handler: { event in
            DispatchQueue.main.async {
                ExternalDropMonitor.shared.dragStartedInsideRecall = true
                ExternalDropMonitor.shared.cachedURLs = []
            }
            return event
        }) {
            monitors.append(down)
        }
        if let down = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { _ in
            DispatchQueue.main.async {
                ExternalDropMonitor.shared.dragStartedInsideRecall = false
                ExternalDropMonitor.shared.cachedURLs = []
            }
        }) {
            monitors.append(down)
        }
        if let drag = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged], handler: { _ in
            DispatchQueue.main.async {
                ExternalDropMonitor.shared.trackHover()
            }
        }) {
            monitors.append(drag)
        }
        if let up = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp], handler: { _ in
            DispatchQueue.main.async {
                ExternalDropMonitor.shared.finishDrag()
            }
        }) {
            monitors.append(up)
        }
    }
    
    private func trackHover() {
        guard !dragStartedInsideRecall else { return }
        let inside = Self.recallWindowContainsMouse()
        if inside {
            if cachedURLs.isEmpty {
                cachedURLs = Self.safeFileURLs(from: NSPasteboard(name: .drag))
            }
            guard !cachedURLs.isEmpty else { return }
            DispatchQueue.main.async {
                ToPlayService.shared.isDraggingFileOver = true
            }
        } else if ToPlayService.shared.isDraggingFileOver {
            DispatchQueue.main.async {
                ToPlayService.shared.isDraggingFileOver = false
            }
        }
    }
    
    private func finishDrag() {
        let inside = Self.recallWindowContainsMouse()
        let startedInside = dragStartedInsideRecall
        let urls = cachedURLs.isEmpty ? Self.safeFileURLs(from: NSPasteboard(name: .drag)) : cachedURLs
        cachedURLs = []
        dragStartedInsideRecall = false
        DispatchQueue.main.async {
            ToPlayService.shared.isDraggingFileOver = false
            guard inside, !startedInside else { return }
            for url in urls {
                ToPlayService.shared.addTrack(fromURL: url)
            }
        }
    }
    
    private static func recallWindowContainsMouse() -> Bool {
        guard let window = FloatingWindowController.shared.window, window.isVisible else { return false }
        return window.frame.contains(NSEvent.mouseLocation)
    }
    
    /// Uniquement les chemins déjà présents. Jamais `types`, `pasteboardItems` ni les promesses.
    static func safeFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []
        if let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for file in files where !file.isEmpty {
                results.append(URL(fileURLWithPath: file))
            }
        }
        if results.isEmpty,
           let str = pasteboard.string(forType: NSPasteboard.PasteboardType("public.file-url")),
           let url = URL(string: str),
           url.isFileURL {
            results.append(url)
        }
        return results
    }
}

/// Vue conservée pour ne pas changer la mise en page. Elle ne s'inscrit plus au drag.
public final class RecallDropTargetNSView: NSView {
    public var onDropURLs: (([URL]) -> Void)?
    public var onDraggingChanged: ((Bool) -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        unregisterDraggedTypes()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        unregisterDraggedTypes()
    }
}

/// Pont SwiftUI pour la vue réceptrice de Drop
public struct RecallDropTargetViewRepresentable: NSViewRepresentable {
    public let onDropURLs: ([URL]) -> Void
    public let onDraggingChanged: (Bool) -> Void
    
    public init(
        onDropURLs: @escaping ([URL]) -> Void,
        onDraggingChanged: @escaping (Bool) -> Void
    ) {
        self.onDropURLs = onDropURLs
        self.onDraggingChanged = onDraggingChanged
    }
    
    public func makeNSView(context: Context) -> RecallDropTargetNSView {
        let view = RecallDropTargetNSView()
        view.onDropURLs = onDropURLs
        view.onDraggingChanged = onDraggingChanged
        return view
    }
    
    public func updateNSView(_ nsView: RecallDropTargetNSView, context: Context) {
        nsView.onDropURLs = onDropURLs
        nsView.onDraggingChanged = onDraggingChanged
    }
}
