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
        
        // Calcul temporel précis
        let earliestPlayed = tracks.map { $0.playedAt }.min() ?? sessionStartTime
        let now = Date()
        let latestPlayed = tracks.map { $0.playedAt }.max() ?? now
        let isLive = now.timeIntervalSince(latestPlayed) < 20 * 60 // Actif si dernier morceau dans les 20 min
        
        let totalDuration: Double
        if isLive {
            let startPoint = min(sessionStartTime, earliestPlayed)
            totalDuration = max(60.0, now.timeIntervalSince(startPoint))
        } else {
            // Session terminée ou en pause : durée réelle couverte par les morceaux du mix
            let lastTrack = tracks.max(by: { $0.playedAt < $1.playedAt })
            let lastTrackDuration = (lastTrack?.durationSeconds ?? 0) > 0 ? (lastTrack?.durationSeconds ?? 180.0) : 180.0
            let effectiveEnd = latestPlayed.addingTimeInterval(lastTrackDuration)
            totalDuration = max(60.0, effectiveEnd.timeIntervalSince(earliestPlayed))
        }
        
        let avgTimePerTrack = totalDuration / Double(count)
        let tracksPerHour = (Double(count) / totalDuration) * 3600.0
        
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
                  art.lowercased() != "unknown" else { continue }
            artistCounts[art, default: 0] += 1
            if let existing = artistLatestDate[art] {
                artistLatestDate[art] = max(existing, tr.playedAt)
            } else {
                artistLatestDate[art] = tr.playedAt
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
            let g = tr.genre.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !g.isEmpty,
                  g.lowercased() != "unknown",
                  g.lowercased() != "genre inconnu",
                  g.lowercased() != "inconnu",
                  g.lowercased() != "other",
                  g.lowercased() != "autre" else { continue }
            let formatted = g.capitalized
            genreCounts[formatted, default: 0] += 1
            if let existing = genreLatestDate[formatted] {
                genreLatestDate[formatted] = max(existing, tr.playedAt)
            } else {
                genreLatestDate[formatted] = tr.playedAt
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
    @State private var showCopyToast: Bool = false
    @State private var initialWindowOrigin: CGPoint? = nil
    
    public var onClose: (() -> Void)?
    public var onOpenTracklist: (() -> Void)?
    
    @State private var currentStats: SetRecapStats? = nil
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    public init(onClose: (() -> Void)? = nil, onOpenTracklist: (() -> Void)? = nil) {
        self.onClose = onClose
        self.onOpenTracklist = onOpenTracklist
    }
    
    private var stats: SetRecapStats {
        if let s = currentStats {
            return s
        }
        return SetRecapStats.compute(
            from: sessionService.playedTracks,
            sessionStartTime: sessionService.sessionStartTime
        )
    }
    
    public var body: some View {
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
            
            // 6. Pied de page / Actions
            footerActionsView
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
        }
        .onReceive(timer) { newTime in
            currentTime = newTime
            currentStats = SetRecapStats.compute(
                from: sessionService.playedTracks,
                sessionStartTime: sessionService.sessionStartTime
            )
        }
        .onReceive(sessionService.$playedTracks) { tracks in
            currentStats = SetRecapStats.compute(
                from: tracks,
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
                    
                    Text("SET RECAP")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.accentCyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.accentCyan.opacity(0.18))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(stats.totalTracksCount == 0 ? Color.white.opacity(0.3) : (stats.isLiveSession ? Color.green : Color.orange))
                        .frame(width: 6, height: 6)
                    
                    Text(stats.totalTracksCount == 0 ? "Mix non démarré (en attente du 1er morceau)" : (stats.isLiveSession ? "Session en direct" : "Session enregistrée"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            
            Spacer()
            
            // Poignée visuelle de déplacement
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 8.5, weight: .bold))
                Text("Déplacer")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.35))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .help("Cliquer et glisser pour déplacer la fenêtre")
            
            Spacer()
            
            if let closeAction = onClose {
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
                .help("Fermer la fenêtre (Esc ou Cmd+W)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    guard let window = NSApp.windows.first(where: { $0.title == "Statistiques du Mix Recall" && $0.isVisible }) ?? SetRecapWindowController.shared.window else { return }
                    if initialWindowOrigin == nil {
                        initialWindowOrigin = window.frame.origin
                    }
                    if let start = initialWindowOrigin {
                        let newX = start.x + gesture.translation.width
                        let newY = start.y - gesture.translation.height
                        window.setFrameOrigin(CGPoint(x: newX, y: newY))
                    }
                }
                .onEnded { _ in
                    initialWindowOrigin = nil
                }
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
        let avgSec = stats.averageTimePerTrackSeconds
        let (label, icon, color): (String, String, Color) = {
            guard stats.totalTracksCount >= 2 else {
                return ("En attente", "hourglass", Color.white.opacity(0.5))
            }
            if avgSec < 90 {
                return ("⚡️ Quick Mix", "bolt.fill", Color.orange)
            } else if avgSec < 180 {
                return ("🔥 Dynamique", "flame.fill", Color.red)
            } else if avgSec < 300 {
                return ("🌊 Progressif", "waveform.path", Color.accentCyan)
            } else {
                return ("🧘 Deep / Long Blend", "wind", Color.purple)
            }
        }()
        
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
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index == 0 ? Color.accentCyan : Color.purple.opacity(0.85))
                                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, gen.percent / 100.0) * 2.0)), height: 4)
                                }
                            }
                            .frame(width: 60, height: 4)
                            
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
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index == 0 ? Color.accentCyan : Color.purple.opacity(0.8))
                                        .frame(width: max(4, geo.size.width * CGFloat(min(1.0, art.percent / 100.0) * 2.5)), height: 4)
                                }
                            }
                            .frame(width: 60, height: 4)
                            
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
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.purple)
                                    .frame(width: max(2, geo.size.width * CGFloat(item.percent / 100.0)), height: 3)
                            }
                        }
                        .frame(height: 3)
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
            // Copier le bilan
            Button {
                copyStatsToClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showCopyToast ? "checkmark" : "doc.on.doc.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(showCopyToast ? "Bilan copié !" : "Copier les statistiques")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: showCopyToast ? [Color.green, Color.green.opacity(0.85)] : [Color.accentCyan, Color.accentCyan.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .shadow(color: Color.accentCyan.opacity(0.3), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            
            // Ouvrir la tracklist
            if let openTracklist = onOpenTracklist {
                Button(action: openTracklist) {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 10.5))
                        Text("Générer Tracklist")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            // Reset Session
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
    
    private func copyStatsToClipboard() {
        var lines: [String] = []
        lines.append("📊 BILAN DU MIX • RECALL")
        lines.append("────────────────────────")
        lines.append("⏱ Durée totale : \(formatDuration(stats.totalDurationSeconds))")
        lines.append("🎵 Morceaux joués : \(stats.totalTracksCount) tracks")
        if stats.totalTracksCount > 0 {
            lines.append("🎚 Vitesse de mix : \(formatMinutesSeconds(stats.averageTimePerTrackSeconds)) / track (\(String(format: "%.1f", stats.tracksPerHour)) tracks/h)")
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
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
}
