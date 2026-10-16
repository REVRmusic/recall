import SwiftUI
import AppKit

/// Vue du bandeau compact réduit affiché sur la droite de l'écran
public struct BandeauCompactView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    @ObservedObject var toPlayService: ToPlayService = .shared
    
    public init() {}
    
    /// Premier match suggéré pour le morceau en cours (selon les filtres actifs)
    private var topSuggestion: Track? {
        if settings.isToPlayFilterActive {
            var list = toPlayService.toTrackList(referenceTrack: monitor.currentTrack)
            if settings.isHarmonicFilterActive, monitor.currentTrack != nil {
                list = list.filter { $0.harmonicRelation?.isCompatible == true }
            }
            if settings.isBpmFilterActive, let currentBpm = monitor.currentTrack?.bpm, currentBpm > 0 {
                let tolPercent = settings.bpmTolerancePercent / 100.0
                list = list.filter { track in
                    guard track.bpm > 0 else { return false }
                    let ratio1 = track.bpm / currentBpm
                    if abs(ratio1 - 1.0) <= tolPercent { return true }
                    let ratio2 = (track.bpm / 2.0) / currentBpm
                    if abs(ratio2 - 1.0) <= tolPercent { return true }
                    let ratio3 = (track.bpm * 2.0) / currentBpm
                    if abs(ratio3 - 1.0) <= tolPercent { return true }
                    return false
                }
            }
            if settings.hidePlayedTracks {
                list = list.filter { !$0.isPlayedInSession }
            }
            return list.first
        }
        
        var list = settings.isFavoritesFilterActive ? monitor.favoriteSuggestions : monitor.historySuggestions
        
        if settings.isHarmonicFilterActive {
            list = list.filter { $0.harmonicRelation?.isCompatible == true }
        }
        
        if settings.isBpmFilterActive, let currentBpm = monitor.currentTrack?.bpm, currentBpm > 0 {
            let tolPercent = settings.bpmTolerancePercent / 100.0
            list = list.filter { track in
                guard track.bpm > 0 else { return false }
                let ratio1 = track.bpm / currentBpm
                if abs(ratio1 - 1.0) <= tolPercent { return true }
                let ratio2 = (track.bpm / 2.0) / currentBpm
                if abs(ratio2 - 1.0) <= tolPercent { return true }
                let ratio3 = (track.bpm * 2.0) / currentBpm
                if abs(ratio3 - 1.0) <= tolPercent { return true }
                return false
            }
        }
        
        if settings.hidePlayedTracks {
            list = list.filter { !$0.isPlayedInSession }
        }
        
        return list.first
    }
    
    public var body: some View {
        HStack(spacing: 7) {
            // 1. Icône officielle de l'application Recall (vinyle)
            AppIconMiniView()
            
            // 2. Premier match suggéré (au lieu du morceau en cours)
            VStack(alignment: .leading, spacing: 2) {
                if let match = topSuggestion {
                    HStack(spacing: 4) {
                        Text(settings.isToPlayFilterActive ? "#1 À JOUER" : "#1")
                            .font(.system(size: 8.5, weight: .black, design: .rounded))
                            .foregroundColor(settings.isToPlayFilterActive ? Color(hex: "#FFB300") : Color.accentCyan)
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 0.5)
                            .background((settings.isToPlayFilterActive ? Color(hex: "#FFB300") : Color.accentCyan).opacity(0.2))
                            .cornerRadius(3)
                            .fixedSize(horizontal: true, vertical: false)
                        
                        Text(match.displayTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(
                                match.isPlayedInSession && settings.playedTrackHighlightStyle != .bgOnly ?
                                    settings.playedTrackColor :
                                    .white
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(match.fullTooltip)
                    
                    HStack(spacing: 4) {
                        if !match.displayArtist.isEmpty && match.displayArtist != "Artiste inconnu" {
                            Text(match.displayArtist)
                                .font(.system(size: 8.5))
                                .foregroundColor(
                                    match.isPlayedInSession && settings.playedTrackHighlightStyle != .bgOnly ?
                                        settings.playedTrackColor.opacity(0.70) :
                                        .white.opacity(0.55)
                                )
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        
                        // Badge Déjà Joué (strictement sur une ligne)
                        if match.isPlayedInSession {
                            HStack(spacing: 1.5) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 5.5, weight: .black))
                                Text("JOUÉ")
                                    .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(settings.playedTrackColor)
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 0.5)
                            .background(settings.playedTrackColor.opacity(0.20))
                            .cornerRadius(2.5)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Badge Favori
                        if match.isFavorite {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 6))
                                Text("FAV")
                                    .font(.system(size: 7, weight: .black, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "#FF5252"))
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 0.5)
                            .background(Color(hex: "#FF5252").opacity(0.2))
                            .cornerRadius(2.5)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Badge Compteur d'enchaînements historiques
                        if match.transitionCount > 0 {
                            HStack(spacing: 1.5) {
                                if match.transitionCount >= 3 {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 6.5))
                                        .foregroundColor(Color.accentFire)
                                }
                                Text("\(match.transitionCount)x")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(match.transitionCount >= 3 ? Color.accentFire : Color.accentCyan)
                            }
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 0.5)
                            .background((match.transitionCount >= 3 ? Color.accentFire : Color.accentCyan).opacity(0.18))
                            .cornerRadius(2.5)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Badge Clé Camelot / Musicale
                        if let camelot = match.camelotKey {
                            Text(camelot.displayText(mode: settings.keyDisplayMode))
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 0.5)
                                .background(camelot.color.opacity(0.25))
                                .foregroundColor(camelot.color)
                                .cornerRadius(2.5)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        
                        // Badge BPM
                        Text("\(match.displayBpm) BPM")
                            .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 0.5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(2.5)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else if settings.isToPlayFilterActive {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aucun morceau à jouer")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Color(hex: "#FFB300"))
                        Text("Glissez un morceau ici")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.45))
                    }
                } else if monitor.currentTrack != nil {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Aucun match disponible")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Dépliez pour rechercher")
                            .font(.system(size: 8.5))
                            .foregroundColor(.white.opacity(0.45))
                    }
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.accentCyan)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Lancer la lecture")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                            Text("Démarrez un morceau sur Serato")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .help(topSuggestion != nil ?
                  "Match n°1 pour « \(monitor.currentTrack?.displayTitle ?? "") » (Glisser vers Serato)" :
                  "En attente de suggestions")
            // Support natif du Drag & Drop du match n°1 vers Serato DJ Pro directement depuis le bandeau !
            .onDrag {
                guard let match = topSuggestion,
                      let path = match.filePath,
                      FileManager.default.fileExists(atPath: path) else {
                    return NSItemProvider()
                }
                let url = URL(fileURLWithPath: path)
                return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL)
            }
            
            Spacer(minLength: 2)
            
            // 2.5 Bouton de sauvegarde rapide du combo actif si 2 platines
            if let d1 = monitor.deck1Track, let d2 = monitor.deck2Track,
               FavoriteCombosService.normalize(d1.displayTitle) != FavoriteCombosService.normalize(d2.displayTitle) {
                let isFav = FavoriteCombosService.shared.isComboFavorite(track1: d1, track2: d2)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if settings.isCompactMode {
                            settings.isCompactMode = false
                            FloatingWindowController.shared.toggleCompactMode(false)
                        }
                        monitor.requestComboConfirmation(trackA: d1, trackB: d2, source: "Deck 1 ⇄ Deck 2")
                    }
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(isFav ? Color(hex: "#FF5252") : .white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(isFav ? Color(hex: "#FF5252").opacity(0.25) : Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isFav ? "Combo Deck 1 ⇄ Deck 2 enregistré !" : "Sauvegarder ce combo Deck 1 ⇄ Deck 2")
            }
            
            // Bouton de réinitialisation de session rapide
            SessionResetHeaderButton()
            
            // 3. Bouton TRÈS VISIBLE "Déplier" pour restaurer la fenêtre complète
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    settings.isCompactMode = false
                    FloatingWindowController.shared.toggleCompactMode(false)
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.to.line")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Déplier")
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.accentCyan.opacity(0.2))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.accentCyan.opacity(0.65), lineWidth: 1)
                    )
                    
                    Image(systemName: "arrow.left.to.line")
                        .font(.system(size: 9.5, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.accentCyan.opacity(0.2))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentCyan.opacity(0.65), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Déplier la fenêtre Recall complète")
            
            // 4. Bouton Fermer Recall
            CloseHeaderButton()
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .overlay(
            Group {
                if toPlayService.isDraggingFileOver {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentCyan.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.accentCyan, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        )
                        .overlay(
                            HStack(spacing: 5) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.accentCyan)
                                Text("Ajouter aux morceaux à jouer")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        )
                }
            }
        )
    }
}

/// Mini affichage de l'icône vinyle pour le bandeau
private struct AppIconMiniView: View {
    private var appIcon: NSImage? {
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: path) {
            return icon
        }
        return NSApp.applicationIconImage
    }
    
    var body: some View {
        Group {
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Circle()
                    .fill(Color.accentCyan)
                    .frame(width: 22, height: 22)
            }
        }
    }
}
