import SwiftUI
import AppKit

/// Vue dédiée à la génération de l'image visuelle haute définition du Bilan Statistique (Set Recap)
/// Restitue l'intégralité des données du mix sous une présentation esthétique, moderne et prête au partage.
public struct SetRecapExportCardView: View {
    public let stats: SetRecapStats
    public let sessionStartTime: Date
    public let sessionEndTime: Date?
    public let eventTitle: String?
    public let generationDate: Date
    public let hideDuration: Bool
    
    public init(
        stats: SetRecapStats,
        sessionStartTime: Date,
        sessionEndTime: Date? = nil,
        eventTitle: String? = nil,
        generationDate: Date = Date(),
        hideDuration: Bool = false
    ) {
        self.stats = stats
        self.sessionStartTime = sessionStartTime
        self.sessionEndTime = sessionEndTime
        self.eventTitle = eventTitle
        self.generationDate = generationDate
        self.hideDuration = hideDuration
    }
    
    public var body: some View {
        VStack(spacing: 14) {
            // 1. En-tête de marque & date du mix
            headerBrandingView
            
            // 2. Carte Principale : Durée totale & Pacing du mix
            heroDurationCard
            
            // 3. Grille des indicateurs clés (BPM, Clé dominante, Genre dominant, Transition rapide, Vitesse, Lectures)
            metricsGridView
            
            // 4. Section Top Genres joués
            if !stats.topGenres.isEmpty {
                topGenresSection
            }
            
            // 5. Section Top Artistes joués
            if !stats.topArtists.isEmpty {
                topArtistsSection
            }
            
            // 6. Section Distribution Harmonique
            if !stats.keyDistribution.isEmpty {
                harmonicDistributionSection
            }
            
            // 7. Signature de marque inférieure
            footerBrandingView
        }
        .padding(22)
        .frame(width: 560)
        .background(
            ZStack {
                // Fond sombre ultra-profond
                Color(red: 0.08, green: 0.09, blue: 0.12)
                
                // Dégradé néon club immersif
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.14),
                        Color.clear,
                        Color.accentCyan.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - 1. En-tête de Marque
    
    private var headerBrandingView: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.4), Color.accentCyan.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.accentCyan)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Statistiques du Mix")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("SET RECAP")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(Color.accentCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentCyan.opacity(0.18))
                        .cornerRadius(4)
                }
                
                HStack(spacing: 6) {
                    Text(displaySessionTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 10))
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stats.totalTracksCount == 0 ? Color.white.opacity(0.3) : (stats.isLiveSession ? Color.green : Color.orange))
                            .frame(width: 6, height: 6)
                        Text(stats.totalTracksCount == 0 ? "Non démarré" : (stats.isLiveSession ? "Session en direct" : "Session enregistrée"))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(stats.isLiveSession ? Color.green.opacity(0.9) : Color.white.opacity(0.6))
                    }
                }
            }
            
            Spacer()
            
            // Badge Recall
            VStack(alignment: .trailing, spacing: 2) {
                Text("RECALL")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentCyan, Color.purple.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("DJ COMPANION")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.bottom, 2)
    }
    
    // MARK: - 2. Carte Durée & Pacing
    
    private var heroDurationCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hideDuration ? "TOTAL DU MIX" : "DURÉE TOTALE DU MIX")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.6)
                    
                    if hideDuration {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(stats.totalTracksCount)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text("morceaux joués")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.accentCyan)
                        }
                    } else {
                        Text(formatDuration(stats.totalDurationSeconds))
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                mixPaceBadge
            }
            
            if !hideDuration {
                // Horaires du set : Début & Fin
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color.accentCyan)
                        Text("Début :")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.60))
                        Text(formatHourMinute(sessionStartTime))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    if let end = resolvedSessionEndTime {
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.30))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 9))
                                .foregroundColor(Color.accentCyan.opacity(0.85))
                            Text("Fin :")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.60))
                            Text(formatHourMinute(end))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 1)
            }
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            HStack(spacing: 12) {
                if hideDuration {
                    // Métriques préservant la confidentialité de la durée totale du set
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.accentCyan)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(stats.totalTracksCount)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("morceaux joués")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "circle.grid.cross.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(stats.keyDistribution.count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("tonalités jouées")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "guitars")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(stats.topGenres.count)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("genres explorés")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Morceaux joués
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.accentCyan)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(stats.totalTracksCount)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("morceaux joués")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Temps moyen par morceau
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stats.totalTracksCount > 0 ? formatMinutesSeconds(stats.averageTimePerTrackSeconds) : "--")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("temps / track")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Rotation horaire
                    HStack(spacing: 6) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(stats.totalTracksCount > 0 ? String(format: "%.1f", stats.tracksPerHour) : "--")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("tracks / heure")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        
        return HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.16))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.4), lineWidth: 0.8)
        )
    }
    
    // MARK: - 3. Grille des Indicateurs
    
    private var metricsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(
                icon: "speedometer",
                iconColor: .orange,
                title: "BPM MOYEN DU SET",
                mainValue: stats.averageBpm > 0 ? String(format: "%.1f", stats.averageBpm) : "--",
                unit: "BPM",
                subtext: stats.minBpm > 0 ? "Plage : \(Int(stats.minBpm.rounded())) - \(Int(stats.maxBpm.rounded())) BPM" : "Aucun BPM détecté"
            )
            
            metricCard(
                icon: "music.quarternote.3",
                iconColor: .purple,
                title: "TONALITÉ DOMINANTE",
                mainValue: stats.dominantKey ?? "--",
                unit: "",
                subtext: stats.dominantKey != nil ? "\(stats.dominantKeyCount) tracks (\(Int(stats.dominantKeyPercentage.rounded()))% du set)" : "Clés non analysées"
            )
            
            metricCard(
                icon: "headphones",
                iconColor: Color.accentCyan,
                title: "GENRE LE PLUS JOUÉ",
                mainValue: stats.mostPlayedGenre?.name ?? "--",
                unit: "",
                subtext: stats.mostPlayedGenre != nil ? "\(stats.mostPlayedGenre!.count) tracks (\(Int(stats.mostPlayedGenre!.percent.rounded()))% du set)" : "En attente des genres"
            )
            
            metricCard(
                icon: "bolt.horizontal.fill",
                iconColor: .yellow,
                title: "TRANSITION LA PLUS RAPIDE",
                mainValue: stats.fastestTransition != nil ? formatMinutesSeconds(stats.fastestTransition!.elapsedSeconds) : "--",
                unit: "",
                subtext: stats.fastestTransition != nil ? "\(stats.fastestTransition!.fromTrack) ➔ \(stats.fastestTransition!.toTrack)" : "2 morceaux requis"
            )
            
            if hideDuration {
                metricCard(
                    icon: "sparkles",
                    iconColor: Color.accentCyan,
                    title: "VARIÉTÉ DES GENRES",
                    mainValue: "\(stats.topGenres.count)",
                    unit: "genres",
                    subtext: "\(stats.topArtists.count) artistes différents explorés"
                )
            } else {
                metricCard(
                    icon: "hare.fill",
                    iconColor: Color.accentCyan,
                    title: "VITESSE DE MIX",
                    mainValue: stats.totalTracksCount > 0 ? String(format: "%.1f", stats.tracksPerHour) : "--",
                    unit: "tracks/h",
                    subtext: stats.totalTracksCount > 0 ? "Cadence moyenne observée" : "En cours d'analyse..."
                )
            }
            
            metricCard(
                icon: "music.note",
                iconColor: Color.accentCyan,
                title: "MORCEAUX DU SET",
                mainValue: stats.totalTracksCount > 0 ? "\(stats.totalTracksCount)" : "--",
                unit: "titres",
                subtext: stats.totalTracksCount > 0 ? "\(stats.totalTracksCount) morceaux joués" : "En attente du mix"
            )
        }
    }
    
    private func metricCard(
        icon: String,
        iconColor: Color,
        title: String,
        mainValue: String,
        unit: String,
        subtext: String
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
                .lineLimit(1)
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
    
    // MARK: - 4. Top Genres
    
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
                        
                        // Barre de progression
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
                        .frame(width: 70, height: 4)
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
    
    // MARK: - 5. Top Artistes
    
    private var topArtistsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    
                    Text("ARTISTES LES PLUS JOUÉS")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(0.5)
                }
                
                Spacer()
                
                if let top1 = stats.mostPlayedArtist {
                    Text("Top 1 : \(top1.name)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.purple)
                }
            }
            
            VStack(spacing: 6) {
                ForEach(Array(stats.topArtists.enumerated()), id: \.element.id) { index, art in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundColor(index == 0 ? .purple : .white.opacity(0.5))
                            .frame(width: 18, alignment: .leading)
                        
                        Text(art.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Barre de progression
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                
                                let ratio = max(0.0, min(1.0, art.percent / 100.0))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.pink.opacity(0.85), Color.purple.opacity(0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(4, min(geo.size.width, geo.size.width * CGFloat(ratio))), height: 4)
                            }
                        }
                        .frame(width: 70, height: 4)
                        .clipped()
                        
                        HStack(spacing: 2) {
                            Text("\(art.count)")
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(.purple)
                            
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
    
    // MARK: - 6. Distribution Harmonique
    
    private var harmonicDistributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.purple)
                
                Text("DISTRIBUTION HARMONIQUE")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(0.5)
            }
            
            HStack(spacing: 8) {
                ForEach(stats.keyDistribution, id: \.key) { item in
                    VStack(spacing: 4) {
                        Text(item.key)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(item.key == stats.dominantKey ? Color.accentCyan : .white)
                        
                        Text("\(item.count) tracks")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 3)
                                
                                let ratio = max(0.0, min(1.0, item.percent / 100.0))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(item.key == stats.dominantKey ? Color.accentCyan : Color.purple)
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
    
    // MARK: - 7. Signature Footer
    
    private var footerBrandingView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(Color.accentCyan)
                
                Text("Généré avec Recall")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
    
    // MARK: - Formatage
    
    private var displaySessionTitle: String {
        if let custom = eventTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return Self.formatFullDayDate(sessionStartTime)
    }
    
    /// Formate la date de manière élégante et complète en français (ex: "Samedi 17 octobre 2026")
    public static func formatFullDayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        let raw = formatter.string(from: date)
        guard let first = raw.first else { return raw }
        return String(first).uppercased() + String(raw.dropFirst())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatHourMinute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH'h'mm"
        return formatter.string(from: date)
    }
    
    private var resolvedSessionEndTime: Date? {
        if let end = sessionEndTime {
            return end
        }
        if stats.totalDurationSeconds > 0 {
            return sessionStartTime.addingTimeInterval(stats.totalDurationSeconds)
        }
        return nil
    }
    
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
    
    private func mixPaceInfo(avgSec: Double, totalTracks: Int) -> (label: String, icon: String, color: Color) {
        guard totalTracks >= 2 else {
            return ("En attente", "hourglass", Color.white.opacity(0.5))
        }
        if avgSec < 45 {
            return ("Quick Mix", "bolt.fill", Color.orange)
        } else if avgSec < 60 {
            return ("Dynamique", "flame.fill", Color.red)
        } else if avgSec < 120 {
            return ("Rythmé", "music.note", Color(hex: "#FF9F43"))
        } else if avgSec < 240 {
            return ("Progressif", "waveform.path", Color.accentCyan)
        } else {
            return ("Deep Blend", "wind", Color.purple)
        }
    }
}
