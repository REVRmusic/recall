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
    
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !fileName.isEmpty {
            return (fileName as NSString).deletingPathExtension
        }
        return "Morceau inconnu"
    }
    
    public var displayArtist: String {
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty &&
           trimmed.lowercased() != "artiste inconnu" &&
           trimmed.lowercased() != "unknown artist" &&
           trimmed.lowercased() != "unknown" {
            return trimmed
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
            isFavorite: false,
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
            print("Erreur chargement des morceaux à jouer: \(error)")
            self.tracks = []
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(tracks)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erreur sauvegarde des morceaux à jouer: \(error)")
        }
    }
    
    // MARK: - Gestion des Morceaux
    
    /// Ajoute un morceau directement depuis un objet Track
    @discardableResult
    public func addTrack(_ track: Track) -> Bool {
        let normTitle = FavoriteCombosService.normalize(track.displayTitle)
        
        // Si le morceau est déjà présent, on le déplace en tête de liste
        if let existingIndex = tracks.firstIndex(where: {
            FavoriteCombosService.normalize($0.displayTitle) == normTitle ||
            (!track.fileName.isEmpty && !$0.fileName.isEmpty && FavoriteCombosService.normalize($0.fileName) == FavoriteCombosService.normalize(track.fileName))
        }) {
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
    public func addTrack(fromURL url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let filePath = url.path
        let fileName = url.lastPathComponent
        
        // 1. Recherche prioritaire dans la base SQLite de Serato (métadonnées précises Serato)
        let seratoService = SeratoDatabaseService(databasePath: UserSettings.shared.effectiveDatabasePath)
        if let seratoTrack = seratoService.findTrackByFile(filePath: filePath, fileName: fileName) {
            return addTrack(seratoTrack)
        }
        
        // 2. Recherche dans la collection Rekordbox XML
        if let rekordboxTrack = RekordboxService.shared.findTrackByFile(filePath: filePath, fileName: fileName) {
            return addTrack(rekordboxTrack)
        }
        
        // 3. Ajout immédiat avec analyse intelligente du nom de fichier
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
        
        addTrack(initialTrack)
        
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
    
    /// Récupère la liste sous forme de [Track] avec les relations harmoniques et de BPM calculées
    public func toTrackList(referenceTrack: Track? = nil) -> [Track] {
        return tracks.map { $0.toTrack(referenceTrack: referenceTrack) }
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
}

// MARK: - Composant Natif AppKit de Destination de Glisser-Déposer

/// Vue AppKit native dédiée à la réception absolue des glisser-déposer de morceaux depuis Serato DJ Pro
public final class RecallDropTargetNSView: NSView {
    public var onDropURLs: (([URL]) -> Void)?
    public var onDraggingChanged: ((Bool) -> Void)?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragTypes()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragTypes()
    }
    
    private func setupDragTypes() {
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("public.file-url")
        ])
    }
    
    private func canHandle(pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains(.fileURL) ||
               types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType")) ||
               types.contains(NSPasteboard.PasteboardType("public.file-url"))
    }
    
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if canHandle(pasteboard: sender.draggingPasteboard) {
            onDraggingChanged?(true)
            return .copy
        }
        return []
    }
    
    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return canHandle(pasteboard: sender.draggingPasteboard) ? .copy : []
    }
    
    public override func draggingExited(_ sender: NSDraggingInfo?) {
        onDraggingChanged?(false)
    }
    
    public override func draggingEnded(_ sender: NSDraggingInfo) {
        onDraggingChanged?(false)
    }
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDraggingChanged?(false)
        let urls = extractURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        onDropURLs?(urls)
        return true
    }
    
    private func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []
        
        // 1. Objets NSURL natifs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls where url.isFileURL {
                results.append(url)
            }
        }
        
        // 2. Format historique NSFilenamesPboardType de Serato
        if results.isEmpty,
           let filePaths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            for path in filePaths {
                results.append(URL(fileURLWithPath: path))
            }
        }
        
        // 3. Chaîne d'URL brute
        if results.isEmpty, let urlStr = pasteboard.string(forType: .fileURL), let url = URL(string: urlStr) {
            results.append(url)
        }
        
        return results
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
