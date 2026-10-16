import SwiftUI
import AppKit

/// Bandeau discret affiché au premier plan lorsqu'une mise à jour de Recall est disponible
public struct UpdateBannerView: View {
    @ObservedObject var updater: AutoUpdateService = .shared
    let release: GitHubRelease
    
    @State private var isHovered: Bool = false
    
    public init(release: GitHubRelease) {
        self.release = release
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Icône animée / halo
            ZStack {
                Circle()
                    .fill(Color.accentCyan.opacity(0.25))
                    .frame(width: 20, height: 20)
                Image(systemName: "sparkles")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Color.accentCyan)
            }
            
            // Texte d'annonce
            HStack(spacing: 4) {
                Text("Nouvelle version")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                
                Text(release.tagName)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.accentCyan)
            }
            .lineLimit(1)
            
            Spacer(minLength: 4)
            
            // Bouton Télécharger direct
            Button {
                updater.openDownload()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("Télécharger")
                        .font(.system(size: 9.5, weight: .heavy))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.accentCyan)
                .cornerRadius(4)
                .shadow(color: Color.accentCyan.opacity(0.4), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Télécharger la dernière version (\(release.tagName))")
            
            // Bouton Fermer / Plus tard
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    updater.dismissBanner()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Masquer pour cette session")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentCyan.opacity(0.18),
                            Color.cardBg.opacity(0.92)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.accentCyan.opacity(0.45), lineWidth: 0.8)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}
