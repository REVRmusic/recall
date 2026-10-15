import SwiftUI

public struct HeaderView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    
    @Binding var showSettings: Bool
    @Binding var showSearch: Bool
    @Binding var showGuide: Bool
    
    public init(showSettings: Binding<Bool>, showSearch: Binding<Bool>, showGuide: Binding<Bool>) {
        self._showSettings = showSettings
        self._showSearch = showSearch
        self._showGuide = showGuide
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            // Logo et Nom Recall positionnés nettement tout en haut à gauche
            HStack(spacing: 3) {
                // Véritable icône de l'application Recall (vinyle avec centre dégradé cyan/bleu)
                AppIconImageView()
                
                Text("Recall")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
                
                // Bouton Nouvelle session / Remise à zéro des morceaux déjà joués
                SessionResetHeaderButton()
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.leading, 1)
            
            Spacer(minLength: 2)
            
            // Boutons d'actions épurés à droite (adaptatifs selon la largeur disponible)
            HStack(spacing: 2.5) {
                // Bouton Réduire : texte + icône si large, ou icône seule si fenêtre étroite
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        settings.isCompactMode = true
                        FloatingWindowController.shared.toggleCompactMode(true)
                    }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right.to.line")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Réduire")
                                .font(.system(size: 9.5, weight: .heavy))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(Color.accentCyan.opacity(0.18))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.accentCyan.opacity(0.65), lineWidth: 1)
                        )
                        
                        Image(systemName: "arrow.right.to.line")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.accentCyan)
                            .frame(width: 21, height: 21)
                            .background(Color.accentCyan.opacity(0.18))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.accentCyan.opacity(0.65), lineWidth: 0.8)
                            )
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Réduire Recall en petit bandeau sur la droite de l'écran")
                
                // Bouton Recherche dans la bibliothèque
                Button {
                    showSearch.toggle()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(monitor.manualTrackOverride != nil ? Color.accentCyan : .white.opacity(0.75))
                        .frame(width: 21, height: 21)
                        .background(monitor.manualTrackOverride != nil ? Color.accentCyan.opacity(0.2) : Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Rechercher un morceau manuellement dans Serato")
                
                // Bouton Guide & Légende explicative (?)
                Button {
                    showGuide.toggle()
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 21, height: 21)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Guide et légende des symboles (enchaînements, clés Camelot, BPM)")
                
                // Bouton Épingler au premier plan (Always-On-Top)
                Button {
                    settings.alwaysOnTop.toggle()
                    FloatingWindowController.shared.updateAlwaysOnTop(settings.alwaysOnTop)
                } label: {
                    Image(systemName: settings.alwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(settings.alwaysOnTop ? Color.accentCyan : .white.opacity(0.5))
                        .frame(width: 21, height: 21)
                        .background(settings.alwaysOnTop ? Color.accentCyan.opacity(0.2) : Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help(settings.alwaysOnTop ? "Toujours au premier plan (Actif)" : "Premier plan désactivé")
                
                // Bouton Paramètres
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 21, height: 21)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .help("Paramètres d'historique et filtres")
                
                // Bouton Fermer Recall élégant
                CloseHeaderButton()
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 8)
        .padding(.bottom, 5)
        .frame(height: 38)
    }
}

/// Bouton de fermeture ultra moderne et discret avec effet de survol
struct CloseHeaderButton: View {
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundColor(isHovered ? .white : .white.opacity(0.6))
                .frame(width: 21, height: 21)
                .background(isHovered ? Color.red.opacity(0.75) : Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Quitter Recall")
    }
}

/// Affiche la véritable icône de l'application Recall (vinyle avec centre dégradé cyan/bleu)
struct AppIconImageView: View {
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
                    .frame(width: 21, height: 21)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5))
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentCyan, Color.accentBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 21, height: 21)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 10.5, weight: .black))
                        .foregroundColor(.black)
                }
            }
        }
    }
}

/// Bouton tactile et élégant pour réinitialiser la session en cours et démarrer un nouveau set
struct SessionResetHeaderButton: View {
    @ObservedObject private var sessionService = SessionHistoryService.shared
    @State private var showFeedback: Bool = false
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sessionService.resetSession()
                showFeedback = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation {
                    showFeedback = false
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 3) {
                    if showFeedback {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(Color.accentGreen)
                        Text("Reset")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(Color.accentGreen)
                    } else {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(sessionService.playedCount > 0 ? Color.accentCyan : .white.opacity(isHovered ? 0.85 : 0.45))
                        
                        if sessionService.playedCount > 0 {
                            Text("\(sessionService.playedCount)")
                                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                                .foregroundColor(Color.accentCyan)
                        }
                    }
                }
                .padding(.horizontal, sessionService.playedCount > 0 || showFeedback ? 6 : 5)
                .frame(height: 20)
                .background(
                    showFeedback ? Color.accentGreen.opacity(0.18) :
                    (sessionService.playedCount > 0 ? Color.accentCyan.opacity(0.16) : Color.white.opacity(isHovered ? 0.08 : 0.04))
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            showFeedback ? Color.accentGreen.opacity(0.6) :
                            (sessionService.playedCount > 0 ? Color.accentCyan.opacity(0.45) : Color.white.opacity(0.08)),
                            lineWidth: 0.8
                        )
                )
                
                Image(systemName: showFeedback ? "checkmark" : "arrow.counterclockwise")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(showFeedback ? Color.accentGreen : (sessionService.playedCount > 0 ? Color.accentCyan : .white.opacity(isHovered ? 0.85 : 0.45)))
                    .frame(width: 20, height: 20)
                    .background(
                        showFeedback ? Color.accentGreen.opacity(0.18) :
                        (sessionService.playedCount > 0 ? Color.accentCyan.opacity(0.16) : Color.white.opacity(isHovered ? 0.08 : 0.04))
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                showFeedback ? Color.accentGreen.opacity(0.6) :
                                (sessionService.playedCount > 0 ? Color.accentCyan.opacity(0.45) : Color.white.opacity(0.08)),
                                lineWidth: 0.8
                            )
                    )
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .help(sessionService.playedCount > 0 ?
              "Démarrer une nouvelle session : Remettre à zéro les morceaux déjà joués (\(sessionService.playedCount) joués ce soir)" :
              "Démarrer une nouvelle session : Remettre à zéro l'historique des morceaux joués")
    }
}

