import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Formats d'exportation disponibles pour le générateur de tracklist
public enum TracklistFormat: String, CaseIterable, Identifiable {
    case youtube = "YouTube / Sommaire"
    case tracklist1001 = "1001Tracklists"
    case social = "Réseaux (Insta / TikTok)"
    case liveTimestamp = "Horodaté Réel"
    case detailedDJ = "Détaillé DJ (BPM & Clé)"
    case m3u8 = "Playlist M3U8"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .tracklist1001: return "list.number"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .liveTimestamp: return "clock.fill"
        case .detailedDJ: return "waveform.path.ecg"
        case .m3u8: return "music.note.list"
        }
    }
    
    public var sample: String {
        switch self {
        case .youtube: return "00:00 Artiste - Titre"
        case .tracklist1001: return "01. [00:00] Artiste - Titre"
        case .social: return "01. Artiste - Titre"
        case .liveTimestamp: return "[22:15] Artiste - Titre"
        case .detailedDJ: return "01. [00:00] Artiste - Titre [126 BPM • 8A]"
        case .m3u8: return "#EXTM3U (Fichier playlist)"
        }
    }
}

/// Source des données pour la tracklist
public enum TracklistSource: String, CaseIterable, Identifiable {
    case session = "Session en cours"
    case toPlay = "Ma Sélec (À jouer)"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .session: return "clock.arrow.circlepath"
        case .toPlay: return "text.badge.plus"
        }
    }
}

/// Structure unifiée pour la génération de tracklist
private struct UnifiedTrackItem: Identifiable {
    let id: String
    let title: String
    let artist: String
    let bpm: Double
    let rawKey: String
    let camelotKey: CamelotKey?
    let playedAt: Date?
    let durationSeconds: Double
    let filePath: String?
}

/// Vue principale du Générateur de Tracklist de Recall
public struct TracklistGeneratorView: View {
    @ObservedObject private var sessionService = SessionHistoryService.shared
    @ObservedObject private var toPlayService = ToPlayService.shared
    @ObservedObject private var settings = UserSettings.shared
    
    @State private var selectedSource: TracklistSource = .session
    @State private var selectedFormat: TracklistFormat = .youtube
    
    // Options modulables
    @State private var includeTimestamps: Bool = true
    @State private var includeNumbering: Bool = false
    @State private var includeBpmKey: Bool = false
    @State private var artistFirst: Bool = true
    @State private var chronologicalOrder: Bool = true
    
    // Contenu éditable
    @State private var currentText: String = ""
    @State private var isManuallyEdited: Bool = false
    @State private var showCopyToast: Bool = false
    
    public var onClose: (() -> Void)?
    
    public init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. En-tête moderne & épuré
            headerView
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            VStack(spacing: 12) {
                // 2. Sélecteur de Source (Session vs Sélec)
                sourceSelectorView
                
                // 3. Sélecteur de Formats
                formatSelectorView
                
                // 4. Barre d'options modulables
                optionsBarView
                
                // 5. Barre de résumé / Statistiques
                summaryStatsBarView
                
                // 6. Zone d'édition / Prévisualisation
                editorView
                
                // 7. Barre d'actions (Copier, Exporter .txt, Exporter .m3u8)
                actionsFooterView
            }
            .padding(14)
        }
        .frame(minWidth: 540, minHeight: 620)
        .background(
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12)
                
                // Léger dégradé d'ambiance en arrière-plan
                LinearGradient(
                    colors: [
                        Color.accentCyan.opacity(0.08),
                        Color.clear,
                        Color.purple.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .onAppear {
            applyFormatDefaults(for: selectedFormat)
            regenerateText()
        }
        .onChange(of: selectedSource) { _ in
            regenerateText()
        }
        .onChange(of: selectedFormat) { newFormat in
            applyFormatDefaults(for: newFormat)
            regenerateText()
        }
        .onChange(of: includeTimestamps) { _ in regenerateText() }
        .onChange(of: includeNumbering) { _ in regenerateText() }
        .onChange(of: includeBpmKey) { _ in regenerateText() }
        .onChange(of: artistFirst) { _ in regenerateText() }
        .onChange(of: chronologicalOrder) { _ in regenerateText() }
    }
    
    // MARK: - 1. En-tête
    
    private var headerView: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentCyan.opacity(0.16))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.accentCyan)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Générateur de Tracklist")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.white)
                
                Text("YouTube • 1001Tracklists • Insta • SoundCloud • M3U8")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            Spacer()
            
            Button {
                onClose?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    SetRecapWindowController.shared.show()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 9.5))
                    Text("Stats du mix")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color.accentCyan)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.accentCyan.opacity(0.14))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.accentCyan.opacity(0.35), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
            .help("Consulter le bilan statistique de ce mix (Cmd+Shift+S)")
            
            if let closeAction = onClose {
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("close_tracklist_button")
                .accessibilityLabel("Fermer la fenêtre")
                .help("Fermer la fenêtre (Esc ou Cmd+W)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - 2. Source Selector
    
    private var sourceSelectorView: some View {
        HStack(spacing: 8) {
            ForEach(TracklistSource.allCases) { src in
                let count = countForSource(src)
                let isSelected = selectedSource == src
                
                Button {
                    selectedSource = src
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: src.icon)
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? Color.accentCyan : .white.opacity(0.6))
                        
                        Text(src.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                        
                        Text("\(count)")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(isSelected ? Color.accentCyan : .white.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(isSelected ? Color.accentCyan.opacity(0.20) : Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isSelected ? Color.accentCyan.opacity(0.14) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isSelected ? Color.accentCyan.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("source_\(src.id)")
                .accessibilityLabel(src.rawValue)
            }
        }
    }
    
    // MARK: - 3. Format Selector
    
    private var formatSelectorView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FORMAT DU SOMMAIRE")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.5)
                
                Spacer()
                
                Text(selectedFormat.sample)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(Color.accentCyan.opacity(0.85))
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(TracklistFormat.allCases) { fmt in
                    let isSelected = selectedFormat == fmt
                    Button {
                        selectedFormat = fmt
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: fmt.icon)
                                .font(.system(size: 10.5))
                                .foregroundColor(isSelected ? Color.accentCyan : .white.opacity(0.6))
                            
                            Text(fmt.rawValue)
                                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentCyan.opacity(0.18) : Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.accentCyan.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("format_\(fmt.id)")
                    .accessibilityLabel(fmt.rawValue)
                }
            }
        }
    }
    
    // MARK: - 4. Options Bar
    
    private var optionsBarView: some View {
        HStack(spacing: 8) {
            // Toggle Timestamps
            optionToggle(
                title: "Horodatage",
                icon: "clock",
                isOn: $includeTimestamps,
                disabled: selectedFormat == .m3u8
            )
            
            // Toggle Numbering
            optionToggle(
                title: "Numérotation",
                icon: "number",
                isOn: $includeNumbering,
                disabled: selectedFormat == .m3u8
            )
            
            // Toggle BPM & Key
            optionToggle(
                title: "BPM & Clé",
                icon: "waveform.path",
                isOn: $includeBpmKey,
                disabled: selectedFormat == .m3u8
            )
            
            // Toggle Artist First
            optionToggle(
                title: artistFirst ? "Artiste - Titre" : "Titre - Artiste",
                icon: "arrow.triangle.swap",
                isOn: $artistFirst,
                disabled: selectedFormat == .m3u8
            )
            
            // Toggle Order
            optionToggle(
                title: chronologicalOrder ? "Début → Fin" : "Récent d'abord",
                icon: "arrow.up.arrow.down",
                isOn: $chronologicalOrder,
                disabled: false
            )
        }
    }
    
    private func optionToggle(title: String, icon: String, isOn: Binding<Bool>, disabled: Bool) -> some View {
        Button {
            guard !disabled else { return }
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8.5))
                
                Text(title)
                    .font(.system(size: 9.5, weight: isOn.wrappedValue ? .bold : .medium))
            }
            .foregroundColor(disabled ? .white.opacity(0.25) : (isOn.wrappedValue ? Color.accentCyan : .white.opacity(0.65)))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isOn.wrappedValue && !disabled ? Color.accentCyan.opacity(0.14) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isOn.wrappedValue && !disabled ? Color.accentCyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("option_\(title)")
        .accessibilityLabel(title)
        .disabled(disabled)
    }
    
    // MARK: - 5. Summary / Stats Bar
    
    private var summaryStatsBarView: some View {
        let items = fetchRawItems()
        let totalCount = items.count
        let totalDuration = items.reduce(0.0) { $0 + ($1.durationSeconds > 0 ? $1.durationSeconds : 180.0) }
        let validBpms = items.map { $0.bpm }.filter { $0 > 0 }
        
        let minBpm = validBpms.min() ?? 0
        let maxBpm = validBpms.max() ?? 0
        
        let durationFormatted: String = {
            let totalSec = Int(totalDuration.rounded())
            let hours = totalSec / 3600
            let minutes = (totalSec % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)min"
            } else {
                return "\(minutes) min"
            }
        }()
        
        return HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "music.note")
                    .foregroundColor(Color.accentCyan)
                Text("\(totalCount) morceau\(totalCount > 1 ? "x" : "")")
                    .foregroundColor(.white)
            }
            .font(.system(size: 10, weight: .semibold))
            
            Text("•")
                .foregroundColor(.white.opacity(0.3))
            
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .foregroundColor(.purple)
                Text("~\(durationFormatted)")
                    .foregroundColor(.white.opacity(0.9))
            }
            .font(.system(size: 10, weight: .medium))
            
            if minBpm > 0 && maxBpm > 0 {
                Text("•")
                    .foregroundColor(.white.opacity(0.3))
                
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                    if abs(minBpm - maxBpm) < 0.5 {
                        Text("\(Int(minBpm.rounded())) BPM")
                    } else {
                        Text("\(Int(minBpm.rounded())) - \(Int(maxBpm.rounded())) BPM")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            if isManuallyEdited {
                Button {
                    regenerateText(force: true)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Rétablir texte auto")
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(Color.accentCyan)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_reset_auto")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
    }
    
    // MARK: - 6. Editor / Preview
    
    private var editorView: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $currentText)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.92))
                .padding(8)
                .background(Color(red: 0.05, green: 0.06, blue: 0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .onChange(of: currentText) { _ in
                    isManuallyEdited = true
                }
            
            // Toast flottant lors de la copie
            if showCopyToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Copié dans le presse-papier !")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.1, green: 0.12, blue: 0.16).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green.opacity(0.6), lineWidth: 1)
                )
                .cornerRadius(6)
                .padding(12)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - 7. Actions Footer
    
    private var actionsFooterView: some View {
        HStack(spacing: 8) {
            // Bouton Principal : Copier dans le presse-papier
            Button {
                copyToClipboard()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Copier dans le presse-papier")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color.accentCyan, Color.accentCyan.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
                .shadow(color: Color.accentCyan.opacity(0.35), radius: 4, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("copy_button")
            .accessibilityLabel("Copier dans le presse-papier")
            .keyboardShortcut("c", modifiers: .command)
            
            // Bouton Secondaire : Exporter .txt
            Button {
                exportToFile(isM3U8: false)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 10.5))
                    Text("Exporter .txt")
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
            .accessibilityIdentifier("export_txt_button")
            .accessibilityLabel("Exporter au format texte")
            
            // Bouton Secondaire : Exporter .m3u8
            Button {
                exportToFile(isM3U8: true)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 10.5))
                    Text("Exporter .m3u8")
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
            .accessibilityIdentifier("export_m3u8_button")
            .accessibilityLabel("Exporter la playlist M3U8")
            .help("Créer un fichier playlist M3U8 importable dans Rekordbox, Serato ou Lexicon")
        }
    }
    
    // MARK: - Logique & Génération
    
    private func countForSource(_ src: TracklistSource) -> Int {
        switch src {
        case .session:
            return sessionService.playedTracks.count
        case .toPlay:
            return toPlayService.tracks.count
        }
    }
    
    private func fetchRawItems() -> [UnifiedTrackItem] {
        switch selectedSource {
        case .session:
            let list = sessionService.playedTracks
            let sorted = chronologicalOrder ? list.reversed() : list
            return sorted.map { tr in
                UnifiedTrackItem(
                    id: tr.id,
                    title: tr.displayTitle,
                    artist: tr.displayArtist,
                    bpm: tr.bpm,
                    rawKey: tr.rawKey,
                    camelotKey: tr.camelotKey,
                    playedAt: tr.playedAt,
                    durationSeconds: tr.durationSeconds,
                    filePath: tr.fileName
                )
            }
        case .toPlay:
            let list = toPlayService.tracks
            let sorted = chronologicalOrder ? list : list.reversed()
            return sorted.map { tr in
                UnifiedTrackItem(
                    id: tr.id,
                    title: tr.displayTitle,
                    artist: tr.displayArtist,
                    bpm: tr.bpm,
                    rawKey: tr.rawKey,
                    camelotKey: tr.camelotKey,
                    playedAt: tr.addedAt,
                    durationSeconds: 180.0,
                    filePath: tr.filePath ?? tr.fileName
                )
            }
        }
    }
    
    private func applyFormatDefaults(for format: TracklistFormat) {
        switch format {
        case .youtube:
            includeTimestamps = true
            includeNumbering = false
            includeBpmKey = false
        case .tracklist1001:
            includeTimestamps = true
            includeNumbering = true
            includeBpmKey = false
        case .social:
            includeTimestamps = false
            includeNumbering = true
            includeBpmKey = false
        case .liveTimestamp:
            includeTimestamps = true
            includeNumbering = false
            includeBpmKey = false
        case .detailedDJ:
            includeTimestamps = true
            includeNumbering = true
            includeBpmKey = true
        case .m3u8:
            break
        }
    }
    
    private func regenerateText(force: Bool = false) {
        let items = fetchRawItems()
        guard !items.isEmpty else {
            currentText = "// Aucun morceau détecté dans cette sélection.\n// Jouez des morceaux en direct dans Serato/Rekordbox ou ajoutez-en à votre Sélec pour générer la tracklist !"
            isManuallyEdited = false
            return
        }
        
        // Format M3U8 spécial
        if selectedFormat == .m3u8 {
            currentText = buildM3U8Content(items: items)
            isManuallyEdited = false
            return
        }
        
        var lines: [String] = []
        
        // En-tête convivial pour réseaux
        if selectedFormat == .social {
            lines.append("🎧 TRACKLIST :")
            lines.append("")
        }
        
        // Calcul du premier morceau pour les timestamps relatifs
        let firstPlayed = items.compactMap { $0.playedAt }.min() ?? Date()
        var cumulativeSec: Double = 0.0
        
        for (index, item) in items.enumerated() {
            var lineParts: [String] = []
            
            // 1. Numéro (ex: "01.")
            if includeNumbering {
                let numStr = String(format: "%02d.", index + 1)
                lineParts.append(numStr)
            }
            
            // 2. Horodatage (Timestamp)
            if includeTimestamps {
                if selectedFormat == .liveTimestamp {
                    let timeStr = formatRealTime(item.playedAt ?? Date())
                    lineParts.append("[\(timeStr)]")
                } else {
                    let elapsed: Double
                    if selectedSource == .session, let played = item.playedAt {
                        elapsed = max(0, played.timeIntervalSince(firstPlayed))
                    } else {
                        elapsed = cumulativeSec
                        cumulativeSec += (item.durationSeconds > 0 ? item.durationSeconds : 180.0)
                    }
                    
                    let relTime = formatRelativeTime(elapsed)
                    if selectedFormat == .tracklist1001 || selectedFormat == .detailedDJ {
                        lineParts.append("[\(relTime)]")
                    } else {
                        lineParts.append(relTime)
                    }
                }
            }
            
            // 3. Nom de piste (Artiste - Titre)
            lineParts.append(formatTrackName(item))
            
            // 4. BPM & Clé Camelot
            if includeBpmKey || selectedFormat == .detailedDJ {
                var metaParts: [String] = []
                if item.bpm > 0 {
                    let bpmStr = abs(item.bpm.rounded() - item.bpm) < 0.05 ? "\(Int(item.bpm.rounded()))" : String(format: "%.1f", item.bpm)
                    metaParts.append("\(bpmStr) BPM")
                }
                if let camelot = item.camelotKey {
                    metaParts.append(camelot.displayText(mode: settings.keyDisplayMode))
                } else if !item.rawKey.isEmpty {
                    metaParts.append(item.rawKey)
                }
                
                if !metaParts.isEmpty {
                    lineParts.append("[\(metaParts.joined(separator: " • "))]")
                }
            }
            
            lines.append(lineParts.joined(separator: " "))
        }
        
        if selectedFormat == .social {
            lines.append("")
            lines.append("⚡️ Mixé en live avec Recall (https://revrmusic.github.io/recall/)")
        }
        
        currentText = lines.joined(separator: "\n")
        isManuallyEdited = false
    }
    
    private func buildM3U8Content(items: [UnifiedTrackItem]) -> String {
        var lines: [String] = ["#EXTM3U"]
        for item in items {
            let dur = item.durationSeconds > 0 ? Int(item.durationSeconds) : -1
            let name = formatTrackName(item)
            lines.append("#EXTINF:\(dur),\(name)")
            if let path = item.filePath, !path.isEmpty {
                lines.append(path)
            } else {
                lines.append(name)
            }
        }
        return lines.joined(separator: "\n")
    }
    
    private func formatTrackName(_ item: UnifiedTrackItem) -> String {
        let art = item.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if art.isEmpty || art.lowercased() == "artiste inconnu" || art.lowercased() == "unknown artist" {
            return tit.isEmpty ? "Morceau inconnu" : tit
        }
        
        if artistFirst {
            return "\(art) - \(tit)"
        } else {
            return "\(tit) - \(art)"
        }
    }
    
    private func formatRelativeTime(_ seconds: Double) -> String {
        let totalSec = max(0, Int(seconds.rounded()))
        let hours = totalSec / 3600
        let minutes = (totalSec % 3600) / 60
        let secs = totalSec % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    private func formatRealTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentText, forType: .string)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
    
    private func exportToFile(isM3U8: Bool) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        let ext = isM3U8 ? "m3u8" : "txt"
        savePanel.allowedContentTypes = isM3U8 ? [.init(filenameExtension: "m3u8") ?? .plainText] : [.plainText]
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "Tracklist Recall - \(dateStr).\(ext)"
        
        NSApp.activate(ignoringOtherApps: true)
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                let contentToSave: String
                if isM3U8 && selectedFormat != .m3u8 {
                    contentToSave = buildM3U8Content(items: fetchRawItems())
                } else {
                    contentToSave = currentText
                }
                
                try? contentToSave.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
