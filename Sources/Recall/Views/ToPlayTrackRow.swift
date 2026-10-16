import SwiftUI
import AppKit

/// Ligne d'affichage d'un morceau de la liste des morceaux à jouer prochainement
/// Comprend la petite poubelle pour suppression immédiate et le support du glisser vers Serato
public struct ToPlayTrackRow: View {
    let track: Track
    let rank: Int
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    
    @State private var isHovered: Bool = false
    @State private var isTrashHovered: Bool = false
    
    public init(track: Track, rank: Int) {
        self.track = track
        self.rank = rank
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // 1. Rang & Petite poubelle de suppression
            HStack(spacing: 4) {
                Text("\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(rank <= 3 ? Color(hex: "#FFB300") : .white.opacity(0.40))
                    .frame(width: 14, alignment: .trailing)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        ToPlayService.shared.removeTrack(id: track.id)
                    }
                } label: {
                    Image(systemName: isTrashHovered ? "trash.fill" : "trash")
                        .font(.system(size: 8.5))
                        .foregroundColor(isTrashHovered ? Color(hex: "#FF5252") : Color.white.opacity(0.30))
                        .frame(width: 18, height: 18)
                        .background(isTrashHovered ? Color(hex: "#FF5252").opacity(0.18) : Color.white.opacity(0.04))
                        .cornerRadius(3.5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { isTrashHovered = $0 }
                .help("Retirer de ma Sélec")
            }
            
            // 2. Infos Titre & Artiste
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
                
                if !track.displayArtist.isEmpty {
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
            }
            .contentShape(Rectangle())
            .help("Glisser vers une platine Serato pour charger ce morceau")
            
            Spacer(minLength: 4)
            
            // 3. Badges Métriques (Déjà Joué, Clé Camelot, BPM)
            HStack(spacing: 3.5) {
                // Badge Déjà Joué dans la session en cours
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
                    .help("Déjà joué lors de votre session en cours")
                }
                
                // Badge Clé Harmonique Camelot
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
                            Text(rel.badgeText)
                                .font(.system(size: 6.5, weight: .bold))
                                .foregroundColor(camelot.color.opacity(0.85))
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
                
                // Badge BPM avec écart relatif
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
                        Color(hex: "#FFB300").opacity(0.65) :
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
        .help("Glisser vers Serato pour jouer ce morceau")
        // Support du glisser natif direct sur l'intégralité de la card
        .onDrag {
            guard let path = track.filePath, FileManager.default.fileExists(atPath: path) else {
                return NSItemProvider()
            }
            let url = URL(fileURLWithPath: path)
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
        }
    }
    
    // MARK: - Explications au survol
    
    private func camelotTooltip(for track: Track) -> String {
        guard let camelot = track.camelotKey else { return track.rawKey }
        var tip = "Clé Camelot \(camelot.code) (\(camelot.musicalName))"
        if let rel = track.harmonicRelation {
            switch rel {
            case .exact:
                tip += " • Même tonalité (harmonie parfaite)"
            case .adjacent:
                tip += " • Clé adjacente (transition fluide)"
            case .relative:
                tip += " • Clé relative (Majeur ⇄ Mineur)"
            case .energyBoost:
                tip += " • +2 Boost d'énergie harmonique"
            case .energyDrop:
                tip += " • -2 Descente d'énergie"
            case .incompatible:
                tip += " • Clé différente"
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
            tip += " (Écart : \(displayBpmDiff(diff)) BPM avec le morceau en cours)"
        }
        return tip
    }
}
