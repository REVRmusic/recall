import SwiftUI

/// Modale de confirmation pour l'enregistrement ou la suppression d'une combinaison favorite
public struct ComboConfirmationModalView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    let data: ComboConfirmationData
    
    public init(data: ComboConfirmationData) {
        self.data = data
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
                
                // Morceau 1
                trackCard(track: data.trackA, label: "Morceau 1")
                
                // Indicateur de liaison bidirectionnelle
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 8, weight: .bold))
                        Text("Enchaînement bidirectionnel (⇄)")
                            .font(.system(size: 8.5, weight: .semibold))
                    }
                    .foregroundColor(Color.accentCyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.accentCyan.opacity(0.14))
                    .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
                
                // Morceau 2
                trackCard(track: data.trackB, label: "Morceau 2")
                
                // Note explicative rassurante
                Text("Ce combo sera automatiquement proposé dès que l'un des deux morceaux sera joué, peu importe la platine.")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Boutons d'actions
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            monitor.dismissComboConfirmation()
                        }
                    } label: {
                        Text(data.isAlreadySaved ? "Conserver" : "Annuler")
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
                            monitor.confirmPendingCombo()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: data.isAlreadySaved ? "trash" : "heart.fill")
                                .font(.system(size: 9.5, weight: .bold))
                            Text(data.isAlreadySaved ? "Retirer des favoris" : "Enregistrer le match")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            data.isAlreadySaved ?
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
    
    private func trackCard(track: Track, label: String) -> some View {
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
            
            Spacer(minLength: 4)
            
            HStack(spacing: 3) {
                if let camelot = track.camelotKey {
                    Text(camelot.code)
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
