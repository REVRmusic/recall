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
    
    public static func compute(from tracks: [SessionPlayedTrack], sessionStartTime: Date) -> SetRecapStats {
        let count = tracks.count
        guard count > 0 else {
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
                isLiveSession: false
            )
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
    
    @State private var currentStats: SetRecapStats? = nil
    @State private var pastSessions: [SeratoDatabaseService.PastSessionItem] = []
    @State private var selectedPastSession: SeratoDatabaseService.PastSessionItem? = nil
    @State private var pastSessionTracks: [SessionPlayedTrack] = []
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(onClose: (() -> Void)? = nil, onOpenTracklist: (() -> Void)? = nil) {
        self.onClose = onClose
        self.onOpenTracklist = onOpenTracklist
    }
    
    private var stats: SetRecapStats {
        if let s = currentStats {
            return s
        }
        if let past = selectedPastSession {
            return SetRecapStats.compute(
                from: pastSessionTracks,
                sessionStartTime: past.startTime
            )
        }
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
        .frame(minWidth: 540, minHeight: 620)
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
        .onAppear {
            currentStats = SetRecapStats.compute(
                from: sessionService.playedTracks,
                sessionStartTime: sessionService.sessionStartTime
            )
            loadPastSessions()
        }
        .onReceive(timer) { newTime in
            // OPTIMISATION CPU MAJEURE : Si aucun morceau n'est en cours de lecture,
            // on stoppe le rafraîchissement récurrent du timer (0% CPU)
            guard selectedPastSession == nil, stats.isLiveSession else { return }
            currentTime = newTime
            currentStats = SetRecapStats.compute(
                from: sessionService.playedTracks,
                sessionStartTime: sessionService.sessionStartTime
            )
        }
        .onReceive(sessionService.$playedTracks) { tracks in
            guard selectedPastSession == nil else { return }
            currentStats = SetRecapStats.compute(
                from: tracks,
                sessionStartTime: sessionService.sessionStartTime
            )
        }
        .onReceive(sessionService.$isCurrentlyPlaying) { _ in
            guard selectedPastSession == nil else { return }
            currentStats = SetRecapStats.compute(
                from: sessionService.playedTracks,
                sessionStartTime: sessionService.sessionStartTime
            )
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
                    Circle()
                        .fill(selectedPastSession != nil ? Color.purple : (stats.totalTracksCount == 0 ? Color.white.opacity(0.3) : (stats.isLiveSession ? Color.green : Color.orange)))
                        .frame(width: 6, height: 6)
                    
                    Text(selectedPastSession != nil ? (selectedPastSession!.venue != nil ? "📍 \(selectedPastSession!.venue!) • \(selectedPastSession!.trackCount) morceaux" : "Session archivée (\(selectedPastSession!.trackCount) morceaux)") : (stats.totalTracksCount == 0 ? "Mix non démarré (en attente du 1er morceau)" : (stats.isLiveSession ? "Session en direct" : "En pause")))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            
            sessionPickerMenu
            
            Spacer()
            
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
    }
    
    // MARK: - 1.1 Sélecteur de session (Direct / Passé)
    
    private var sessionPickerMenu: some View {
        Menu {
            Button {
                returnToLive()
            } label: {
                if selectedPastSession == nil {
                    Label("Session en direct (Actuelle)", systemImage: "checkmark")
                } else {
                    Text("🟢 Session en direct (Actuelle)")
                }
            }
            
            if !pastSessions.isEmpty {
                Divider()
                
                ForEach(pastSessions) { session in
                    Button {
                        selectPastSession(session)
                    } label: {
                        if selectedPastSession?.id == session.id {
                            Label(session.formattedTitle, systemImage: "checkmark")
                        } else {
                            Text(session.formattedTitle)
                        }
                    }
                }
            } else {
                Divider()
                Text("Chargement des sessions Serato...")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedPastSession == nil ? "record.circle" : "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(selectedPastSession == nil ? .green : Color.accentCyan)
                
                Text(selectedPastSession == nil ? "Session en cours" : selectedPastSession!.shortTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isPickerHovered ? Color.accentCyan : .white.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isPickerHovered ? Color.white.opacity(0.14) : (selectedPastSession == nil ? Color.white.opacity(0.08) : Color.accentCyan.opacity(0.18)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isPickerHovered ? Color.accentCyan : (selectedPastSession == nil ? Color.white.opacity(0.18) : Color.accentCyan.opacity(0.45)), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { isPickerHovered = $0 }
        .help("Choisir la session à analyser (session en direct ou sessions Serato passées)")
    }
    
    private func loadPastSessions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let sessions = SeratoDatabaseService.shared.fetchPastSessions(limit: 30)
            DispatchQueue.main.async {
                self.pastSessions = sessions
            }
        }
    }
    
    private func selectPastSession(_ session: SeratoDatabaseService.PastSessionItem) {
        selectedPastSession = session
        exportSessionTitleInput = session.fullFrenchDate
        DispatchQueue.global(qos: .userInitiated).async {
            let tracks = SeratoDatabaseService.shared.fetchTracksForSession(sessionId: session.id)
            let newStats = SetRecapStats.compute(from: tracks, sessionStartTime: session.startTime)
            DispatchQueue.main.async {
                self.pastSessionTracks = tracks
                self.currentStats = newStats
            }
        }
    }
    
    private func returnToLive() {
        selectedPastSession = nil
        pastSessionTracks = []
        exportSessionTitleInput = SetRecapExportCardView.formatFullDayDate(sessionService.sessionStartTime)
        currentStats = SetRecapStats.compute(
            from: sessionService.playedTracks,
            sessionStartTime: sessionService.sessionStartTime
        )
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
                    
                    Text(stats.totalTracksCount > 0 ? formatDuration(stats.totalDurationSeconds) : "00m 00s")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(stats.totalTracksCount > 0 ? .white : .white.opacity(0.4))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MORCEAUX JOUÉS")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                    
                    HStack(spacing: 4) {
                        Text("\(stats.totalTracksCount)")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(Color.accentCyan)
                        
                        Text("tracks")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            
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
                    
                    Text(stats.totalTracksCount > 0 ? formatMinutesSeconds(stats.averageTimePerTrackSeconds) : "--")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("/ track")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Badge de style de mix
                mixPaceBadge
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
                mainValue: stats.averageBpm > 0 ? String(format: "%.1f", stats.averageBpm) : "--",
                unit: "BPM",
                subtext: stats.minBpm > 0 ? "Plage : \(Int(stats.minBpm.rounded())) - \(Int(stats.maxBpm.rounded())) BPM" : "Aucun BPM détecté"
            )
            
            // Indicateur 2 : Tonalité Dominante
            metricCard(
                icon: "music.quarternote.3",
                iconColor: .purple,
                title: "TONALITÉ DOMINANTE",
                mainValue: stats.dominantKey ?? "--",
                unit: "",
                subtext: stats.dominantKey != nil ? "\(stats.dominantKeyCount) tracks (\(Int(stats.dominantKeyPercentage.rounded()))% du set)" : "Clés non analysées"
            )
            
            // Indicateur 3 : Genre le plus joué
            metricCard(
                icon: "headphones",
                iconColor: Color.accentCyan,
                title: "GENRE LE PLUS JOUÉ",
                mainValue: stats.mostPlayedGenre?.name ?? "--",
                unit: "",
                subtext: stats.mostPlayedGenre != nil ? "\(stats.mostPlayedGenre!.count) tracks (\(Int(stats.mostPlayedGenre!.percent.rounded()))% du set)" : "En attente des genres",
                isTruncatedSubtext: true
            )
            
            // Indicateur 4 : Enchaînement le plus rapide
            metricCard(
                icon: "bolt.horizontal.fill",
                iconColor: .yellow,
                title: "TRANSITION LA PLUS RAPIDE",
                mainValue: stats.fastestTransition != nil ? formatMinutesSeconds(stats.fastestTransition!.elapsedSeconds) : "--",
                unit: "",
                subtext: stats.fastestTransition != nil ? "\(stats.fastestTransition!.fromTrack) ➔ \(stats.fastestTransition!.toTrack)" : "2 morceaux requis",
                isTruncatedSubtext: true
            )
            
            // Indicateur 5 : Cadence horaire (Tracks/heure)
            metricCard(
                icon: "hare.fill",
                iconColor: Color.accentCyan,
                title: "VITESSE DE MIX",
                mainValue: stats.totalTracksCount > 0 ? String(format: "%.1f", stats.tracksPerHour) : "--",
                unit: "tracks/h",
                subtext: stats.totalTracksCount > 0 ? "Cadence moyenne observée" : "En cours d'analyse..."
            )
            
            // Indicateur 6 : Total Lectures
            metricCard(
                icon: "music.note.list",
                iconColor: .green,
                title: "LECTURES TOTALES",
                mainValue: stats.totalPlaysCount > 0 ? "\(stats.totalPlaysCount)" : (stats.totalTracksCount > 0 ? "\(stats.totalTracksCount)" : "--"),
                unit: "plays",
                subtext: stats.totalTracksCount > 0 ? "\(stats.totalTracksCount) morceaux uniques" : "En attente du mix"
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
            
            if stats.topGenres.isEmpty {
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
            
            if stats.topArtists.isEmpty {
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
            sessionStartTime: effectiveSessionStartTime,
            eventTitle: title,
            hideDuration: exportHideDuration
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
            sessionStartTime: effectiveSessionStartTime,
            eventTitle: title,
            hideDuration: exportHideDuration
        ) else {
            showToast(message: "Échec de génération de l'image", icon: "xmark.circle.fill", color: .red)
            return
        }
        
        SetRecapExportService.shared.shareImage(image: image, window: NSApp.keyWindow)
    }
    
    private func copyVisualRecapImage(with title: String) {
        guard let image = SetRecapExportService.shared.generateImage(
            stats: stats,
            sessionStartTime: effectiveSessionStartTime,
            eventTitle: title,
            hideDuration: exportHideDuration
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
            sessionStartTime: effectiveSessionStartTime,
            eventTitle: title,
            hideDuration: exportHideDuration
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
            sessionStartTime: effectiveSessionStartTime,
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
                                Text("Masquer la durée du set")
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
                            
                            Text("Masque le temps total sur l'image et sur le web (met en avant le volume de morceaux).")
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
            lines.append("🎧 Lectures totales : \(stats.totalPlaysCount > 0 ? stats.totalPlaysCount : stats.totalTracksCount) passages")
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
