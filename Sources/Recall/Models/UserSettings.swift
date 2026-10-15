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

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
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
    
    public init() {
        let def = UserDefaults.standard
        self.historyDaysLookback = def.object(forKey: "historyDaysLookback") != nil ? def.integer(forKey: "historyDaysLookback") : 360
        self.maxSuggestions = def.object(forKey: "maxSuggestions") != nil ? def.integer(forKey: "maxSuggestions") : 30
        self.bpmTolerancePercent = def.object(forKey: "bpmTolerancePercent") != nil ? def.double(forKey: "bpmTolerancePercent") : 8.0
        self.isBpmFilterActive = def.bool(forKey: "isBpmFilterActive")
        self.isHarmonicFilterActive = def.bool(forKey: "isHarmonicFilterActive")
        self.isFavoritesFilterActive = def.bool(forKey: "isFavoritesFilterActive")
        self.minTransitionsCount = def.object(forKey: "minTransitionsCount") != nil ? def.integer(forKey: "minTransitionsCount") : 1
        self.alwaysOnTop = def.object(forKey: "alwaysOnTop") != nil ? def.bool(forKey: "alwaysOnTop") : true
        self.keyDisplayMode = def.integer(forKey: "keyDisplayMode")
        self.isCompactMode = def.bool(forKey: "isCompactMode")
        self.hidePlayedTracks = def.bool(forKey: "hidePlayedTracks")
        self.seratoDatabaseCustomPath = def.string(forKey: "seratoDatabaseCustomPath") ?? ""
        self.playedTrackColorHex = def.string(forKey: "playedTrackColorHex") ?? "#0FA2FF"
        self.playedTrackStyle = def.string(forKey: "playedTrackStyle") ?? "both"
        self.playedMinDurationSeconds = def.object(forKey: "playedMinDurationSeconds") != nil ? def.integer(forKey: "playedMinDurationSeconds") : 25
    }
    
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
    
    public var playedTrackColor: Color {
        Color(hex: playedTrackColorHex)
    }
    
    public var playedTrackHighlightStyle: PlayedTrackHighlightStyle {
        get { PlayedTrackHighlightStyle(rawValue: playedTrackStyle) ?? .both }
        set { playedTrackStyle = newValue.rawValue }
    }
    
    public func resetToDefaults() {
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
    }
}
