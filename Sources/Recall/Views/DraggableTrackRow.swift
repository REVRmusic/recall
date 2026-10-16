import SwiftUI
import AppKit

public struct DraggableTrackRow: View {
    let track: Track
    let rank: Int
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    
    @State private var isHovered: Bool = false
    
    public init(track: Track, rank: Int) {
        self.track = track
        self.rank = rank
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Numéro de classement (#1, #2, ...) avec bouton de favori rapide au survol
            HStack(spacing: 2) {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        track.isPlayedInSession && settings.playedTrackHighlightStyle != .bgOnly ?
                            settings.playedTrackColor :
                            (rank <= 3 ? Color.accentCyan.opacity(0.85) : .white.opacity(0.35))
                    )
                    .frame(width: 14, alignment: .trailing)
                
                Button {
                    if let current = monitor.currentTrack {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            monitor.requestComboConfirmation(
                                trackA: current,
                                trackB: track,
                                source: "En cours ⇄ Morceau suggéré"
                            )
                        }
                    }
                } label: {
                    Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 9))
                        .foregroundColor(track.isFavorite ? Color(hex: "#FF5252") : (isHovered ? .white.opacity(0.65) : Color.white.opacity(0.15)))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(track.isFavorite ? "Gérer cette combinaison favorite" : "Ajouter cette combinaison aux favoris")
            }
            
            // Infos Titre & Artiste (plus d'espace horizontal disponible)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(track.displayTitle)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(
                            track.isPlayedInSession && settings.playedTrackHighlightStyle != .bgOnly ?
                                settings.playedTrackColor :
                                .white
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if !track.isFileAvailable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                            .help("Fichier audio non trouvé sur le disque local")
                    }
                }
                
                Text(track.displayArtist)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundColor(
                        track.isPlayedInSession && settings.playedTrackHighlightStyle != .bgOnly ?
                            settings.playedTrackColor.opacity(0.70) :
                            .white.opacity(0.55)
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .contentShape(Rectangle())
            .help(track.fullTooltip)
            
            Spacer(minLength: 4)
            
            // Métriques (Déjà Joué, Favori, Fréquence d'enchaînement, Clé Camelot Serato, BPM)
            HStack(spacing: 3.5) {
                // Badge Déjà Joué dans la session en cours (strictement sur une seule ligne)
                if track.isPlayedInSession {
                    HStack(spacing: 2.5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 6.5, weight: .black))
                        Text("JOUÉ")
                            .font(.system(size: 7, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(settings.playedTrackColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(settings.playedTrackColor.opacity(0.20))
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(settings.playedTrackColor.opacity(0.55), lineWidth: 0.8)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Déjà joué lors de votre session en cours (durée > \(settings.playedMinDurationSeconds)s)")
                }
                
                // Badge Combinaison Favorite
                if track.isFavorite {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 6))
                        Text("FAV")
                            .font(.system(size: 7.5, weight: .black, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color(hex: "#FF5252"))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color(hex: "#FF5252").opacity(0.2))
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(hex: "#FF5252").opacity(0.6), lineWidth: 0.8)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .help("Combinaison favorite manuelle enregistrée")
                }
                
                // Badge Compteur d'enchaînements historiques (ex: 🔥 8x)
                if track.transitionCount > 0 {
                    HStack(spacing: 2) {
                        if track.transitionCount >= 3 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 7))
                                .foregroundColor(Color.accentFire)
                        }
                        Text("\(track.transitionCount)x")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(track.transitionCount >= 3 ? Color.accentFire : Color.accentCyan)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(
                        (track.transitionCount >= 3 ? Color.accentFire : Color.accentCyan)
                            .opacity(0.18)
                    )
                    .cornerRadius(3)
                    .fixedSize(horizontal: true, vertical: false)
                    .help(transitionTooltip(for: track))
                }
                
                // Badge Clé Harmonique Camelot (couleurs authentiques Serato selon réglages)
                if let camelot = track.camelotKey {
                    VStack(spacing: 0) {
                        if settings.keyDisplayMode == 1 {
                            Text(camelot.musicalName)
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(camelot.color)
                                .lineLimit(1)
                        } else if settings.keyDisplayMode == 2 {
                            HStack(spacing: 2) {
                                Text(camelot.code)
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                Text(camelot.musicalName)
                                    .font(.system(size: 7.5, weight: .semibold))
                            }
                            .foregroundColor(camelot.color)
                            .lineLimit(1)
                        } else {
                            Text(camelot.code)
                                .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(camelot.color)
                                .lineLimit(1)
                        }
                        
                        if let rel = track.harmonicRelation, rel.isCompatible, rel != .exact {
                            HStack(spacing: 1.5) {
                                if rel.isEnergyBoost {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 5.5, weight: .bold))
                                        .foregroundColor(Color(hex: "#FFB300"))
                                    Text(rel.badgeText)
                                        .font(.system(size: 6.5, weight: .heavy))
                                        .foregroundColor(Color(hex: "#FFB300"))
                                } else {
                                    Text(rel.badgeText)
                                        .font(.system(size: 6.5, weight: .bold))
                                        .foregroundColor(camelot.color.opacity(0.85))
                                }
                            }
                            .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(camelot.color.opacity(0.2))
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(camelot.color.opacity(0.5), lineWidth: 0.8)
                    )
                    .fixedSize(horizontal: true, vertical: false)
                    .help(camelotTooltip(for: track))
                }
                
                // Badge BPM avec écart (strictement sur une seule ligne)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(track.displayBpm)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    
                    if let diff = track.bpmDiff, abs(diff) > 0.1 {
                        Text(displayBpmDiff(diff))
                            .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                            .foregroundColor(abs(diff) <= 3.0 ? Color.accentGreen : (abs(diff) <= 8.0 ? Color.accentOrange : Color.gray))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(3)
                .fixedSize(horizontal: true, vertical: true)
                .help(bpmTooltip(for: track))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isHovered ?
                        Color.cardHoverBg :
                        (track.isPlayedInSession && settings.playedTrackHighlightStyle != .textOnly ?
                            settings.playedTrackColor.opacity(0.14) :
                            Color.cardBg.opacity(0.55))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    isHovered ?
                        Color.borderActive :
                        (track.isPlayedInSession && settings.playedTrackHighlightStyle != .textOnly ?
                            settings.playedTrackColor.opacity(0.40) :
                            Color.clear),
                    lineWidth: 1
                )
        )
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help(track.fullTooltip)
        // Support du glisser natif direct sur l'intégralité de la card
        .onDrag {
            guard let path = track.filePath, FileManager.default.fileExists(atPath: path) else {
                return NSItemProvider()
            }
            let url = URL(fileURLWithPath: path)
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        }
    }
    
    // MARK: - Explications détaillées au survol
    
    private func transitionTooltip(for track: Track) -> String {
        let count = track.transitionCount
        let currentTitle = monitor.currentTrack?.displayTitle ?? "le morceau en cours"
        let routineInfo = count >= 3 ? " • Routine favorite 🔥" : ""
        return "Enchaîné \(count) fois juste après « \(currentTitle) » dans vos sets réels\(routineInfo)"
    }
    
    private func camelotTooltip(for track: Track) -> String {
        guard let camelot = track.camelotKey else { return track.rawKey }
        var tip = "Clé Camelot \(camelot.code) (\(camelot.musicalName))"
        if let rel = track.harmonicRelation {
            switch rel {
            case .exact:
                tip += " • Même tonalité (harmonie parfaite)"
            case .adjacent:
                tip += " • Clé voisine ±1 (transition fluide)"
            case .relative:
                tip += " • Clé relative (Majeur ⇄ Mineur)"
            case .semitoneBoost:
                tip += " • ⚡️ Energy Boost +1 demi-ton (+7 Camelot) : montée d'énergie explosive"
            case .wholeToneBoost:
                tip += " • ⚡️ Energy Boost +1 ton (+2 Camelot) : modulation pop/anthem montante"
            case .semitoneDrop:
                tip += " • ❄️ Energy Drop -1 demi-ton (-7 Camelot) : redescente d'énergie"
            case .diagonal:
                tip += " • Diagonale modale (voisine Majeur ⇄ Mineur)"
            case .incompatible:
                tip += " • Tonalité différente"
            }
        }
        return tip
    }
    
    private func displayBpmDiff(_ diff: Double) -> String {
        let sign = diff > 0 ? "+" : ""
        if abs(diff.rounded() - diff) < 0.05 {
            return "\(sign)\(Int(diff.rounded()))"
        }
        return String(format: "%@%.1f", sign, diff)
    }
    
    private func bpmTooltip(for track: Track) -> String {
        var tip = "\(track.displayBpm) BPM"
        if let diff = track.bpmDiff, abs(diff) > 0.05 {
            tip += " (Écart : \(displayBpmDiff(diff)) BPM)"
        }
        return tip
    }
}
