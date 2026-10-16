import SwiftUI

public struct NowPlayingCard: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    @ObservedObject var rekordboxService: RekordboxService = .shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 6) {
            // En-tête de carte unifiée : label + sélecteurs de Deck intégrés
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(monitor.currentTrack != nil ? Color.accentCyan : Color.white.opacity(0.35))
                        .frame(width: 5, height: 5)
                    
                    Text(monitor.currentTrack != nil ? "EN COURS" : "EN ATTENTE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(monitor.currentTrack != nil ? Color.accentCyan : .white.opacity(0.55))
                        .tracking(1.0)
                }
                
                Spacer()
                
                // Sélecteurs de platines ou statut Rekordbox
                HStack(spacing: 3) {
                    if monitor.activeDJSoftware == .rekordbox {
                        if !rekordboxService.isAccessibilityGranted {
                            Button {
                                rekordboxService.openAccessibilityPreferences()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 7, weight: .bold))
                                    Text("ACCÈS REQUIS")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentOrange.opacity(0.25))
                                .foregroundColor(Color.accentOrange)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .help("Cliquez pour autoriser Recall dans Réglages Système > Confidentialité et sécurité > Accessibilité")
                        } else {
                            Text("REKORDBOX")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentCyan.opacity(0.18))
                                .foregroundColor(Color.accentCyan)
                                .cornerRadius(4)
                        }
                    }
                    
                    deckPill(label: "AUTO", isSelected: monitor.activeDeckSelection == "AUTO") {
                        monitor.selectDeck("AUTO")
                    }
                    
                    if monitor.deck1Track != nil {
                        deckPill(label: "DECK 1", isSelected: monitor.activeDeckSelection == "1") {
                            monitor.selectDeck("1")
                        }
                    }
                    
                    if monitor.deck2Track != nil {
                        deckPill(label: "DECK 2", isSelected: monitor.activeDeckSelection == "2") {
                            monitor.selectDeck("2")
                        }
                    }
                    
                    if monitor.manualTrackOverride != nil {
                        Button {
                            monitor.clearManualOverride()
                        } label: {
                            HStack(spacing: 2) {
                                Text("MANUEL")
                                    .font(.system(size: 8, weight: .bold))
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentOrange.opacity(0.25))
                            .foregroundColor(Color.accentOrange)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Corps de la carte : Morceau actif ou attente
            if let track = monitor.currentTrack {
                HStack(spacing: 10) {
                    // Vinyle avec centre coloré selon la clé Camelot
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        
                        // Sillon vinyle
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            .frame(width: 26, height: 26)
                        
                        // Macaron central avec la couleur Camelot
                        Circle()
                            .fill(track.camelotKey?.color.opacity(0.85) ?? Color.accentCyan)
                            .frame(width: 12, height: 12)
                        
                        Circle()
                            .fill(Color.black)
                            .frame(width: 4, height: 4)
                    }
                    
                    // Titre & Artiste
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.displayTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Text(track.displayArtist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .help(track.fullTooltip)
                    
                    Spacer(minLength: 8)
                    
                    // Badges Clé Camelot & BPM
                    VStack(alignment: .trailing, spacing: 4) {
                        // Badge Clé Camelot (couleurs authentiques Serato)
                        if let camelot = track.camelotKey {
                            HStack(spacing: 3) {
                                if settings.keyDisplayMode == 1 {
                                    Text(camelot.musicalName)
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                } else if settings.keyDisplayMode == 2 {
                                    Text(camelot.code)
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    Text("(\(camelot.musicalName))")
                                        .font(.system(size: 8, weight: .medium))
                                } else {
                                    Text(camelot.code)
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(camelot.color.opacity(0.25))
                            .foregroundColor(camelot.color)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(camelot.color.opacity(0.6), lineWidth: 1)
                            )
                        } else if !track.rawKey.isEmpty {
                            Text(track.rawKey)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(5)
                        }
                        
                        // Badge BPM
                        Text("\(track.displayBpm) BPM")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(4)
                    }
                }
                
                // Bouton d'enregistrement de combinaison bien visible (sans description surchargée)
                if let d1 = monitor.deck1Track, let d2 = monitor.deck2Track,
                   FavoriteCombosService.normalize(d1.displayTitle) != FavoriteCombosService.normalize(d2.displayTitle) {
                    comboSaveButton(trackA: d1, trackB: d2, labelPrefix: "Deck 1 ⇄ Deck 2")
                } else if let prev = monitor.previousTrack, let curr = monitor.currentTrack,
                          FavoriteCombosService.normalize(prev.displayTitle) != FavoriteCombosService.normalize(curr.displayTitle) {
                    comboSaveButton(trackA: prev, trackB: curr, labelPrefix: "Enchaînement récent")
                }
            } else {
                // État lorsqu'aucun morceau n'est en cours de lecture
                if monitor.activeDJSoftware == .rekordbox && !rekordboxService.isAccessibilityGranted {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.accentOrange.opacity(0.18))
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(Color.accentOrange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Autorisation requise pour Rekordbox")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Pour détecter vos platines en direct, autorisez Recall dans Réglages Système > Accessibilité (si déjà coché, décochez puis recochez).")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        Button {
                            rekordboxService.openAccessibilityPreferences()
                        } label: {
                            Text("Activer")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentOrange.opacity(0.25))
                                .foregroundColor(Color.accentOrange)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.accentCyan.opacity(0.18))
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(Color.accentCyan)
                                .offset(x: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lancer la lecture")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(monitor.activeDJSoftware == .rekordbox ? "Lancez un morceau sur Deck 1 ou Deck 2 dans Rekordbox pour afficher les suggestions." : "Démarrez un morceau sur Deck 1 ou Deck 2 dans Serato DJ Pro pour afficher les suggestions.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(10)
        .background(Color.cardBg.opacity(min(0.85, 0.20 + (1.0 - settings.glassTranslucency) * 0.65)))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
    
    private func deckPill(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isSelected ? Color.accentCyan.opacity(0.3) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? Color.accentCyan : Color.white.opacity(0.6))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
    
    private func comboSaveButton(trackA: Track, trackB: Track, labelPrefix: String) -> some View {
        let isSaved = FavoriteCombosService.shared.isComboFavorite(track1: trackA, track2: trackB)
        
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                monitor.requestComboConfirmation(trackA: trackA, trackB: trackB, source: labelPrefix)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 10, weight: .bold))
                
                Text(isSaved ? "Combo en favoris" : "Sauvegarder ce combo")
                    .font(.system(size: 10, weight: .bold))
                
                if isSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .heavy))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                isSaved ?
                    Color(hex: "#FF5252").opacity(0.20) :
                    Color(hex: "#FF5252").opacity(0.12)
            )
            .foregroundColor(isSaved ? Color(hex: "#FF5252") : Color(hex: "#FF7675"))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSaved ? Color(hex: "#FF5252").opacity(0.7) : Color(hex: "#FF5252").opacity(0.4),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 3)
        .help(isSaved ? "Combinaison enregistrée dans vos favoris (cliquez pour gérer)" : "Sauvegarder l'enchaînement de ces deux morceaux en favori")
    }
}
