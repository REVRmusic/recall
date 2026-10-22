import SwiftUI
import AppKit

// MARK: - 1. Catégories & Codes Couleurs des Styles Musicaux

/// Catégories canoniques de styles pour la visualisation temporelle du mix
public enum MusicStyleCategory: String, CaseIterable, Identifiable, Codable {
    case electro = "Électro"
    case latino = "Latino"
    case shatta = "Shatta"
    case bouyon = "Bouyon"
    case hipHop = "Hip-Hop"
    case afro = "Afro"
    case afroBeat = "Afro-Beat"
    case dancehall = "Dancehall / Zouk"
    case rnb = "R&B / Funk"
    case pop = "Pop"
    case rock = "Rock"
    case mix = "Mix"
    case other = "Autre"
    
    public var id: String { rawValue }
    
    /// Code couleur officiel conforme aux exigences utilisateur :
    /// - Bleu pour l'électro / EDM / House / Techno
    /// - Jaune pour le latino / reggaeton
    /// - Orange pour le shatta
    /// - Vermillon pour le bouyon
    /// - Rouge pour le hip-hop / rap
    /// - Vert pour l'afro / amapiano
    /// - Vert citron pour l'afro-beat (afrobeats, afro-pop)
    /// - Turquoise pour dancehall / reggae / zouk
    /// - Violet pour R&B / soul / funk
    /// - Rose pour pop / commercial
    /// - Magenta pour rock
    /// - Indigo pour un mix long (mixtape, podcast, mix pré-enregistré)
    /// - Gris ardoise pour autre
    public var color: Color {
        switch self {
        case .electro:
            return Color(hex: "#0A84FF") // Bleu électrique vif
        case .latino:
            return Color(hex: "#FFD600") // Jaune doré solaire
        case .shatta:
            return Color(hex: "#FF7A00") // Orange tropical vibrant
        case .bouyon:
            return Color(hex: "#FF5A1F") // Vermillon, plus chaud que le shatta
        case .hipHop:
            return Color(hex: "#FF3B30") // Rouge percutant
        case .afro:
            return Color(hex: "#34C759") // Vert émeraude
        case .afroBeat:
            return Color(hex: "#C6F531") // Vert citron, distinct de l'afro vague
        case .dancehall:
            return Color(hex: "#30D1B2") // Turquoise caraïbe
        case .rnb:
            return Color(hex: "#AF52DE") // Violet profond
        case .pop:
            return Color(hex: "#FF2D55") // Rose néon
        case .rock:
            return Color(hex: "#E056FD") // Magenta énergique
        case .mix:
            return Color(hex: "#5E5CE6") // Indigo, distinct des genres musicaux
        case .other:
            return Color(hex: "#8E8E93") // Gris ardoise neutre
        }
    }
    
    /// Icône SF Symbol représentative du style
    public var iconName: String {
        switch self {
        case .electro: return "bolt.horizontal.fill"
        case .latino: return "sun.max.fill"
        case .shatta: return "flame.fill"
        case .bouyon: return "tornado"
        case .hipHop: return "mic.fill"
        case .afro: return "leaf.fill"
        case .afroBeat: return "waveform"
        case .dancehall: return "tropicalstorm"
        case .rnb: return "heart.fill"
        case .pop: return "star.fill"
        case .rock: return "guitars.fill"
        case .mix: return "recordingtape"
        case .other: return "music.note"
        }
    }
    
    /// Détection intelligente du style musical à partir du genre brut ou canonique
    public static func from(genre: String) -> MusicStyleCategory {
        let clean = genre.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.isEmpty { return .other }
        
        // 1. Bouyon puis Shatta
        if clean.contains("bouyon") {
            return .bouyon
        }
        if clean.contains("shatta") {
            return .shatta
        }
        
        // 2. Latino & Reggaeton (Jaune) — avant « ragga », car raggaeton contient « ragga »
        let folded = clean.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let compact = folded.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
        if folded.contains("latino") || folded.contains("latin") || folded.contains("reggaeton") ||
           folded.contains("raggaeton") || folded.contains("regeton") || folded.contains("regueton") ||
           folded.contains("ragaeton") || folded.contains("raggaton") || compact.contains("raggaeton") ||
           folded.contains("dembow") || folded.contains("baile") ||
           folded.contains("bachata") || folded.contains("salsa") || folded.contains("merengue") ||
           folded.contains("cumbia") || folded.contains("perreo") || folded.contains("urbano") ||
           folded.contains("urbana") ||
           folded.contains("moombahton") {
            return .latino
        }
        
        // 3. Hip-Hop & Rap (Rouge). « Urban » oui, « Urbano » non (déjà classé latino au-dessus).
        let withoutUrbano = clean.replacingOccurrences(of: "urbano", with: " ").replacingOccurrences(of: "urbana", with: " ")
        if clean.contains("hip-hop") || clean.contains("hip hop") || clean.contains("hiphop") ||
           clean.contains("rap") || clean.contains("trap") || clean.contains("drill") ||
           clean.contains("boom bap") || clean.contains("crunk") || clean.contains("phonk") ||
           clean.contains("urbain") || withoutUrbano.contains("urban") {
            return .hipHop
        }
        
        // Dancehall avant « dance » : le mot dancehall contient « dance », sinon il partait en Électro.
        if compact.contains("dancehall") {
            return .dancehall
        }
        
        // 4. Électro / House / Techno / Bass / EDM (Bleu)
        if clean.contains("electro") || clean.contains("edm") || clean.contains("house") ||
           clean.contains("techno") || clean.contains("trance") || clean.contains("drum & bass") ||
           clean.contains("drum and bass") || clean.contains("dnb") || clean.contains("dubstep") ||
           clean.contains("hardstyle") || clean.contains("eurodance") || clean.contains("garage") ||
           clean.contains("big room") || clean.contains("minimal") || clean.contains("bass") ||
           clean.contains("club") || clean.contains("dance") {
            return .electro
        }
        
        // Afrobeats / Afro-pop, avant le tag vague « Afro » et avant « pop ».
        if compact.contains("afrobeat") || compact.contains("afropop") {
            return .afroBeat
        }
        
        // 5. Afro & Amapiano (Vert)
        if clean.contains("afro") || clean.contains("amapiano") || clean.contains("coupe decale") ||
           clean.contains("coupé décalé") || clean.contains("ndombolo") || clean.contains("kizomba") ||
           clean.contains("semba") || clean.contains("gqom") || clean.contains("highlife") {
            return .afro
        }
        
        // 6. Dancehall, Reggae & Zouk (Turquoise)
        if clean.contains("dancehall") || clean.contains("ragga") || clean.contains("reggae") ||
           clean.contains("zouk") || clean.contains("kompa") || clean.contains("gouyad") ||
           clean.contains("dub") {
            return .dancehall
        }
        
        // 7. R&B, Soul & Funk (Violet)
        if clean.contains("r&b") || clean.contains("rnb") || clean.contains("soul") ||
           clean.contains("funk") || clean.contains("disco") || clean.contains("boogie") {
            return .rnb
        }
        
        // 8. Pop & Commercial (Rose)
        if clean.contains("pop") || clean.contains("top 40") || clean.contains("commercial") ||
           clean.contains("variété") || clean.contains("variete") || clean.contains("chanson") {
            return .pop
        }
        
        // 9. Rock & Metal (Magenta)
        if clean.contains("rock") || clean.contains("metal") || clean.contains("punk") ||
           clean.contains("indie") || clean.contains("grunge") || clean.contains("alternative") {
            return .rock
        }
        
        return .other
    }
}

// MARK: - 2. Modèles de Données pour la Frise Temporelle

/// Segment individuel représentant un morceau joué dans la frise temporelle
public struct GenreTimelineSegment: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let displayGenre: String
    public let style: MusicStyleCategory
    public let startTime: Date
    public let endTime: Date
    public let durationSeconds: Double
    public let bpm: Double
    public let rawKey: String
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        displayGenre: String,
        style: MusicStyleCategory,
        startTime: Date,
        endTime: Date,
        durationSeconds: Double,
        bpm: Double = 0.0,
        rawKey: String = ""
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.displayGenre = displayGenre
        self.style = style
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.bpm = bpm
        self.rawKey = rawKey
    }
}

/// Découpage horaire d'une phase du mix avec son style dominant et sa répartition
public struct HourlyStylePhase: Identifiable {
    public let id: String
    public let label: String
    public let startDate: Date
    public let endDate: Date
    public let dominantStyle: MusicStyleCategory
    public let dominantPercentage: Double
    public let trackCount: Int
    public let stylePercentages: [(style: MusicStyleCategory, percent: Double, count: Int)]
    
    public init(
        id: String = UUID().uuidString,
        label: String,
        startDate: Date,
        endDate: Date,
        dominantStyle: MusicStyleCategory,
        dominantPercentage: Double,
        trackCount: Int,
        stylePercentages: [(style: MusicStyleCategory, percent: Double, count: Int)]
    ) {
        self.id = id
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
        self.dominantStyle = dominantStyle
        self.dominantPercentage = dominantPercentage
        self.trackCount = trackCount
        self.stylePercentages = stylePercentages
    }
}

// MARK: - 3. Générateur / Constructeur de Segments Temporels

public struct GenreTimelineBuilder {
    
    /// Construit les segments chronologiques à partir de la liste des morceaux joués
    public static func buildSegments(
        from tracks: [SessionPlayedTrack],
        sessionStartTime: Date,
        isLive: Bool
    ) -> (segments: [GenreTimelineSegment], start: Date, end: Date, duration: Double) {
        guard !tracks.isEmpty else {
            return ([], sessionStartTime, sessionStartTime, 0.0)
        }
        
        let sorted = tracks.sorted { $0.playedAt < $1.playedAt }
        let now = Date()
        
        var segments: [GenreTimelineSegment] = []
        
        for i in 0..<sorted.count {
            let tr = sorted[i]
            let start = tr.startTime
            let end: Date
            
            if i + 1 < sorted.count {
                let nextStart = sorted[i + 1].startTime
                if let trackEnd = tr.endTime, trackEnd > start {
                    end = min(trackEnd, nextStart)
                } else {
                    end = nextStart
                }
            } else {
                // Dernier morceau
                if tr.isCurrentlyPlaying || isLive {
                    end = max(start.addingTimeInterval(30.0), now)
                } else if let trackEnd = tr.endTime, trackEnd > start {
                    end = trackEnd
                } else {
                    let dur = tr.durationSeconds > 0 ? tr.durationSeconds : 180.0
                    end = start.addingTimeInterval(dur)
                }
            }
            
            let dur = max(15.0, end.timeIntervalSince(start))
            let isLongFormMix = tr.isLongFormMix
            let canonicalGenre = isLongFormMix ? MusicStyleCategory.mix.rawValue : tr.displayGenre
            let style = isLongFormMix
                ? MusicStyleCategory.mix
                : MusicStyleCategory.from(genre: canonicalGenre.isEmpty ? tr.genre : canonicalGenre)
            
            segments.append(GenreTimelineSegment(
                id: "\(tr.id)_\(i)",
                title: tr.displayTitle,
                artist: tr.displayArtist,
                displayGenre: canonicalGenre.isEmpty ? style.rawValue : canonicalGenre,
                style: style,
                startTime: start,
                endTime: end,
                durationSeconds: dur,
                bpm: tr.bpm,
                rawKey: tr.rawKey
            ))
        }
        
        let effectiveStart = segments.first?.startTime ?? sessionStartTime
        let effectiveEnd = segments.last?.endTime ?? (isLive ? now : effectiveStart.addingTimeInterval(60.0))
        let totalSpan = max(30.0, effectiveEnd.timeIntervalSince(effectiveStart))
        
        return (segments, effectiveStart, effectiveEnd, totalSpan)
    }
    
    /// Construit les repères horaires fixes pour l'axe chronologique (ex: 23h00, 00h00, 01h00, etc.)
    public static func computeHourTicks(
        start: Date,
        end: Date,
        totalDuration: Double
    ) -> [Date] {
        guard totalDuration >= 300.0 else { return [] } // Au moins 5 min de mix
        
        let calendar = Calendar.current
        var ticks: [Date] = []
        
        // Intervalle : 30 min si le mix dure <= 2h, 1 heure si <= 6h, 2 heures sinon
        let stepMinutes: Int
        if totalDuration <= 7200.0 {
            stepMinutes = 30
        } else if totalDuration <= 21600.0 {
            stepMinutes = 60
        } else {
            stepMinutes = 120
        }
        
        // Trouver la première graduation ronde après le début
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        let currentMinute = comps.minute ?? 0
        let nextMinute = ((currentMinute / stepMinutes) + 1) * stepMinutes
        
        if nextMinute >= 60 {
            comps.hour = (comps.hour ?? 0) + 1
            comps.minute = nextMinute % 60
        } else {
            comps.minute = nextMinute
        }
        comps.second = 0
        
        guard var cursor = calendar.date(from: comps) else { return [] }
        
        // Marge minimale en secondes pour éviter le chevauchement visuel avec start et end
        let minMarginSeconds = Double(stepMinutes) * 20.0
        
        while cursor < end {
            if cursor.timeIntervalSince(start) >= minMarginSeconds && end.timeIntervalSince(cursor) >= minMarginSeconds {
                ticks.append(cursor)
            }
            guard let next = calendar.date(byAdding: .minute, value: stepMinutes, to: cursor) else { break }
            cursor = next
        }
        
        return ticks
    }
    
    /// Calcule les tranches horaires avec style dominant (ex: "23h00 - 00h00" : Électro 80%)
    public static func computeHourlyPhases(
        segments: [GenreTimelineSegment],
        start: Date,
        end: Date
    ) -> [HourlyStylePhase] {
        guard !segments.isEmpty else { return [] }
        let totalDur = end.timeIntervalSince(start)
        guard totalDur >= 1200.0 else { return [] } // Au moins 20 minutes
        
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "fr_FR")
        timeFormatter.dateFormat = "HH'h'mm"
        
        // Déterminer les frontières d'heures
        var boundaries: [Date] = [start]
        var comps = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        comps.minute = 0
        comps.second = 0
        if var cursor = calendar.date(from: comps) {
            cursor = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? cursor
            while cursor < end {
                if cursor > start.addingTimeInterval(900.0) { // Au moins 15 min du début
                    boundaries.append(cursor)
                }
                cursor = calendar.date(byAdding: .hour, value: 1, to: cursor) ?? cursor
            }
        }
        boundaries.append(end)
        
        // Déduplication & tri
        boundaries = Array(Set(boundaries)).sorted()
        guard boundaries.count >= 2 else { return [] }
        
        var phases: [HourlyStylePhase] = []
        
        for i in 0..<(boundaries.count - 1) {
            let slotStart = boundaries[i]
            let slotEnd = boundaries[i + 1]
            let slotDur = slotEnd.timeIntervalSince(slotStart)
            guard slotDur >= 600.0 else { continue } // Au moins 10 minutes
            
            // Trouver les segments chevauchant cette tranche
            var styleDurations: [MusicStyleCategory: Double] = [:]
            var styleCounts: [MusicStyleCategory: Int] = [:]
            var tracksInSlot = 0
            
            for seg in segments {
                let overlapStart = max(slotStart, seg.startTime)
                let overlapEnd = min(slotEnd, seg.endTime)
                if overlapEnd > overlapStart {
                    let overlapDur = overlapEnd.timeIntervalSince(overlapStart)
                    styleDurations[seg.style, default: 0.0] += overlapDur
                    styleCounts[seg.style, default: 0] += 1
                    tracksInSlot += 1
                }
            }
            
            guard tracksInSlot > 0 else { continue }
            
            let totalSlotDuration = styleDurations.values.reduce(0.0, +)
            guard totalSlotDuration > 0 else { continue }
            
            let sortedStyles = styleDurations.sorted { $0.value > $1.value }
            guard let top = sortedStyles.first else { continue }
            
            let dominantPercent = (top.value / totalSlotDuration) * 100.0
            let percentages = sortedStyles.map { (style: $0.key, percent: ($0.value / totalSlotDuration) * 100.0, count: styleCounts[$0.key] ?? 0) }
            
            let label = "\(timeFormatter.string(from: slotStart)) - \(timeFormatter.string(from: slotEnd))"
            
            phases.append(HourlyStylePhase(
                label: label,
                startDate: slotStart,
                endDate: slotEnd,
                dominantStyle: top.key,
                dominantPercentage: dominantPercent,
                trackCount: tracksInSlot,
                stylePercentages: percentages
            ))
        }
        
        return phases
    }
}

// MARK: - 4. Composant Graphique Principal (SetRecapView)

public struct GenreTimelineChartView: View {
    public let tracks: [SessionPlayedTrack]
    public let sessionStartTime: Date
    public let sessionEndTime: Date?
    public let isLive: Bool
    
    @State private var selectedStyleFilter: MusicStyleCategory? = nil
    
    public init(
        tracks: [SessionPlayedTrack],
        sessionStartTime: Date,
        sessionEndTime: Date? = nil,
        isLive: Bool = false
    ) {
        self.tracks = tracks
        self.sessionStartTime = sessionStartTime
        self.sessionEndTime = sessionEndTime
        self.isLive = isLive
    }
    
    private var timelineData: (segments: [GenreTimelineSegment], start: Date, end: Date, duration: Double) {
        GenreTimelineBuilder.buildSegments(
            from: tracks,
            sessionStartTime: sessionStartTime,
            isLive: isLive
        )
    }
    
    private var styleDistribution: [(style: MusicStyleCategory, count: Int, percent: Double)] {
        let segs = timelineData.segments
        guard !segs.isEmpty else { return [] }
        var counts: [MusicStyleCategory: Int] = [:]
        for s in segs {
            counts[s.style, default: 0] += 1
        }
        let total = Double(segs.count)
        return counts
            .sorted { $0.value > $1.value }
            .map { (style: $0.key, count: $0.value, percent: (Double($0.value) / total) * 100.0) }
    }
    
    private var hourTicks: [Date] {
        GenreTimelineBuilder.computeHourTicks(
            start: timelineData.start,
            end: timelineData.end,
            totalDuration: timelineData.duration
        )
    }
    
    private var hourlyPhases: [HourlyStylePhase] {
        GenreTimelineBuilder.computeHourlyPhases(
            segments: timelineData.segments,
            start: timelineData.start,
            end: timelineData.end
        )
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "HH'h'mm"
        return df
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // En-tête de la section
            headerView
            
            if timelineData.segments.isEmpty {
                emptyStateView
            } else {
                // Légende interactive des styles avec pastilles de couleur
                legendPillsView
                
                // Frise chronologique avec heures bien visibles
                timelineRibbonView
                
                // Répartition par tranches horaires (si set >= 20 min)
                if !hourlyPhases.isEmpty {
                    hourlyPhasesView
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
    
    // MARK: - En-tête
    
    private var headerView: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.accentCyan)
                
                Text("ÉVOLUTION DES STYLES AU FIL DU SET")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(0.6)
            }
            
            Spacer()
            
            if !timelineData.segments.isEmpty {
                HStack(spacing: 6) {
                    Text("\(timelineData.segments.count) morceaux")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    
                    if let filter = selectedStyleFilter {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedStyleFilter = nil
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text("Filtre : \(filter.rawValue)")
                                Image(systemName: "xmark.circle.fill")
                            }
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(filter.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(filter.color.opacity(0.18))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Légende Interactive des Styles
    
    private var legendPillsView: some View {
        HStack(spacing: 6) {
            ForEach(styleDistribution, id: \.style.id) { item in
                let isSelected = selectedStyleFilter == item.style
                let isDimmed = selectedStyleFilter != nil && !isSelected
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedStyleFilter == item.style {
                            selectedStyleFilter = nil
                        } else {
                            selectedStyleFilter = item.style
                        }
                    }
                } label: {
                    HStack(spacing: 4.5) {
                        Circle()
                            .fill(item.style.color)
                            .frame(width: 7, height: 7)
                            .shadow(color: item.style.color.opacity(isSelected ? 0.6 : 0.3), radius: isSelected ? 3 : 1)
                        
                        Text(item.style.rawValue)
                            .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                            .foregroundColor(.white.opacity(isDimmed ? 0.35 : 0.9))
                        
                        Text("\(Int(item.percent.rounded()))%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(item.style.color.opacity(isDimmed ? 0.35 : 1.0))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? item.style.color.opacity(0.22) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? item.style.color.opacity(0.8) : Color.white.opacity(0.06), lineWidth: isSelected ? 1 : 0.6)
                    )
                }
                .buttonStyle(.plain)
                .help("Filtrer par \(item.style.rawValue) (\(item.count) track\(item.count > 1 ? "s" : ""))")
            }
        }
    }
    
    // MARK: - Frise Chronologique avec Heures Bien Visibles
    
    private var timelineRibbonView: some View {
        VStack(spacing: 6) {
            // Le Ruban Temporel des Morceaux (accéléré GPU via drawingGroup)
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let totalDur = timelineData.duration
                let start = timelineData.start
                
                ZStack(alignment: .leading) {
                    // Fond du ruban
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.40))
                    
                    // Segments colorés des morceaux
                    ForEach(timelineData.segments) { seg in
                        let isFiltered = selectedStyleFilter == nil || selectedStyleFilter == seg.style
                        let startOffset = max(0.0, min(1.0, seg.startTime.timeIntervalSince(start) / totalDur))
                        let endOffset = max(startOffset, min(1.0, seg.endTime.timeIntervalSince(start) / totalDur))
                        let xPos = totalWidth * CGFloat(startOffset)
                        let rawWidth = totalWidth * CGFloat(endOffset - startOffset)
                        let segWidth = max(3.0, rawWidth)
                        
                        Rectangle()
                            .fill(seg.style.color.opacity(isFiltered ? 0.92 : 0.15))
                            .frame(width: segWidth, height: 32)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black.opacity(0.30), lineWidth: 0.5)
                            )
                            .offset(x: min(totalWidth - segWidth, xPos))
                    }
                    
                    // Lignes verticales de graduation des heures à travers le ruban
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickOffset = max(0.0, min(1.0, tick.timeIntervalSince(start) / totalDur))
                        let xPos = totalWidth * CGFloat(tickOffset)
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: 1.5, height: 32)
                            .offset(x: xPos - 0.75)
                            .allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .drawingGroup()
            }
            .frame(height: 32)
            
            // AXE TEMPOREL AVEC LES HEURES BIEN VISIBLES
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let totalDur = timelineData.duration
                let start = timelineData.start
                let end = timelineData.end
                
                ZStack(alignment: .topLeading) {
                    // Ligne d'axe horizontale
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.top, 2)
                    
                    // Heure de début (extrême gauche)
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.accentCyan)
                            .frame(width: 2, height: 5)
                        
                        HStack(spacing: 2) {
                            Text(timeFormatter.string(from: start))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(x: 0, y: 0)
                    
                    // Graduations intermédiaires des heures
                    ForEach(hourTicks, id: \.self) { tick in
                        let tickOffset = max(0.0, min(1.0, tick.timeIntervalSince(start) / totalDur))
                        let xPos = totalWidth * CGFloat(tickOffset)
                        
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 1.5, height: 5)
                            
                            Text(timeFormatter.string(from: tick))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(Color.accentCyan.opacity(0.95))
                        }
                        .offset(x: max(24, min(totalWidth - 36, xPos - 18)), y: 0)
                    }
                    
                    // Heure de fin (extrême droite)
                    VStack(alignment: .trailing, spacing: 2) {
                        Rectangle()
                            .fill(isLive ? Color.green : Color.accentCyan)
                            .frame(width: 2, height: 5)
                        
                        HStack(spacing: 3) {
                            if isLive {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                                Text("Live")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.green)
                            } else {
                                Text(timeFormatter.string(from: end))
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .offset(y: 0)
                }
            }
            .frame(height: 22)
        }
    }
    
    // MARK: - Découpage par Tranches Horaires
    
    private var hourlyPhasesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "hourglass")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.4))
                Text("PHASES DE LA SOIRÉE (RÉPARTITION PAR HEURE)")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.5)
            }
            
            HStack(spacing: 6) {
                ForEach(hourlyPhases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(phase.label)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            
                            Spacer()
                            
                            Text("\(phase.trackCount)t")
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        // Style dominant du créneau
                        HStack(spacing: 3.5) {
                            Circle()
                                .fill(phase.dominantStyle.color)
                                .frame(width: 6, height: 6)
                            
                            Text(phase.dominantStyle.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(phase.dominantStyle.color)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(Int(phase.dominantPercentage.rounded()))%")
                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                .foregroundColor(phase.dominantStyle.color)
                        }
                        
                        // Mini barre de répartition multicolore pour l'heure
                        GeometryReader { g in
                            HStack(spacing: 1) {
                                ForEach(phase.stylePercentages, id: \.style.id) { sp in
                                    let w = max(2.0, g.size.width * CGFloat(sp.percent / 100.0))
                                    Rectangle()
                                        .fill(sp.style.color)
                                        .frame(width: w, height: 3)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 1.5))
                        }
                        .frame(height: 3)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.025))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(phase.dominantStyle.color.opacity(0.25), lineWidth: 0.6)
                    )
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - État Vide
    
    private var emptyStateView: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
            
            Text("Les données de styles musicaux s'afficheront dès les premiers morceaux joués.")
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 5. Composant Dédié à l'Export HD (SetRecapExportCardView)

public struct GenreTimelineExportSectionView: View {
    public let tracks: [SessionPlayedTrack]
    public let sessionStartTime: Date
    public let sessionEndTime: Date?
    
    public init(
        tracks: [SessionPlayedTrack],
        sessionStartTime: Date,
        sessionEndTime: Date? = nil
    ) {
        self.tracks = tracks
        self.sessionStartTime = sessionStartTime
        self.sessionEndTime = sessionEndTime
    }
    
    private var timelineData: (segments: [GenreTimelineSegment], start: Date, end: Date, duration: Double) {
        GenreTimelineBuilder.buildSegments(
            from: tracks,
            sessionStartTime: sessionStartTime,
            isLive: false
        )
    }
    
    private var styleDistribution: [(style: MusicStyleCategory, count: Int, percent: Double)] {
        let segs = timelineData.segments
        guard !segs.isEmpty else { return [] }
        var counts: [MusicStyleCategory: Int] = [:]
        for s in segs {
            counts[s.style, default: 0] += 1
        }
        let total = Double(segs.count)
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { (style: $0.key, count: $0.value, percent: (Double($0.value) / total) * 100.0) }
    }
    
    private var hourTicks: [Date] {
        GenreTimelineBuilder.computeHourTicks(
            start: timelineData.start,
            end: timelineData.end,
            totalDuration: timelineData.duration
        )
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "HH'h'mm"
        return df
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // En-tête
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.accentCyan)
                
                Text("ÉVOLUTION DES STYLES AU FIL DU SET")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.6)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach(styleDistribution, id: \.style.id) { item in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(item.style.color)
                                .frame(width: 6, height: 6)
                            Text(item.style.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                            Text("\(Int(item.percent.rounded()))%")
                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                .foregroundColor(item.style.color)
                        }
                    }
                }
            }
            
            if !timelineData.segments.isEmpty {
                // Frise colorée HD
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let totalDur = timelineData.duration
                    let start = timelineData.start
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.black.opacity(0.40))
                        
                        ForEach(timelineData.segments) { seg in
                            let startOffset = max(0.0, min(1.0, seg.startTime.timeIntervalSince(start) / totalDur))
                            let endOffset = max(startOffset, min(1.0, seg.endTime.timeIntervalSince(start) / totalDur))
                            let xPos = totalWidth * CGFloat(startOffset)
                            let rawWidth = totalWidth * CGFloat(endOffset - startOffset)
                            let segWidth = max(3.0, rawWidth)
                            
                            Rectangle()
                                .fill(seg.style.color)
                                .frame(width: segWidth, height: 26)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.black.opacity(0.25), lineWidth: 0.5)
                                )
                                .offset(x: min(totalWidth - segWidth, xPos))
                        }
                        
                        // Lignes des heures
                        ForEach(hourTicks, id: \.self) { tick in
                            let tickOffset = max(0.0, min(1.0, tick.timeIntervalSince(start) / totalDur))
                            let xPos = totalWidth * CGFloat(tickOffset)
                            
                            Rectangle()
                                .fill(Color.white.opacity(0.40))
                                .frame(width: 1.5, height: 26)
                                .offset(x: xPos - 0.75)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .frame(height: 26)
                
                // Graduations des heures
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let totalDur = timelineData.duration
                    let start = timelineData.start
                    let end = timelineData.end
                    
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.top, 2)
                        
                        // Début
                        Text(timeFormatter.string(from: start))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .offset(x: 0, y: 4)
                        
                        // Heures intermédiaires
                        ForEach(hourTicks, id: \.self) { tick in
                            let tickOffset = max(0.0, min(1.0, tick.timeIntervalSince(start) / totalDur))
                            let xPos = totalWidth * CGFloat(tickOffset)
                            
                            Text(timeFormatter.string(from: tick))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(Color.accentCyan.opacity(0.95))
                                .offset(x: max(20, min(totalWidth - 32, xPos - 14)), y: 4)
                        }
                        
                        // Fin
                        Text(timeFormatter.string(from: end))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: 4)
                    }
                }
                .frame(height: 18)
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
}
