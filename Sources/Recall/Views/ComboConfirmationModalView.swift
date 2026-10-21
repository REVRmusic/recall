import SwiftUI

/// Modale de confirmation pour l'enregistrement ou la suppression d'une combinaison favorite
public struct ComboConfirmationModalView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @ObservedObject private var settings = UserSettings.shared
    let data: ComboConfirmationData
    @State private var linkDirection: FavoriteLinkDirection
    @State private var hoveredDirection: FavoriteLinkDirection?
    
    public init(data: ComboConfirmationData) {
        self.data = data
        _linkDirection = State(initialValue: data.savedDirection ?? .forward)
    }
    
    /// Sens déjà enregistré, dans l'ordre affiché. Les anciens favoris sont bidirectionnels.
    private var savedDirection: FavoriteLinkDirection {
        data.savedDirection ?? .both
    }
    
    /// Le bouton rouge retire le favori seulement si le sens affiché n'a pas changé.
    private var primaryIsRemoval: Bool {
        data.isAlreadySaved && linkDirection == savedDirection
    }
    
    private var dismissTitle: String {
        data.isAlreadySaved && linkDirection == savedDirection ? "Conserver" : "Annuler"
    }
    
    private var primaryTitle: String {
        if !data.isAlreadySaved { return "Enregistrer le match" }
        if primaryIsRemoval { return "Retirer des favoris" }
        return "Enregistrer le sens"
    }
    
    private var directionCaption: String {
        switch linkDirection {
        case .forward:
            return "Quand le morceau 1 passe, Recall propose le morceau 2."
        case .reverse:
            return "Quand le morceau 2 passe, Recall propose le morceau 1."
        case .both:
            return "Quand l'un des deux passe, Recall propose l'autre."
        }
    }
    
    public var body: some View {
        ZStack {
            // Fond noir dépoli cliquable pour annuler
            Color.black.opacity(0.65)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        monitor.dismissComboConfirmation()
                    }
                }
            
            // Boîte modale centrée
            VStack(spacing: 11) {
                // En-tête
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FF5252").opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#FF5252"))
                    }
                    
                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(data.isAlreadySaved ? "Gérer ce combo favori" : "Confirmer le match favori")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(data.sourceDescription ?? "Association de deux morceaux")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            monitor.dismissComboConfirmation()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                // Morceau 1 (haut de la lecture affichée)
                trackCard(track: data.trackA, isSource: true)
                
                directionControl
                
                // Morceau 2
                trackCard(track: data.trackB, isSource: false)
                
                Text(directionCaption)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.16), value: linkDirection)
                
                // Boutons d'actions
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            monitor.dismissComboConfirmation()
                        }
                    } label: {
                        Text(dismissTitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            if primaryIsRemoval {
                                monitor.removePendingCombo()
                            } else {
                                monitor.confirmPendingCombo(direction: linkDirection)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: primaryIsRemoval ? "trash" : "heart.fill")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(primaryTitle)
                                .font(.system(size: 10.5, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            primaryIsRemoval ?
                                Color(hex: "#FF5252").opacity(0.85) :
                                Color(hex: "#FF5252")
                        )
                        .cornerRadius(6)
                        .shadow(color: Color(hex: "#FF5252").opacity(0.35), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 3)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkBg.opacity(0.98))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FF5252").opacity(0.6),
                            Color.white.opacity(0.15),
                            Color.accentCyan.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .frame(width: 320)
            .shadow(color: Color.black.opacity(0.7), radius: 24, x: 0, y: 12)
        }
    }
    
    private var directionIcon: String {
        switch linkDirection {
        case .forward: return "arrow.down"
        case .both: return "arrow.triangle.swap"
        case .reverse: return "arrow.up"
        }
    }
    
    private var directionTitle: String {
        switch linkDirection {
        case .forward: return "Sens direct (1 ➔ 2)"
        case .both: return "Enchaînement bidirectionnel (⇄)"
        case .reverse: return "Sens inverse (2 ➔ 1)"
        }
    }
    
    private var directionColor: Color {
        switch linkDirection {
        case .forward: return Color.accentCyan
        case .both: return Color(hex: "#FF9E14")
        case .reverse: return Color(hex: "#AF52DE")
        }
    }
    
    private var directionControl: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    switch linkDirection {
                    case .forward: linkDirection = .both
                    case .both: linkDirection = .reverse
                    case .reverse: linkDirection = .forward
                    }
                }
            } label: {
                HStack(spacing: 4.5) {
                    Image(systemName: directionIcon)
                        .font(.system(size: 8.5, weight: .bold))
                    Text(directionTitle)
                        .font(.system(size: 8.5, weight: .bold))
                }
                .foregroundColor(directionColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(directionColor.opacity(0.15))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(directionColor.opacity(0.40), lineWidth: 0.8)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Cliquer pour changer le sens : Sens direct (1 ➔ 2), Bidirectionnel (⇄) ou Sens inverse (2 ➔ 1)")
            .contextMenu {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        linkDirection = .forward
                    }
                } label: {
                    Label("Sens direct (1 ➔ 2)", systemImage: "arrow.down")
                }
                
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        linkDirection = .both
                    }
                } label: {
                    Label("Enchaînement bidirectionnel (⇄)", systemImage: "arrow.triangle.swap")
                }
                
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        linkDirection = .reverse
                    }
                } label: {
                    Label("Sens inverse (2 ➔ 1)", systemImage: "arrow.up")
                }
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
    }
    
    private func trackCard(track: Track, isSource: Bool) -> some View {
        HStack(spacing: 8) {
            // Vinyle miniature avec centre Camelot
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.7))
                    .frame(width: 26, height: 26)
                Circle()
                    .fill(track.camelotKey?.color.opacity(0.85) ?? Color.accentCyan)
                    .frame(width: 9, height: 9)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(track.displayTitle)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.displayArtist)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }
            .help(track.fullTooltip)
            
            Spacer(minLength: 4)
            
            HStack(spacing: 3) {
                if let camelot = track.camelotKey {
                    Text(camelot.displayText(mode: settings.keyDisplayMode))
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(camelot.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(camelot.color.opacity(0.2))
                        .cornerRadius(3)
                }
                
                if track.bpm > 0 {
                    Text("\(track.displayBpm)")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(3)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }
}
