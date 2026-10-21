import SwiftUI
import AppKit
import Combine

/// Données statistiques calculées à partir de la session en cours
public struct SetRecapStats {
    public let totalTracksCount: Int
    public let totalPlaysCount: Int
    public let totalDurationSeconds: Double
    public let averageTimePerTrackSeconds: Double
    public let tracksPerHour: Double
    
    public let averageBpm: Double
    public let minBpm: Double
    public let maxBpm: Double
    
    public let dominantKey: String?
    public let dominantKeyCount: Int
    public let dominantKeyPercentage: Double
    public let keyDistribution: [(key: String, count: Int, percent: Double)]
    
    public struct TransitionRecord {
        public let fromTrack: String
        public let toTrack: String
        public let elapsedSeconds: Double
    }
    
    public let fastestTransition: TransitionRecord?
    public let longestTransition: TransitionRecord?
    
    public struct ArtistRecord: Identifiable {
        public var id: String { name }
        public let name: String
        public let count: Int
        public let percent: Double
    }
    
    public struct GenreRecord: Identifiable {
        public var id: String { name }
        public let name: String
        public let count: Int
        public let percent: Double
    }
    
    public let topArtists: [ArtistRecord]
    public let mostPlayedArtist: ArtistRecord?
    public let topGenres: [GenreRecord]
    public let mostPlayedGenre: GenreRecord?
    public let isLiveSession: Bool
    
    public static func empty(isLive: Bool = false) -> SetRecapStats {
        return SetRecapStats(
            totalTracksCount: 0,
            totalPlaysCount: 0,
            totalDurationSeconds: 0.0,
            averageTimePerTrackSeconds: 0,
            tracksPerHour: 0,
            averageBpm: 0,
            minBpm: 0,
            maxBpm: 0,
            dominantKey: nil,
            dominantKeyCount: 0,
            dominantKeyPercentage: 0,
            keyDistribution: [],
            fastestTransition: nil,
            longestTransition: nil,
            topArtists: [],
            mostPlayedArtist: nil,
            topGenres: [],
            mostPlayedGenre: nil,
            isLiveSession: isLive
        )
    }
    
    public static func compute(from tracks: [SessionPlayedTrack], sessionStartTime: Date) -> SetRecapStats {
        let count = tracks.count
        guard count > 0 else {
            return empty(isLive: false)
        }
        
        let totalPlays = tracks.reduce(0) { $0 + $1.playCount }
        
        // Calcul temporel haute précision basé sur les intervalles réels de lecture
        let now = Date()
        let (totalDuration, isLive) = SessionHistoryService.computeTotalPlaybackDuration(from: tracks, now: now)
        let effectiveDuration = max(totalDuration, tracks.isEmpty ? 0.0 : 1.0)
        
        let avgTimePerTrack = count > 0 && effectiveDuration > 0 ? effectiveDuration / Double(count) : 0
        let tracksPerHour = effectiveDuration > 0 ? (Double(count) / effectiveDuration) * 3600.0 : 0
        
        // BPM
        let validBpms = tracks.map { $0.bpm }.filter { $0 > 0 }
        let avgBpm: Double = !validBpms.isEmpty ? validBpms.reduce(0, +) / Double(validBpms.count) : 0
        let minBpm = validBpms.min() ?? 0
        let maxBpm = validBpms.max() ?? 0
        
        // Tonalité dominante (avec horodatage pour départage stable)
        var keyCounts: [String: Int] = [:]
        var keyLatestDate: [String: Date] = [:]
        for tr in tracks {
            let keyStr: String
            if let cam = tr.camelotKey {
                keyStr = cam.displayText(mode: UserSettings.shared.keyDisplayMode)
            } else if !tr.rawKey.isEmpty {
                keyStr = tr.rawKey
            } else {
                continue
            }
            keyCounts[keyStr, default: 0] += 1
            if let existing = keyLatestDate[keyStr] {
                keyLatestDate[keyStr] = max(existing, tr.playedAt)
            } else {
                keyLatestDate[keyStr] = tr.playedAt
            }
        }
        
        let totalTracksWithKey = keyCounts.values.reduce(0, +)
        let sortedKeys: [(key: String, count: Int, percent: Double)] = keyCounts
            .sorted { a, b in
                if a.value != b.value {
                    return a.value > b.value
                }
                let dateA = keyLatestDate[a.key] ?? .distantPast
                let dateB = keyLatestDate[b.key] ?? .distantPast
                if dateA != dateB {
                    return dateA > dateB
                }
                return a.key < b.key
            }
            .map { (key: $0.key, count: $0.value, percent: totalTracksWithKey > 0 ? (Double($0.value) / Double(totalTracksWithKey)) * 100.0 : 0.0) }
        
        let dominantKeyRecord = sortedKeys.first
        
        // Enchaînements (Chronologique)
        let chronTracks = tracks.sorted { $0.playedAt < $1.playedAt }
        var transitions: [TransitionRecord] = []
        if chronTracks.count >= 2 {
            for i in 0 ..< (chronTracks.count - 1) {
                let t1 = chronTracks[i]
                let t2 = chronTracks[i + 1]
                let diff = max(0, t2.playedAt.timeIntervalSince(t1.playedAt))
                // Filtre : au moins 15s pour écarter les double-drops instantanés ou erreurs
                if diff >= 15.0 {
                    transitions.append(TransitionRecord(
                        fromTrack: t1.displayTitle,
                        toTrack: t2.displayTitle,
                        elapsedSeconds: diff
                    ))
                }
            }
        }
        
        let fastest = transitions.min(by: { $0.elapsedSeconds < $1.elapsedSeconds })
        let longest = transitions.max(by: { $0.elapsedSeconds < $1.elapsedSeconds })
        
        // Top Artistes (avec horodatage pour départage stable)
        var artistCounts: [String: Int] = [:]
        var artistLatestDate: [String: Date] = [:]
        for tr in tracks {
            let art = tr.displayArtist.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !art.isEmpty,
                  art.lowercased() != "artiste inconnu",
                  art.lowercased() != "unknown artist",
                  art.lowercased() != "unknown",
                  !TrackMetadataCleaner.isJunkOrPromoArtist(art),
                  !TrackMetadataCleaner.isKnownGenericGenre(art) else { continue }
            
            // Regroupement intelligent par artiste principal (ex: "Drake, Hamza" -> "Drake", "Drake ft. 21 Savage" -> "Drake")
            let primary = TrackMetadataCleaner.extractPrimaryArtist(art)
            let countedName = !primary.isEmpty ? primary : art
            
            artistCounts[countedName, default: 0] += 1
            if let existing = artistLatestDate[countedName] {
                artistLatestDate[countedName] = max(existing, tr.playedAt)
            } else {
                artistLatestDate[countedName] = tr.playedAt
            }
        }
        
        let totalArtistPlays = artistCounts.values.reduce(0, +)
        let topArtistsList: [ArtistRecord] = artistCounts
            .sorted { a, b in
                if a.value != b.value {
                    return a.value > b.value
                }
                let dateA = artistLatestDate[a.key] ?? .distantPast
                let dateB = artistLatestDate[b.key] ?? .distantPast
                if dateA != dateB {
                    return dateA > dateB
                }
                return a.key < b.key
            }
            .prefix(5)
            .map { ArtistRecord(name: $0.key, count: $0.value, percent: totalArtistPlays > 0 ? (Double($0.value) / Double(totalArtistPlays)) * 100.0 : 0.0) }
        
        // Top Genres (avec horodatage pour départage stable)
        var genreCounts: [String: Int] = [:]
        var genreLatestDate: [String: Date] = [:]
        for tr in tracks {
            let canonical = tr.displayGenre
            guard !canonical.isEmpty,
                  !TrackMetadataCleaner.isJunkOrPromoArtist(canonical) else { continue }
            
            // Si le genre correspond en réalité au nom de l'artiste résolu, ne pas le compter comme genre musical
            let artLower = tr.displayArtist.lowercased()
            let primaryLower = TrackMetadataCleaner.extractPrimaryArtist(tr.displayArtist).lowercased()
            if canonical.lowercased() == artLower || (!primaryLower.isEmpty && canonical.lowercased() == primaryLower) {
                continue
            }
            
            genreCounts[canonical, default: 0] += 1
            if let existing = genreLatestDate[canonical] {
                genreLatestDate[canonical] = max(existing, tr.playedAt)
            } else {
                genreLatestDate[canonical] = tr.playedAt
            }
        }
        
        let totalGenrePlays = genreCounts.values.reduce(0, +)
        let topGenresList: [GenreRecord] = genreCounts
            .sorted { a, b in
                if a.value != b.value {
                    return a.value > b.value
                }
                let dateA = genreLatestDate[a.key] ?? .distantPast
                let dateB = genreLatestDate[b.key] ?? .distantPast
                if dateA != dateB {
                    return dateA > dateB
                }
                return a.key < b.key
            }
            .prefix(5)
            .map { GenreRecord(name: $0.key, count: $0.value, percent: totalGenrePlays > 0 ? (Double($0.value) / Double(totalGenrePlays)) * 100.0 : 0.0) }
        
        return SetRecapStats(
            totalTracksCount: count,
            totalPlaysCount: totalPlays,
            totalDurationSeconds: totalDuration,
            averageTimePerTrackSeconds: avgTimePerTrack,
            tracksPerHour: tracksPerHour,
            averageBpm: avgBpm,
            minBpm: minBpm,
            maxBpm: maxBpm,
            dominantKey: dominantKeyRecord?.key,
            dominantKeyCount: dominantKeyRecord?.count ?? 0,
            dominantKeyPercentage: dominantKeyRecord?.percent ?? 0,
            keyDistribution: Array(sortedKeys.prefix(4)),
            fastestTransition: fastest,
            longestTransition: longest,
            topArtists: topArtistsList,
            mostPlayedArtist: topArtistsList.first,
            topGenres: topGenresList,
            mostPlayedGenre: topGenresList.first,
            isLiveSession: isLive
        )
    }
}

/// Vue principale de restitution des Statistiques du Mix (Set Recap)
public struct SetRecapView: View {
    @ObservedObject private var sessionService = SessionHistoryService.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var currentTime = Date()
    public enum ExportTarget {
        case photos
        case share
        case copyImage
        case saveFile
        case webLink
        
        var modalTitle: String {
            switch self {
            case .photos: return "Enregistrer dans Photos"
            case .share: return "Partager l'image"
            case .copyImage: return "Copier l'image"
            case .saveFile: return "Enregistrer le fichier PNG"
            case .webLink: return "Partager la page web"
            }
        }
        
        var actionButtonTitle: String {
            switch self {
            case .photos: return "Enregistrer dans Photos"
            case .share: return "Partager le visuel"
            case .copyImage: return "Copier dans le presse-papier"
            case .saveFile: return "Enregistrer le fichier..."
            case .webLink: return "Créer le lien sécurisé"
            }
        }
        
        var actionIcon: String {
            switch self {
            case .photos: return "photo.badge.plus"
            case .share: return "square.and.arrow.up"
            case .copyImage: return "doc.on.doc.fill"
            case .saveFile: return "arrow.down.doc.fill"
            case .webLink: return "link.badge.plus"
            }
        }
    }
    
    @State private var isShowingExportCustomization: Bool = false
    @State private var exportSessionTitleInput: String = ""
    @AppStorage("recap_export_hide_duration") private var exportHideDuration: Bool = false
    @State private var pendingExportTarget: ExportTarget = .photos
    @State private var isPublishingWeb: Bool = false
    @FocusState private var isTitleFieldFocused: Bool
    
    @State private var isCloseHovered: Bool = false
    @State private var isPhotosHovered: Bool = false
    @State private var isShareHovered: Bool = false
    @State private var isPickerHovered: Bool = false
    @State private var isExporting: Bool = false
    @State private var toastMessage: String? = nil
    @State private var toastIcon: String = "checkmark.circle.fill"
    @State private var toastColor: Color = .green
    
    public var onClose: (() -> Void)?
    public var onOpenTracklist: (() -> Void)?
    
    @State private var pastSessionStats: SetRecapStats? = nil
    @State private var pastSessions: [SeratoDatabaseService.PastSessionItem] = SeratoDatabaseService.shared.cachedPastSessionsImmediate ?? []
    @State private var selectedPastSession: SeratoDatabaseService.PastSessionItem? = nil
    @State private var pastSessionTracks: [SessionPlayedTrack] = []
    @State private var isLoadingPastSession: Bool = false
    @State private var isLoadingPastSessionsList: Bool = false
    @State private var pastSessionLoadTask: Task<Void, Never>? = nil
    @State private var pastSessionsListTask: Task<Void, Never>? = nil
    @State private var isSessionPickerOpen: Bool = false
    @State private var sessionSearchText: String = ""
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(onClose: (() -> Void)? = nil, onOpenTracklist: (() -> Void)? = nil) {
        self.onClose = onClose
        self.onOpenTracklist = onOpenTracklist
    }
    
    private var stats: SetRecapStats {
        if let past = selectedPastSession {
            if let ps = pastSessionStats {
                return ps
            }
            if !pastSessionTracks.isEmpty {
                return SetRecapStats.compute(
                    from: pastSessionTracks,
                    sessionStartTime: past.startTime
                )
            }
            return SetRecapStats.empty(isLive: false)
        }
        
        // Session en direct : calcul dynamique et instantané basé sur les morceaux joués en temps réel
        return SetRecapStats.compute(
            from: sessionService.playedTracks,
            sessionStartTime: sessionService.sessionStartTime
        )
    }
    
    private var effectiveSessionStartTime: Date {
        return selectedPastSession?.startTime ?? sessionService.sessionStartTime
    }
    
    private var effectiveTracks: [SessionPlayedTrack] {
        return selectedPastSession != nil ? pastSessionTracks : sessionService.playedTracks
    }
    
    /// Horaires de début et de fin du set avec détection en direct et sessions archivées
    private var setTimeRange: (start: Date, end: Date?, isLive: Bool, formattedStart: String, formattedEnd: String) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "HH'h'mm"
        
        if let past = selectedPastSession {
            let start = past.startTime
            let startStr = df.string(from: start)
            
            if let end = past.endTime {
                return (start, end, false, startStr, df.string(from: end))
            } else if let lastTrack = pastSessionTracks.max(by: { ($0.endTime ?? $0.playedAt) < ($1.endTime ?? $1.playedAt) }) {
                let estimatedEnd = lastTrack.endTime ?? lastTrack.playedAt.addingTimeInterval(max(30.0, lastTrack.durationSeconds))
                return (start, estimatedEnd, false, startStr, df.string(from: estimatedEnd))
            } else if stats.totalDurationSeconds > 0 {
                let estimatedEnd = start.addingTimeInterval(stats.totalDurationSeconds)
                return (start, estimatedEnd, false, startStr, df.string(from: estimatedEnd))
            } else {
                return (start, nil, false, startStr, "--")
            }
        } else {
            // Session en cours
            let tracks = sessionService.playedTracks
            let start: Date
            if let earliest = tracks.min(by: { $0.startTime < $1.startTime }) {
                start = earliest.startTime
            } else {
                start = sessionService.sessionStartTime
            }
            let startStr = df.string(from: start)
            
            if stats.isLiveSession {
                return (start, nil, true, startStr, "En direct")
            } else if let latest = tracks.max(by: { ($0.endTime ?? $0.playedAt) < ($1.endTime ?? $1.playedAt) }) {
                let end = latest.endTime ?? latest.playedAt.addingTimeInterval(max(30.0, latest.durationSeconds))
                return (start, end, false, startStr, df.string(from: end))
            } else if stats.totalDurationSeconds > 0 {
                let end = start.addingTimeInterval(stats.totalDurationSeconds)
                return (start, end, false, startStr, df.string(from: end))
            } else {
                return (start, nil, false, startStr, "--")
            }
        }
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 1. En-tête
                headerView
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 12) {
                        // 2. Carte Principale : Durée totale & Rythme du mix
                        heroDurationCard
                        
                        // 3. Grille des indicateurs clés (BPM, Clé dominante, Genre dominant, Transition rapide, Vitesse, Lectures)
                        metricsGridView
                        
                        // 4. Section Top Genres joués
                        topGenresSection
                        
                        // 5. Section Top Artistes joués
                        topArtistsSection
                        
                        // 6. Section Distribution Harmonique
                        if !stats.keyDistribution.isEmpty {
                            harmonicDistributionSection
                        }
                        
                        // 7. Section Évolution des styles au fil du set (Graphique temporel tout en bas)
                        if !effectiveTracks.isEmpty {
                            genreTimelineSection
                        }
                    }
                    .padding(14)
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // 7. Pied de page / Actions
                footerActionsView
            }
            
            // Notification Toast Flottante
            if let message = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: toastIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(toastColor)
                    
                    Text(message)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.96))
                        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.bottom, 54)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
            
            // Étape intermédiaire : Personnalisation de la soirée avant export
            if isShowingExportCustomization {
                exportCustomizationModal
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(200)
            }
        }
        .overlayPreferenceValue(SessionPickerAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if isSessionPickerOpen, let anchor {
                    let pickerFrame = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .onTapGesture { closeSessionPicker() }
                        
                        sessionPickerDropdown
                            .offset(
                                x: max(12, min(pickerFrame.minX, proxy.size.width - Self.sessionPickerDropdownWidth - 12)),
                                y: pickerFrame.maxY + 6
                            )
                            .transition(.opacity.combined(with: .offset(y: -6)))
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            }
        }
        .onChange(of: isSessionPickerOpen) { isOpen in
            SetRecapWindowController.shared.isSessionPickerOpen = isOpen
        }
        .onReceive(NotificationCenter.default.publisher(for: .recallDismissSessionPicker)) { _ in
            closeSessionPicker()
        }
        .frame(minWidth: 500, minHeight: 520)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12)
                
                // Dégradé d'ambiance
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.10),
                        Color.clear,
                        Color.accentCyan.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .ignoresSafeArea()
        .onAppear {
            loadPastSessions()
        }
        .onReceive(timer) { newTime in
            // OPTIMISATION CPU MAJEURE : Si aucun morceau n'est en cours de lecture,
            // on stoppe le rafraîchissement récurrent du timer (0% CPU)
            guard selectedPastSession == nil, stats.isLiveSession else { return }
            currentTime = newTime
        }
    }
    
    // MARK: - 1. En-tête
    
    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.3), Color.accentCyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.accentCyan)
            }
            .allowsHitTesting(false)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Statistiques du Mix")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(selectedPastSession == nil ? "SET RECAP" : "ARCHIVE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(selectedPastSession == nil ? Color.accentCyan : Color.purple)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(selectedPastSession == nil ? Color.accentCyan.opacity(0.18) : Color.purple.opacity(0.22))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 6) {
                    if isLoadingPastSession {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 6, height: 6)
                        
                        Text("Chargement des statistiques (\(selectedPastSession?.trackCount ?? 0) morceaux)…")
                            .font(.system(size: 10))
                            .foregroundColor(Color.accentCyan.opacity(0.85))
                    } else {
                        Circle()
                            .fill(selectedPastSession != nil ? Color.purple : (stats.totalTracksCount == 0 ? Color.white.opacity(0.3) : (stats.isLiveSession ? Color.green : Color.orange)))
                            .frame(width: 6, height: 6)
                        
                        Text(selectedPastSession != nil ? (selectedPastSession!.venue != nil ? "📍 \(selectedPastSession!.venue!) • \(selectedPastSession!.trackCount) morceaux" : "Session archivée (\(selectedPastSession!.trackCount) morceaux)") : (stats.totalTracksCount == 0 ? "Mix non démarré (en attente du 1er morceau)" : (stats.isLiveSession ? "Session en direct" : "En pause")))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }
            }
            .allowsHitTesting(false)
            
            sessionPickerButton
            
            Spacer(minLength: 8)
            
            HStack(spacing: 6) {
                // Bouton Partager rapide
                Button {
                    promptExport(for: .share)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isShareHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .frame(width: 26, height: 26)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isShareHovered ? Color.accentCyan : .white.opacity(0.85))
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isShareHovered = $0 }
                .focusable(false)
                .help("Partager le bilan visuel (AirDrop, Messages, Mail...)")
                
                // Bouton Photos rapide
                Button {
                    promptExport(for: .photos)
                } label: {
                    ZStack {
                        Circle()
                            .fill(isPhotosHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            .frame(width: 26, height: 26)
                        
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isPhotosHovered ? Color.accentCyan : .white.opacity(0.85))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isPhotosHovered = $0 }
                .focusable(false)
                .disabled(isExporting)
                .help("Enregistrer l'image dans l'application Photos")
                
                if let closeAction = onClose {
                    Button(action: closeAction) {
                        ZStack {
                            Circle()
                                .fill(isCloseHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(isCloseHovered ? .white : .white.opacity(0.75))
                        }
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isCloseHovered = hovering
                    }
                    .focusable(false)
                    .help("Fermer la fenêtre (Esc ou Cmd+W)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(WindowDragArea())
    }
    
    // MARK: - 1.1 Sélecteur de session (Direct / Passé)
    
    private static let sessionPickerDropdownWidth: CGFloat = 340
    
    private var sessionPickerButtonTitle: String {
        guard let past = selectedPastSession else { return "En direct" }
        let date = SessionPickerFormat.shortDate.string(from: past.startTime)
        if let venue = past.venue {
            return "\(venue) · \(date)"
        }
        return date
    }
    
    private var sessionPickerButton: some View {
        let isActive = isPickerHovered || isSessionPickerOpen
        let isPast = selectedPastSession != nil
        
        return Button {
            if isSessionPickerOpen {
                closeSessionPicker()
            } else {
                loadPastSessions()
                withAnimation(.easeOut(duration: 0.15)) {
                    isSessionPickerOpen = true
                }
            }
        } label: {
            HStack(spacing: 7) {
                if isLoadingPastSession {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else if isPast {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.accentCyan)
                } else {
                    Circle()
                        .fill(Color.accentGreen)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.accentGreen.opacity(0.8), radius: 3)
                }
                
                Text(sessionPickerButtonTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(isActive ? Color.accentCyan : .white.opacity(0.55))
                    .rotationEffect(.degrees(isSessionPickerOpen ? 180 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.white.opacity(0.13) : (isPast ? Color.accentCyan.opacity(0.16) : Color.white.opacity(0.07)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentCyan.opacity(0.9) : (isPast ? Color.accentCyan.opacity(0.45) : Color.white.opacity(0.16)), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isPickerHovered = $0 }
        .anchorPreference(key: SessionPickerAnchorKey.self, value: .bounds) { $0 }
        .help("Choisir la session à analyser (en direct ou une soirée Serato passée)")
    }
    
    private var filteredPastSessions: [SeratoDatabaseService.PastSessionItem] {
        let query = SessionPickerFormat.searchKey(sessionSearchText)
        guard !query.isEmpty else { return pastSessions }
        return pastSessions.filter { session in
            let haystack = "\(session.venue ?? "") \(SessionPickerFormat.longDate.string(from: session.startTime)) \(SessionPickerFormat.shortDate.string(from: session.startTime))"
            return SessionPickerFormat.searchKey(haystack).contains(query)
        }
    }
    
    private var pastSessionsByMonth: [(month: String, sessions: [SeratoDatabaseService.PastSessionItem])] {
        var groups: [(month: String, sessions: [SeratoDatabaseService.PastSessionItem])] = []
        for session in filteredPastSessions {
            let month = SessionPickerFormat.month.string(from: session.startTime).capitalized
            if groups.last?.month == month {
                groups[groups.count - 1].sessions.append(session)
            } else {
                groups.append((month: month, sessions: [session]))
            }
        }
        return groups
    }
    
    private var liveSessionSubtitle: String {
        let count = sessionService.playedTracks.count
        if count == 0 { return "En attente du 1er morceau" }
        return "Depuis \(SessionPickerFormat.time.string(from: sessionService.sessionStartTime)) · \(count) morceau\(count > 1 ? "x" : "") joué\(count > 1 ? "s" : "")"
    }
    
    private func pastSessionSubtitle(_ session: SeratoDatabaseService.PastSessionItem) -> String {
        var parts: [String] = []
        let start = SessionPickerFormat.time.string(from: session.startTime)
        if let end = session.endTime {
            parts.append("\(start) → \(SessionPickerFormat.time.string(from: end))")
            parts.append(SessionPickerFormat.duration(end.timeIntervalSince(session.startTime)))
        } else {
            parts.append(start)
        }
        parts.append("\(session.trackCount) morceau\(session.trackCount > 1 ? "x" : "")")
        return parts.joined(separator: " · ")
    }
    
    private var sessionPickerDropdown: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.45))
                
                TextField("Rechercher un lieu ou une date…", text: $sessionSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white)
                
                if !sessionSearchText.isEmpty {
                    Button {
                        sessionSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .padding(8)
            
            Divider().background(Color.white.opacity(0.08))
            
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    if sessionSearchText.isEmpty {
                        SessionPickerRow(
                            date: nil,
                            title: "Session en direct",
                            subtitle: liveSessionSubtitle,
                            isSelected: selectedPastSession == nil
                        ) {
                            closeSessionPicker()
                            if selectedPastSession != nil { returnToLive() }
                        }
                    }
                    
                    ForEach(pastSessionsByMonth, id: \.month) { group in
                        Section {
                            ForEach(group.sessions) { session in
                                SessionPickerRow(
                                    date: session.startTime,
                                    title: session.venue ?? SessionPickerFormat.longDate.string(from: session.startTime).capitalized,
                                    subtitle: pastSessionSubtitle(session),
                                    isSelected: selectedPastSession?.id == session.id
                                ) {
                                    closeSessionPicker()
                                    if selectedPastSession?.id != session.id { selectPastSession(session) }
                                }
                            }
                        } header: {
                            Text(group.month.uppercased())
                                .font(.system(size: 9, weight: .heavy))
                                .tracking(0.6)
                                .foregroundColor(.white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                                .background(Color(red: 0.11, green: 0.12, blue: 0.16))
                        }
                    }
                    
                    if pastSessions.isEmpty {
                        sessionPickerEmptyState(
                            icon: isLoadingPastSessionsList ? nil : "music.note.list",
                            text: isLoadingPastSessionsList ? "Chargement des sessions Serato…" : "Aucune session Serato éligible (min. 10 min & 10 titres)"
                        )
                    } else if filteredPastSessions.isEmpty {
                        sessionPickerEmptyState(icon: "magnifyingglass", text: "Aucune soirée ne correspond à « \(sessionSearchText) »")
                    }
                }
                .padding(6)
            }
            .frame(height: 330)
            
            Divider().background(Color.white.opacity(0.08))
            
            HStack(spacing: 6) {
                Text(pastSessions.isEmpty ? "Sessions de 10 min & 10 titres min." : "\(pastSessions.count) soirées · 10 min & 10 titres min.")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
                
                Button {
                    loadPastSessions(force: true)
                } label: {
                    HStack(spacing: 4) {
                        if isLoadingPastSessionsList {
                            ProgressView().scaleEffect(0.4).frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "arrow.clockwise").font(.system(size: 9, weight: .bold))
                        }
                        Text("Actualiser").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color.accentCyan)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .disabled(isLoadingPastSessionsList)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: Self.sessionPickerDropdownWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.16).opacity(0.98))
                .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func sessionPickerEmptyState(icon: String?, text: String) -> some View {
        VStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            } else {
                ProgressView().scaleEffect(0.7)
            }
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
    }
    
    private func closeSessionPicker() {
        guard isSessionPickerOpen else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            isSessionPickerOpen = false
        }
        sessionSearchText = ""
    }
    
    private func loadPastSessions(force: Bool = false) {
        if pastSessions.isEmpty, let cached = SeratoDatabaseService.shared.cachedPastSessionsImmediate, !cached.isEmpty {
            self.pastSessions = cached
        }
        
        guard !isLoadingPastSessionsList || force else { return }
        isLoadingPastSessionsList = true
        pastSessionsListTask?.cancel()
        
        let dbPath = settings.effectiveDatabasePath
        pastSessionsListTask = Task { @MainActor in
            let sessions = await Task.detached(priority: .userInitiated) {
                SeratoDatabaseService(databasePath: dbPath).fetchPastSessions(limit: 500, useCache: !force)
            }.value
            guard !Task.isCancelled else { return }
            self.pastSessions = sessions
            self.isLoadingPastSessionsList = false
        }
    }
    
    private func selectPastSession(_ session: SeratoDatabaseService.PastSessionItem) {
        pastSessionLoadTask?.cancel()
        selectedPastSession = session
        pastSessionStats = nil
        pastSessionTracks = []
        isLoadingPastSession = true
        exportSessionTitleInput = session.fullFrenchDate
        AppLogger.info("Chargement de la session passée : \(session.shortTitle) (ID: \(session.id), \(session.trackCount) morceaux)", category: .session)
        
        let targetId = session.id
        let sessionStartTime = session.startTime
        
        pastSessionLoadTask = Task { @MainActor in
            let (tracks, computedStats) = await Task.detached(priority: .userInitiated) { () -> ([SessionPlayedTrack], SetRecapStats) in
                let loadedTracks = SeratoDatabaseService.shared.fetchTracksForSession(sessionId: targetId)
                let calculatedStats = SetRecapStats.compute(from: loadedTracks, sessionStartTime: sessionStartTime)
                return (loadedTracks, calculatedStats)
            }.value
            
            guard !Task.isCancelled else { return }
            guard self.selectedPastSession?.id == targetId else { return }
            
            self.pastSessionTracks = tracks
            self.pastSessionStats = computedStats
            self.isLoadingPastSession = false
            AppLogger.info("Statistiques calculées avec succès pour la session passée ID \(targetId) : \(tracks.count) morceaux uniques, \(computedStats.totalPlaysCount) lectures totales", category: .session)
        }
    }
    
    private func returnToLive() {
        pastSessionLoadTask?.cancel()
        pastSessionLoadTask = nil
        isLoadingPastSession = false
        AppLogger.info("Retour à la session en cours (Live)", category: .session)
        selectedPastSession = nil
        pastSessionStats = nil
        pastSessionTracks = []
        exportSessionTitleInput = SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
    }
    
    // MARK: - 2. Hero Card Durée & Pacing
    
    private var heroDurationCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURÉE TOTALE DU SET")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                    
                    if isLoadingPastSession {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.65)
                                .frame(width: 14, height: 14)
                            Text("Calcul du set…")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Color.accentCyan)
                        }
                    } else {
                        Text(stats.totalTracksCount > 0 ? formatDuration(stats.totalDurationSeconds) : "00m 00s")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(stats.totalTracksCount > 0 ? .white : .white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MORCEAUX JOUÉS")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                    
                    let countToDisplay = stats.totalTracksCount > 0 ? stats.totalTracksCount : (selectedPastSession?.trackCount ?? 0)
                    
                    HStack(spacing: 4) {
                        Text("\(countToDisplay)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.accentCyan)
                        
                        Text("morceaux")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
            // Horaires du set : Heure de début et heure de fin
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.accentCyan)
                    
                    Text("Début :")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                    
                    Text(setTimeRange.formattedStart)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text("•")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.30))
                
                HStack(spacing: 5) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 9.5))
                        .foregroundColor(setTimeRange.isLive ? Color.green : Color.accentCyan.opacity(0.85))
                    
                    Text("Fin :")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                    
                    if setTimeRange.isLive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 5.5, height: 5.5)
                            Text("En direct")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color.green)
                        }
                    } else {
                        Text(setTimeRange.formattedEnd)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding(.top, 1)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            HStack {
                // Vitesse moyenne par morceau
                HStack(spacing: 5) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.accentCyan)
                    
                    Text("Temps moyen :")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    
                    if isLoadingPastSession {
                        Text("Analyse en cours…")
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color.accentCyan)
                    } else {
                        Text(stats.totalTracksCount > 0 ? formatMinutesSeconds(stats.averageTimePerTrackSeconds) : "--")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("/ track")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Badge de style de mix
                if isLoadingPastSession {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 9, height: 9)
                        Text("Analyse du rythme")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(Color.accentCyan)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentCyan.opacity(0.12))
                    .cornerRadius(5)
                } else {
                    mixPaceBadge
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private var mixPaceBadge: some View {
        let (label, icon, color) = mixPaceInfo(avgSec: stats.averageTimePerTrackSeconds, totalTracks: stats.totalTracksCount)
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 9.5, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.16))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(color.opacity(0.4), lineWidth: 0.8)
        )
    }
    
    private func mixPaceInfo(avgSec: Double, totalTracks: Int) -> (label: String, icon: String, color: Color) {
        guard totalTracks >= 2 else {
            return ("En attente", "hourglass", Color.white.opacity(0.5))
        }
        if avgSec < 45 {
            return ("⚡️ Quick Mix", "bolt.fill", Color.orange)
        } else if avgSec < 60 {
            // Dynamique : strictement moins de 1 minute par morceau
            return ("🔥 Dynamique", "flame.fill", Color.red)
        } else if avgSec < 120 {
            // 1m00 à 2m00 : mix cadencé / club actif
            return ("🎯 Rythmé", "music.note", Color(hex: "#FF9F43"))
        } else if avgSec < 240 {
            // 2m00 à 4m00 : transitions progressives / morceaux développés
            return ("🌊 Progressif", "waveform.path", Color.accentCyan)
        } else {
            // Plus de 4m00 : blends longs, house/techno étirée
            return ("🧘 Deep / Long Blend", "wind", Color.purple)
        }
    }
    
    // MARK: - 3. Grille des indicateurs
    
    private var metricsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            // Indicateur 1 : BPM Moyen
            metricCard(
                icon: "speedometer",
                iconColor: .orange,
                title: "BPM MOYEN DU SET",
                mainValue: isLoadingPastSession ? "..." : (stats.averageBpm > 0 ? String(format: "%.1f", stats.averageBpm) : "--"),
                unit: "BPM",
                subtext: isLoadingPastSession ? "Calcul du BPM moyen…" : (stats.minBpm > 0 ? "Plage : \(Int(stats.minBpm.rounded())) - \(Int(stats.maxBpm.rounded())) BPM" : "Aucun BPM détecté")
            )
            
            // Indicateur 2 : Tonalité Dominante
            metricCard(
                icon: "music.quarternote.3",
                iconColor: .purple,
                title: "TONALITÉ DOMINANTE",
                mainValue: isLoadingPastSession ? "..." : (stats.dominantKey ?? "--"),
                unit: "",
                subtext: isLoadingPastSession ? "Harmonisation en cours…" : (stats.dominantKey != nil ? "\(stats.dominantKeyCount) tracks (\(Int(stats.dominantKeyPercentage.rounded()))% du set)" : "Clés non analysées")
            )
            
            // Indicateur 3 : Genre le plus joué
            metricCard(
                icon: "headphones",
                iconColor: Color.accentCyan,
                title: "GENRE LE PLUS JOUÉ",
                mainValue: isLoadingPastSession ? "..." : (stats.mostPlayedGenre?.name ?? "--"),
                unit: "",
                subtext: isLoadingPastSession ? "Analyse des styles…" : (stats.mostPlayedGenre != nil ? "\(stats.mostPlayedGenre!.count) tracks (\(Int(stats.mostPlayedGenre!.percent.rounded()))% du set)" : "En attente des genres"),
                isTruncatedSubtext: true
            )
            
            // Indicateur 4 : Enchaînement le plus rapide
            metricCard(
                icon: "bolt.horizontal.fill",
                iconColor: .yellow,
                title: "TRANSITION LA PLUS RAPIDE",
                mainValue: isLoadingPastSession ? "..." : (stats.fastestTransition != nil ? formatMinutesSeconds(stats.fastestTransition!.elapsedSeconds) : "--"),
                unit: "",
                subtext: isLoadingPastSession ? "Calcul des transitions…" : (stats.fastestTransition != nil ? "\(stats.fastestTransition!.fromTrack) ➔ \(stats.fastestTransition!.toTrack)" : "2 morceaux requis"),
                isTruncatedSubtext: true
            )
            
            // Indicateur 5 : Cadence horaire (Tracks/heure)
            metricCard(
                icon: "hare.fill",
                iconColor: Color.accentCyan,
                title: "VITESSE DE MIX",
                mainValue: isLoadingPastSession ? "..." : (stats.totalTracksCount > 0 ? String(format: "%.1f", stats.tracksPerHour) : "--"),
                unit: "tracks/h",
                subtext: isLoadingPastSession ? "Cadence en cours de calcul…" : (stats.totalTracksCount > 0 ? "Cadence moyenne observée" : "En cours d'analyse...")
            )
            
            // Indicateur 6 : Morceaux joués
            metricCard(
                icon: "music.note",
                iconColor: Color.accentCyan,
                title: "MORCEAUX DU SET",
                mainValue: isLoadingPastSession ? "\(selectedPastSession?.trackCount ?? 0)" : (stats.totalTracksCount > 0 ? "\(stats.totalTracksCount)" : "--"),
                unit: "titres",
                subtext: isLoadingPastSession ? "Décompte en cours…" : (stats.totalTracksCount > 0 ? "\(stats.totalTracksCount) morceaux joués" : "En attente du mix")
            )
        }
    }
    
    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        mainValue: String,
        unit: String,
        subtext: String,
        isTruncatedSubtext: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.4)
                    .lineLimit(1)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mainValue)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            
            Text(subtext)
                .font(.system(size: 9.5))
                .foregroundColor(.white.opacity(0.65))
                .lineLimit(isTruncatedSubtext ? 1 : 2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - 4. Top Genres joués
    
    private var topGenresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 10))
                        .foregroundColor(Color.accentCyan)
                    
                    Text("GENRES LES PLUS JOUÉS")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                }
                
                Spacer()
                
                if let top1 = stats.mostPlayedGenre {
                    Text("Top 1 : \(top1.name)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.accentCyan)
                }
            }
            
            if isLoadingPastSession {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Calcul des genres musicaux du set…")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.accentCyan.opacity(0.85))
                }
                .padding(.vertical, 8)
            } else if stats.topGenres.isEmpty {
                Text("Genres musicaux en cours d'analyse.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(stats.topGenres.enumerated()), id: \.element.id) { index, gen in
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(index == 0 ? Color.accentCyan : .white.opacity(0.5))
                                .frame(width: 18, alignment: .leading)
                            
                            Text(gen.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Barre de progression visuelle
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 4)
                                    
                                    let ratio = max(0.0, min(1.0, gen.percent / 100.0))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index == 0 ? Color.accentCyan : Color.purple.opacity(0.85))
                                        .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(ratio))), height: 4)
                                }
                            }
                            .frame(width: 60, height: 4)
                            .clipped()
                            
                            HStack(spacing: 2) {
                                Text("\(gen.count)")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                
                                Text("track\(gen.count > 1 ? "s" : "")")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.025))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - 5. Top Artistes joués
    
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    
                    Text("ARTISTES LES PLUS JOUÉS")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                }
                
                Spacer()
                
                if let top1 = stats.mostPlayedArtist {
                    Text("Top 1 : \(top1.name)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(Color.accentCyan)
                }
            }
            
            if isLoadingPastSession {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Calcul des artistes du mix…")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.accentCyan.opacity(0.85))
                }
                .padding(.vertical, 8)
            } else if stats.topArtists.isEmpty {
                Text("Aucun artiste récurrent détecté dans la session.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(stats.topArtists.enumerated()), id: \.element.id) { index, art in
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(index == 0 ? .yellow : .white.opacity(0.5))
                                .frame(width: 18, alignment: .leading)
                            
                            Text(art.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Barre de progression visuelle
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(height: 4)
                                    
                                    let ratio = max(0.0, min(1.0, art.percent / 100.0))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index == 0 ? Color.accentCyan : Color.purple.opacity(0.8))
                                        .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(ratio))), height: 4)
                                }
                            }
                            .frame(width: 60, height: 4)
                            .clipped()
                            
                            HStack(spacing: 2) {
                                Text("\(art.count)")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                
                                Text("track\(art.count > 1 ? "s" : "")")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            .frame(width: 52, alignment: .trailing)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.025))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - 5. Distribution Harmonique
    
    private var harmonicDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "tuningfork")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                
                Text("DISTRIBUTION DES TONALITÉS")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.5)
            }
            
            HStack(spacing: 8) {
                ForEach(stats.keyDistribution, id: \.key) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(item.key)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(Color.accentCyan)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 3)
                                
                                let ratio = max(0.0, min(1.0, item.percent / 100.0))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.purple)
                                    .frame(width: max(2, min(geo.size.width, geo.size.width * CGFloat(ratio))), height: 3)
                            }
                        }
                        .frame(height: 3)
                        .clipped()
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
    
    // MARK: - 6b. Évolution des styles musicaux au fil du set
    
    private var genreTimelineSection: some View {
        GenreTimelineChartView(
            tracks: effectiveTracks,
            sessionStartTime: effectiveSessionStartTime,
            sessionEndTime: setTimeRange.end,
            isLive: setTimeRange.isLive
        )
    }
    
    // MARK: - 6. Actions Footer
    
    private var footerActionsView: some View {
        HStack(spacing: 8) {
            // 1. Bouton Enregistrer dans Photos (Action Principale 1)
            Button {
                promptExport(for: .photos)
            } label: {
                HStack(spacing: 6) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text("Dans Photos")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.accentCyan, Color.accentCyan.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .shadow(color: Color.accentCyan.opacity(0.3), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .disabled(isExporting)
            .help("Enregistrer l'image du récapitulatif directement dans Photos sur votre Mac")
            
            // 2. Bouton Partager (Action Principale 2)
            Button {
                promptExport(for: .share)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11, weight: .bold))
                    Text("Partager")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.85), Color.purple.opacity(0.70)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .help("Partager le bilan visuel (AirDrop, Messages, Mail...)")
            
            // 3. Menu d'options d'export
            Menu {
                Button {
                    promptExport(for: .copyImage)
                } label: {
                    Label("Copier l'image visuelle", systemImage: "doc.on.doc.fill")
                }
                
                Button {
                    promptExport(for: .saveFile)
                } label: {
                    Label("Enregistrer l'image PNG...", systemImage: "arrow.down.doc")
                }
                
                Button {
                    promptExport(for: .webLink)
                } label: {
                    Label("Partager un lien web sécurisé...", systemImage: "link.badge.plus")
                }
                
                Divider()
                
                Button {
                    copyStatsToClipboard()
                } label: {
                    Label("Copier les statistiques en texte", systemImage: "text.alignleft")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 11, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Options supplémentaires : copier l'image, enregistrer en PNG ou texte")
            
            Spacer()
            
            // 4. Tracklist
            if let openTracklist = onOpenTracklist {
                Button(action: openTracklist) {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 10.5))
                        Text("Tracklist")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Afficher la liste chronologique des morceaux")
            }
            
            // 5. Reset ou Revenir au direct
            if selectedPastSession != nil {
                Button {
                    returnToLive()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10))
                        Text("Revenir au direct")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(Color.accentCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.accentCyan.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentCyan.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Quitter la session archivée et revenir aux statistiques du mix en cours")
            } else {
                Button {
                    sessionService.resetSession()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("Reset")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(.red.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.10))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.red.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Remettre à zéro pour démarrer un nouveau mix")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Formatage & Actions
    
    private func formatDuration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%dh %02dm %02ds", h, m, s)
        } else {
            return String(format: "%02dm %02ds", m, s)
        }
    }
    
    private func formatMinutesSeconds(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%dm %02ds", m, s)
    }
    
    // MARK: - Actions d'Exportation Visuelle & Notification
    
    private func showToast(message: String, icon: String = "checkmark.circle.fill", color: Color = .green) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            toastMessage = message
            toastIcon = icon
            toastColor = color
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.25)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
    
    // MARK: - Étape intermédiaire de personnalisation
    
    private func promptExport(for target: ExportTarget) {
        if exportSessionTitleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let past = selectedPastSession {
                exportSessionTitleInput = past.fullFrenchDate
            } else {
                exportSessionTitleInput = SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
            }
        }
        pendingExportTarget = target
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isShowingExportCustomization = true
        }
    }
    
    private func performExportAction() {
        let defaultDate = selectedPastSession?.fullFrenchDate ?? SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
        let title = exportSessionTitleInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.isEmpty ? defaultDate : title
        
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingExportCustomization = false
        }
        
        switch pendingExportTarget {
        case .photos:
            exportToPhotos(with: resolvedTitle)
        case .share:
            shareRecap(with: resolvedTitle)
        case .copyImage:
            copyVisualRecapImage(with: resolvedTitle)
        case .saveFile:
            saveVisualRecapFile(with: resolvedTitle)
        case .webLink:
            shareViaWebLink(with: resolvedTitle)
        }
    }
    
    // MARK: - Exportations effectives
    
    private func exportToPhotos(with title: String) {
        guard !isExporting else { return }
        isExporting = true
        
        guard let image = SetRecapExportService.shared.generateImage(
            stats: stats,
            sessionStartTime: setTimeRange.start,
            sessionEndTime: setTimeRange.end,
            eventTitle: title,
            hideDuration: exportHideDuration,
            tracks: effectiveTracks
        ) else {
            isExporting = false
            showToast(message: "Échec de génération de l'image", icon: "xmark.circle.fill", color: .red)
            return
        }
        
        SetRecapExportService.shared.saveToPhotos(image: image) { success, error in
            isExporting = false
            if success {
                showToast(message: "Enregistré dans l'application Photos !", icon: "photo.fill.on.rectangle.fill", color: Color.accentCyan)
            } else {
                showToast(message: error ?? "Impossible d'enregistrer dans Photos", icon: "exclamationmark.triangle.fill", color: .orange)
            }
        }
    }
    
    private func shareRecap(with title: String) {
        guard let image = SetRecapExportService.shared.generateImage(
            stats: stats,
            sessionStartTime: setTimeRange.start,
            sessionEndTime: setTimeRange.end,
            eventTitle: title,
            hideDuration: exportHideDuration,
            tracks: effectiveTracks
        ) else {
            showToast(message: "Échec de génération de l'image", icon: "xmark.circle.fill", color: .red)
            return
        }
        
        SetRecapExportService.shared.shareImage(image: image, window: NSApp.keyWindow)
    }
    
    private func copyVisualRecapImage(with title: String) {
        guard let image = SetRecapExportService.shared.generateImage(
            stats: stats,
            sessionStartTime: setTimeRange.start,
            sessionEndTime: setTimeRange.end,
            eventTitle: title,
            hideDuration: exportHideDuration,
            tracks: effectiveTracks
        ) else {
            showToast(message: "Échec de génération de l'image", icon: "xmark.circle.fill", color: .red)
            return
        }
        
        if SetRecapExportService.shared.copyImageToClipboard(image: image) {
            showToast(message: "Image visuelle copiée !", icon: "doc.on.doc.fill", color: Color.accentCyan)
        } else {
            showToast(message: "Erreur lors de la copie de l'image", icon: "xmark.circle.fill", color: .red)
        }
    }
    
    private func saveVisualRecapFile(with title: String) {
        guard let image = SetRecapExportService.shared.generateImage(
            stats: stats,
            sessionStartTime: setTimeRange.start,
            sessionEndTime: setTimeRange.end,
            eventTitle: title,
            hideDuration: exportHideDuration,
            tracks: effectiveTracks
        ) else {
            showToast(message: "Échec de génération de l'image", icon: "xmark.circle.fill", color: .red)
            return
        }
        
        SetRecapExportService.shared.saveImageToFile(image: image, window: NSApp.keyWindow) { success in
            if success {
                showToast(message: "Image PNG enregistrée sur votre Mac !", icon: "arrow.down.doc.fill", color: Color.accentCyan)
            }
        }
    }
    
    private func shareViaWebLink(with title: String) {
        guard !isPublishingWeb else { return }
        isPublishingWeb = true
        showToast(message: "Génération du lien web sécurisé...", icon: "arrow.triangle.2.circlepath", color: Color.accentCyan)
        
        SetRecapShareWebService.shared.publishSetRecap(
            stats: stats,
            sessionStartTime: setTimeRange.start,
            sessionEndTime: setTimeRange.end,
            sessionTitle: title,
            hideDuration: exportHideDuration
        ) { result in
            isPublishingWeb = false
            switch result {
            case .success(let url):
                showToast(message: "Lien sécurisé copié dans le presse-papier !", icon: "link.circle.fill", color: Color.accentCyan)
                NSWorkspace.shared.open(url)
            case .failure(let error):
                showToast(message: error.localizedDescription, icon: "exclamationmark.triangle.fill", color: .orange)
            }
        }
    }
    
    // MARK: - Modale d'Étape Intermédiaire
    
    private var exportCustomizationModal: some View {
        ZStack {
            // Fond noir dépoli cliquable pour fermer
            Color.black.opacity(0.65)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isShowingExportCustomization = false
                    }
                }
            
            // Boîte modale
            VStack(alignment: .leading, spacing: 14) {
                // En-tête
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.4), Color.accentCyan.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.accentCyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quelle soirée est concernée ?")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Ce titre s'affichera en haut à gauche du bilan visuel.")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isShowingExportCustomization = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // Champ de saisie
                VStack(alignment: .leading, spacing: 6) {
                    Text("TITRE OU DATE DE L'ÉVÉNEMENT")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.5)
                    
                    TextField("Ex : Samedi 17 octobre 2026", text: $exportSessionTitleInput)
                        .focused($isTitleFieldFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentCyan.opacity(0.4), lineWidth: 1)
                        )
                        .onSubmit {
                            performExportAction()
                        }
                    
                    // Suggestions de date rapides
                    HStack(spacing: 6) {
                        let fullDate = selectedPastSession?.fullFrenchDate ?? SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
                        
                        Button {
                            exportSessionTitleInput = fullDate
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 8))
                                Text(fullDate)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(exportSessionTitleInput == fullDate ? Color.accentCyan : .white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(exportSessionTitleInput == fullDate ? Color.accentCyan.opacity(0.15) : Color.white.opacity(0.05))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(exportSessionTitleInput == fullDate ? Color.accentCyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        let soireePreset = "Soirée du \(formattedShortFrenchDate(effectiveSessionStartTime))"
                        Button {
                            exportSessionTitleInput = soireePreset
                        } label: {
                            Text(soireePreset)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(exportSessionTitleInput == soireePreset ? Color.accentCyan : .white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(exportSessionTitleInput == soireePreset ? Color.accentCyan.opacity(0.15) : Color.white.opacity(0.05))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(exportSessionTitleInput == soireePreset ? Color.accentCyan.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
                
                // Aperçu visuel en direct
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.accentCyan)
                    
                    Text("Aperçu en-tête :")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                    
                    let defaultDate = selectedPastSession?.fullFrenchDate ?? SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
                    Text(exportSessionTitleInput.isEmpty ? defaultDate : exportSessionTitleInput)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.035))
                .cornerRadius(6)
                
                // Option : Masquer la durée du set
                Button {
                    exportHideDuration.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: exportHideDuration ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(exportHideDuration ? Color.accentCyan : .white.opacity(0.45))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Masquer la durée et les horaires du set")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if exportHideDuration {
                                    Text("CONFIDENTIEL")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(Color.accentCyan)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.accentCyan.opacity(0.18))
                                        .cornerRadius(4)
                                }
                            }
                            
                            Text("Masque le temps total et les heures de début/fin sur l'image et sur le web (met en avant le volume de morceaux).")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        
                        Spacer()
                        
                        Image(systemName: exportHideDuration ? "eye.slash.fill" : "clock")
                            .font(.system(size: 12))
                            .foregroundColor(exportHideDuration ? Color.accentCyan : .white.opacity(0.3))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(exportHideDuration ? Color.accentCyan.opacity(0.08) : Color.white.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(exportHideDuration ? Color.accentCyan.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // Boutons d'actions
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isShowingExportCustomization = false
                        }
                    } label: {
                        Text("Annuler")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if pendingExportTarget == .photos {
                        Button {
                            pendingExportTarget = .webLink
                            performExportAction()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "link")
                                    .font(.system(size: 10))
                                Text("Lien web")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Partager sous la forme d'une page internet avec un lien sécurisé")
                    }
                    
                    Button {
                        performExportAction()
                    } label: {
                        HStack(spacing: 6) {
                            if isExporting || isPublishingWeb {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: pendingExportTarget.actionIcon)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            
                            Text(pendingExportTarget.actionButtonTitle)
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundColor(pendingExportTarget == .photos ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: pendingExportTarget == .photos
                                    ? [Color.accentCyan, Color.accentCyan.opacity(0.85)]
                                    : [Color.purple.opacity(0.9), Color.purple.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: (pendingExportTarget == .photos ? Color.accentCyan : Color.purple).opacity(0.35), radius: 6, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isExporting || isPublishingWeb)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(width: 440)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.10, green: 0.11, blue: 0.15).opacity(0.98))
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.accentCyan.opacity(0.55),
                                Color.purple.opacity(0.35),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.75), radius: 24, x: 0, y: 12)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTitleFieldFocused = true
                }
            }
        }
    }
    
    private func formattedShortFrenchDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func copyStatsToClipboard() {
        var lines: [String] = []
        lines.append("📊 BILAN DU MIX • RECALL")
        lines.append("────────────────────────")
        if !exportHideDuration {
            lines.append("⏱ Durée totale : \(formatDuration(stats.totalDurationSeconds))")
        }
        lines.append("🎵 Morceaux joués : \(stats.totalTracksCount) tracks")
        if stats.totalTracksCount > 0 && !exportHideDuration {
            let pace = mixPaceInfo(avgSec: stats.averageTimePerTrackSeconds, totalTracks: stats.totalTracksCount).label
            lines.append("🎚 Vitesse de mix : \(formatMinutesSeconds(stats.averageTimePerTrackSeconds)) / track (\(String(format: "%.1f", stats.tracksPerHour)) tracks/h • \(pace))")
        } else if exportHideDuration {
            lines.append("🎚 Tonalités explorées : \(stats.keyDistribution.count)")
        }
        if stats.averageBpm > 0 {
            lines.append("⚡️ BPM moyen : \(String(format: "%.1f", stats.averageBpm)) BPM (\(Int(stats.minBpm.rounded())) - \(Int(stats.maxBpm.rounded())) BPM)")
        }
        if let dom = stats.dominantKey {
            lines.append("🎹 Tonalité dominante : \(dom) (\(stats.dominantKeyCount) tracks - \(Int(stats.dominantKeyPercentage.rounded()))%)")
        }
        if let domGenre = stats.mostPlayedGenre {
            lines.append("🎧 Genre le plus joué : \(domGenre.name) (\(domGenre.count) tracks - \(Int(domGenre.percent.rounded()))%)")
        }
        if !stats.topGenres.isEmpty {
            let genStr = stats.topGenres.map { "\($0.name) (\($0.count))" }.joined(separator: ", ")
            lines.append("🎷 Top Genres : \(genStr)")
        }
        if let fast = stats.fastestTransition {
            lines.append("🚀 Enchaînement le plus rapide : \(formatMinutesSeconds(fast.elapsedSeconds)) (\(fast.fromTrack) ➔ \(fast.toTrack))")
        }
        if !stats.topArtists.isEmpty {
            let artStr = stats.topArtists.map { "\($0.name) (\($0.count))" }.joined(separator: ", ")
            lines.append("👑 Top Artistes : \(artStr)")
        }
        lines.append("────────────────────────")
        lines.append("⚡️ Compagnon DJ intelligent Recall (https://revrmusic.github.io/recall/)")
        
        let text = lines.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        showToast(message: "Statistiques en texte copiées !", icon: "doc.on.doc.fill", color: Color.accentCyan)
    }
}

// MARK: - Sélecteur de session : position, formats et lignes

private struct SessionPickerAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

private enum SessionPickerFormat {
    static let time = makeFormatter("HH'h'mm")
    static let shortDate = makeFormatter("d MMM yyyy")
    static let longDate = makeFormatter("EEEE d MMMM")
    static let month = makeFormatter("LLLL yyyy")
    static let weekday = makeFormatter("EEE")
    static let day = makeFormatter("d")
    
    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = format
        return formatter
    }
    
    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        return String(format: "%dh%02d", hours, minutes)
    }
    
    static func searchKey(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SessionPickerRow: View {
    /// `nil` = session en direct
    let date: Date?
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                dateTile
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.accentCyan)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentCyan.opacity(0.14) : (isHovered ? Color.white.opacity(0.07) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
    }
    
    private var dateTile: some View {
        let isLive = date == nil
        return ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(isLive ? Color.accentGreen.opacity(0.15) : Color.white.opacity(0.06))
            RoundedRectangle(cornerRadius: 7)
                .stroke(isLive ? Color.accentGreen.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
            
            if let date {
                VStack(spacing: 0) {
                    Text(SessionPickerFormat.weekday.string(from: date).replacingOccurrences(of: ".", with: "").uppercased())
                        .font(.system(size: 7.5, weight: .heavy))
                        .foregroundColor(Color.accentCyan.opacity(0.85))
                    Text(SessionPickerFormat.day.string(from: date))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.accentGreen)
            }
        }
        .frame(width: 34, height: 34)
    }
}

/// Zone vide de l'en-tête : déplace la fenêtre comme une barre de titre macOS,
/// sans voler les clics des boutons posés par-dessus.
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
    
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
