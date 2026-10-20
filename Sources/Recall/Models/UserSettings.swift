import Foundation
import Combine
import SwiftUI

public enum PlayedTrackHighlightStyle: String, CaseIterable, Identifiable {
    case both = "both"         // Texte & fond teinté
    case textOnly = "textOnly" // Texte uniquement
    case bgOnly = "bgOnly"     // Fond teinté uniquement
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .both: return "Texte & Fond"
        case .textOnly: return "Texte seul"
        case .bgOnly: return "Fond seul"
        }
    }
}

public enum DJSoftwareMode: String, CaseIterable, Identifiable {
    case auto = "auto"
    case serato = "serato"
    case rekordbox = "rekordbox"
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .auto: return "Automatique (Détection temps réel)"
        case .serato: return "Serato DJ Pro"
        case .rekordbox: return "Pioneer DJ Rekordbox"
        }
    }
    
    public var shortLabel: String {
        switch self {
        case .auto: return "Auto"
        case .serato: return "Serato"
        case .rekordbox: return "Rekordbox"
        }
    }
}

public enum TransitionDirection: String, CaseIterable, Identifiable, Codable {
    case next = "next"         // → Après (par défaut)
    case previous = "previous" // ← Avant
    case all = "all"           // ⇄ Tout
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .next: return "Après"
        case .previous: return "Avant"
        case .all: return "Tout"
        }
    }
    
    public var icon: String {
        switch self {
        case .next: return "arrow.right"
        case .previous: return "arrow.left"
        case .all: return "arrow.left.and.right"
        }
    }
    
    public var tooltip: String {
        switch self {
        case .next: return "Transitions suivantes : Morceaux joués APRÈS (Par défaut)"
        case .previous: return "Transitions inversées : Morceaux joués AVANT (Introductions)"
        case .all: return "Toutes les transitions : Avant et Après combinés"
        }
    }
}

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
    @Published public var transitionDirection: TransitionDirection {
        didSet { UserDefaults.standard.set(transitionDirection.rawValue, forKey: "transitionDirection") }
    }
    
    @Published public var djSoftwareMode: DJSoftwareMode {
        didSet { UserDefaults.standard.set(djSoftwareMode.rawValue, forKey: "djSoftwareMode") }
    }
    @Published public var rekordboxXmlCustomPath: String {
        didSet { UserDefaults.standard.set(rekordboxXmlCustomPath, forKey: "rekordboxXmlCustomPath") }
    }
    @Published public var historyDaysLookback: Int {
        didSet { UserDefaults.standard.set(historyDaysLookback, forKey: "historyDaysLookback") }
    }
    @Published public var maxSuggestions: Int {
        didSet { UserDefaults.standard.set(maxSuggestions, forKey: "maxSuggestions") }
    }
    @Published public var bpmTolerancePercent: Double {
        didSet { UserDefaults.standard.set(bpmTolerancePercent, forKey: "bpmTolerancePercent") }
    }
    @Published public var isBpmFilterActive: Bool {
        didSet { UserDefaults.standard.set(isBpmFilterActive, forKey: "isBpmFilterActive") }
    }
    @Published public var isHarmonicFilterActive: Bool {
        didSet { UserDefaults.standard.set(isHarmonicFilterActive, forKey: "isHarmonicFilterActive") }
    }
    @Published public var isFavoritesFilterActive: Bool {
        didSet { UserDefaults.standard.set(isFavoritesFilterActive, forKey: "isFavoritesFilterActive") }
    }
    @Published public var isToPlayFilterActive: Bool {
        didSet { UserDefaults.standard.set(isToPlayFilterActive, forKey: "isToPlayFilterActive") }
    }
    @Published public var minTransitionsCount: Int {
        didSet { UserDefaults.standard.set(minTransitionsCount, forKey: "minTransitionsCount") }
    }
    @Published public var alwaysOnTop: Bool {
        didSet { UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop") }
    }
    @Published public var keyDisplayMode: Int {
        didSet { UserDefaults.standard.set(keyDisplayMode, forKey: "keyDisplayMode") }
    }
    @Published public var isCompactMode: Bool {
        didSet { UserDefaults.standard.set(isCompactMode, forKey: "isCompactMode") }
    }
    @Published public var hidePlayedTracks: Bool {
        didSet { UserDefaults.standard.set(hidePlayedTracks, forKey: "hidePlayedTracks") }
    }
    @Published public var seratoDatabaseCustomPath: String {
        didSet { UserDefaults.standard.set(seratoDatabaseCustomPath, forKey: "seratoDatabaseCustomPath") }
    }
    @Published public var playedTrackColorHex: String {
        didSet { UserDefaults.standard.set(playedTrackColorHex, forKey: "playedTrackColorHex") }
    }
    @Published public var playedTrackStyle: String {
        didSet { UserDefaults.standard.set(playedTrackStyle, forKey: "playedTrackStyle") }
    }
    @Published public var playedMinDurationSeconds: Int {
        didSet { UserDefaults.standard.set(playedMinDurationSeconds, forKey: "playedMinDurationSeconds") }
    }
    @Published public var cumulateVariantSuggestions: Bool {
        didSet { UserDefaults.standard.set(cumulateVariantSuggestions, forKey: "cumulateVariantSuggestions") }
    }
    @Published public var includeEnergyBoostInHarmonicFilter: Bool {
        didSet { UserDefaults.standard.set(includeEnergyBoostInHarmonicFilter, forKey: "includeEnergyBoostInHarmonicFilter") }
    }
    @Published public var includeDiagonalInHarmonicFilter: Bool {
        didSet { UserDefaults.standard.set(includeDiagonalInHarmonicFilter, forKey: "includeDiagonalInHarmonicFilter") }
    }
    @Published public var djTheme: DJTheme {
        didSet {
            UserDefaults.standard.set(djTheme.rawValue, forKey: "djTheme")
            #if os(macOS)
            updateAppDockIcon()
            #endif
        }
    }
    /// Degré de translucidité du verre dépoli (0.0 = Noir opaque, 1.0 = Translucidité maximale)
    @Published public var glassTranslucency: Double {
        didSet {
            UserDefaults.standard.set(glassTranslucency, forKey: "glassTranslucency")
            UserDefaults.standard.set(effectiveGlassTintOpacity, forKey: "glassOpacity")
        }
    }
    /// Opacité réelle de la teinte sombre appliquée par-dessus le flou natif macOS (1.0 = Opaque, 0.04 = Verre cristallin pur)
    public var effectiveGlassTintOpacity: Double {
        max(0.04, 1.0 - (glassTranslucency * 0.96))
    }
    /// Propriété de compatibilité avec les composants existants
    public var glassOpacity: Double {
        get { effectiveGlassTintOpacity }
        set { glassTranslucency = max(0.0, min(1.0, (1.0 - newValue) / 0.96)) }
    }
    @Published public var hotKeyPreset: HotKeyModifierPreset {
        didSet {
            UserDefaults.standard.set(hotKeyPreset.rawValue, forKey: "hotKeyPreset")
            GlobalHotKeyService.shared.updateRegistrations(preset: hotKeyPreset)
        }
    }
    
    /// Lancement automatique de Recall au démarrage de macOS en tâche de fond (Recommandé DJ)
    @Published public var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            Task { @MainActor in
                LaunchAtLoginService.setEnabled(launchAtLogin)
            }
        }
    }
    
    /// Présence d'un compagnon résident dans la barre des menus macOS
    @Published public var enableMenuBarCompanion: Bool {
        didSet {
            UserDefaults.standard.set(enableMenuBarCompanion, forKey: "enableMenuBarCompanion")
            Task { @MainActor in
                MenuBarCompanionService.shared.setEnabled(enableMenuBarCompanion)
            }
        }
    }
    
    public var accentColor: Color {
        djTheme.accentColor
    }
    
    public var accentSecondaryColor: Color {
        djTheme.secondaryColor
    }
    
    public init() {
        let def = UserDefaults.standard
        let rawDir = def.string(forKey: "transitionDirection") ?? TransitionDirection.next.rawValue
        self.transitionDirection = TransitionDirection(rawValue: rawDir) ?? .next
        let rawMode = def.string(forKey: "djSoftwareMode") ?? DJSoftwareMode.auto.rawValue
        self.djSoftwareMode = DJSoftwareMode(rawValue: rawMode) ?? .auto
        self.rekordboxXmlCustomPath = def.string(forKey: "rekordboxXmlCustomPath") ?? ""
        self.historyDaysLookback = def.object(forKey: "historyDaysLookback") != nil ? def.integer(forKey: "historyDaysLookback") : 360
        self.maxSuggestions = def.object(forKey: "maxSuggestions") != nil ? def.integer(forKey: "maxSuggestions") : 30
        self.bpmTolerancePercent = def.object(forKey: "bpmTolerancePercent") != nil ? def.double(forKey: "bpmTolerancePercent") : 8.0
        self.isBpmFilterActive = def.bool(forKey: "isBpmFilterActive")
        self.isHarmonicFilterActive = def.bool(forKey: "isHarmonicFilterActive")
        self.isFavoritesFilterActive = def.bool(forKey: "isFavoritesFilterActive")
        self.isToPlayFilterActive = def.bool(forKey: "isToPlayFilterActive")
        self.minTransitionsCount = def.object(forKey: "minTransitionsCount") != nil ? def.integer(forKey: "minTransitionsCount") : 1
        self.alwaysOnTop = def.object(forKey: "alwaysOnTop") != nil ? def.bool(forKey: "alwaysOnTop") : true
        self.keyDisplayMode = def.integer(forKey: "keyDisplayMode")
        self.isCompactMode = def.bool(forKey: "isCompactMode")
        self.hidePlayedTracks = def.bool(forKey: "hidePlayedTracks")
        self.seratoDatabaseCustomPath = def.string(forKey: "seratoDatabaseCustomPath") ?? ""
        self.playedTrackColorHex = def.string(forKey: "playedTrackColorHex") ?? "#0FA2FF"
        self.playedTrackStyle = def.string(forKey: "playedTrackStyle") ?? "both"
        self.playedMinDurationSeconds = def.object(forKey: "playedMinDurationSeconds") != nil ? def.integer(forKey: "playedMinDurationSeconds") : 25
        self.cumulateVariantSuggestions = def.object(forKey: "cumulateVariantSuggestions") != nil ? def.bool(forKey: "cumulateVariantSuggestions") : true
        self.includeEnergyBoostInHarmonicFilter = def.object(forKey: "includeEnergyBoostInHarmonicFilter") != nil ? def.bool(forKey: "includeEnergyBoostInHarmonicFilter") : true
        self.includeDiagonalInHarmonicFilter = def.object(forKey: "includeDiagonalInHarmonicFilter") != nil ? def.bool(forKey: "includeDiagonalInHarmonicFilter") : true
        let rawTheme = def.string(forKey: "djTheme") ?? DJTheme.cyanNeon.rawValue
        self.djTheme = DJTheme(rawValue: rawTheme) ?? .cyanNeon
        if def.object(forKey: "glassTranslucency") != nil {
            self.glassTranslucency = def.double(forKey: "glassTranslucency")
        } else if let savedOpacity = def.object(forKey: "glassOpacity") as? Double {
            self.glassTranslucency = max(0.0, min(1.0, (1.0 - savedOpacity) / 0.88))
        } else {
            self.glassTranslucency = 0.50
        }
        let rawHotKey = def.string(forKey: "hotKeyPreset") ?? HotKeyModifierPreset.cmdOption.rawValue
        self.hotKeyPreset = HotKeyModifierPreset(rawValue: rawHotKey) ?? .cmdOption
        
        if def.object(forKey: "launchAtLogin") == nil {
            self.launchAtLogin = true
            Task { @MainActor in
                LaunchAtLoginService.setEnabled(true)
            }
        } else {
            self.launchAtLogin = def.bool(forKey: "launchAtLogin")
        }
        
        if def.object(forKey: "enableMenuBarCompanion") == nil {
            self.enableMenuBarCompanion = true
        } else {
            self.enableMenuBarCompanion = def.bool(forKey: "enableMenuBarCompanion")
        }
        
        #if os(macOS)
        updateAppDockIcon()
        #endif
    }
    
    #if os(macOS)
    /// Met à jour dynamiquement l'icône de l'application dans le Dock macOS pour refléter le thème DJ choisi
    public func updateAppDockIcon() {
        DispatchQueue.main.async {
            if let icon = self.djTheme.dockIconImage ?? self.djTheme.iconImage {
                NSApplication.shared.applicationIconImage = icon
            }
        }
    }
    #endif
    
    public var defaultDatabasePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Serato/Library/master.sqlite"
    }
    
    public var effectiveDatabasePath: String {
        if !seratoDatabaseCustomPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return seratoDatabaseCustomPath
        }
        return defaultDatabasePath
    }
    
    /// Détection automatique des emplacements connus de collection Rekordbox XML
    public static func autoDetectRekordboxXmlPath() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        var allCandidates: [String] = []
        
        // 1. Lire rekordbox3.settings si disponible (pont officiel bridgeImportedLibraryFile)
        let settingsPath = "\(home)/Library/Application Support/Pioneer/rekordbox6/rekordbox3.settings"
        if fm.fileExists(atPath: settingsPath),
           let content = try? String(contentsOfFile: settingsPath, encoding: .utf8) {
            let pattern = "name=\"bridgeImportedLibraryFile\"\\s+val=\"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range(at: 1), in: content) {
                let candidate = String(content[range])
                allCandidates.append(candidate)
                let stripped = candidate.replacingOccurrences(of: "/Volumes/Macintosh HD", with: "")
                allCandidates.append(stripped)
            }
        }
        
        // 2. Emplacements standards de sauvegarde et synchronisation XML Rekordbox
        allCandidates.append(contentsOf: [
            "\(home)/Documents/rekordbox.xml",
            "\(home)/Documents/Lexicon/rekordbox.xml",
            "\(home)/Documents/Backup Rekordbkox/Collection rekordbox.xml",
            "\(home)/Library/Pioneer/rekordbox/rekordbox.xml"
        ])
        
        // Trouver tous les fichiers existants et sélectionner le plus récent
        var existingCandidates: [(path: String, modDate: Date)] = []
        var seen = Set<String>()
        for path in allCandidates {
            guard !seen.contains(path) else { continue }
            seen.insert(path)
            if fm.fileExists(atPath: path) {
                let modDate = ((try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date) ?? .distantPast
                existingCandidates.append((path, modDate))
            }
        }
        
        existingCandidates.sort { $0.modDate > $1.modDate }
        return existingCandidates.first?.path
    }
    
    public var effectiveRekordboxXmlPath: String {
        let trimmed = rekordboxXmlCustomPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
        if let autoDetected = UserSettings.autoDetectRekordboxXmlPath() {
            return autoDetected
        }
        return "\(FileManager.default.homeDirectoryForCurrentUser.path)/Documents/rekordbox.xml"
    }
    
    public var playedTrackColor: Color {
        Color(hex: playedTrackColorHex)
    }
    
    public var playedTrackHighlightStyle: PlayedTrackHighlightStyle {
        get { PlayedTrackHighlightStyle(rawValue: playedTrackStyle) ?? .both }
        set { playedTrackStyle = newValue.rawValue }
    }
    
    public func resetToDefaults() {
        transitionDirection = .next
        djSoftwareMode = .auto
        rekordboxXmlCustomPath = ""
        historyDaysLookback = 360
        maxSuggestions = 30
        bpmTolerancePercent = 8.0
        isBpmFilterActive = false
        isHarmonicFilterActive = false
        isFavoritesFilterActive = false
        minTransitionsCount = 1
        alwaysOnTop = true
        keyDisplayMode = 0
        hidePlayedTracks = false
        seratoDatabaseCustomPath = ""
        playedTrackColorHex = "#0FA2FF"
        playedTrackStyle = "both"
        playedMinDurationSeconds = 25
        hotKeyPreset = .cmdOption
        djTheme = .cyanNeon
        glassOpacity = 0.96
    }
}
