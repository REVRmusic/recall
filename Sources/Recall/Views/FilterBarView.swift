import SwiftUI

public struct FilterBarView: View {
    @EnvironmentObject var settings: UserSettings
    @ObservedObject var toPlayService: ToPlayService = .shared
    let suggestionsCount: Int
    
    public init(suggestionsCount: Int) {
        self.suggestionsCount = suggestionsCount
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            // Filtre BPM ±10%
            filterTogglePill(
                title: "BPM ±10%",
                shortTitle: "BPM",
                icon: "metronome",
                isActive: settings.isBpmFilterActive,
                accentColor: Color.accentCyan
            ) {
                settings.isBpmFilterActive.toggle()
            }
            
            // Filtre Harmonique (Camelot compatible)
            filterTogglePill(
                title: "Harmonie",
                shortTitle: "Harm.",
                icon: "circle.grid.cross.fill",
                isActive: settings.isHarmonicFilterActive,
                accentColor: Color(hex: "#C471ED")
            ) {
                settings.isHarmonicFilterActive.toggle()
            }
            
            // Filtre Combos Favoris
            filterTogglePill(
                title: "Favs",
                shortTitle: "Fav",
                icon: "heart.fill",
                isActive: settings.isFavoritesFilterActive && !settings.isToPlayFilterActive,
                accentColor: Color(hex: "#FF5252")
            ) {
                if settings.isToPlayFilterActive {
                    settings.isToPlayFilterActive = false
                }
                settings.isFavoritesFilterActive.toggle()
            }
            
            // Filtre / Onglet Morceaux Sélec
            filterTogglePill(
                title: toPlayService.tracks.isEmpty ? "Sélec" : "Sélec (\(toPlayService.tracks.count))",
                shortTitle: toPlayService.tracks.isEmpty ? "Sélec" : "\(toPlayService.tracks.count) sélec",
                icon: "bookmark.fill",
                isActive: settings.isToPlayFilterActive,
                accentColor: Color(hex: "#FFB300")
            ) {
                settings.isToPlayFilterActive.toggle()
            }
            
            Spacer(minLength: 4)
            
            // Compteur de résultats
            let countLabel = settings.isToPlayFilterActive ?
                "sélec" :
                (suggestionsCount > 1 ? "matchs" : "match")
            
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 3) {
                    Text("\(suggestionsCount)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(settings.isToPlayFilterActive ? Color(hex: "#FFB300") : .white.opacity(0.65))
                    Text(countLabel)
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.40))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.05))
                .cornerRadius(5)
                
                Text("\(suggestionsCount)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundColor(settings.isToPlayFilterActive ? Color(hex: "#FFB300") : .white.opacity(0.55))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 5)
    }
    
    private func filterTogglePill(
        title: String,
        shortTitle: String? = nil,
        icon: String,
        isActive: Bool,
        accentColor: Color = Color.accentCyan,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 2.5) {
                    Image(systemName: icon)
                        .font(.system(size: 7.5, weight: .bold))
                    Text(title)
                        .font(.system(size: 8.5, weight: .semibold))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                
                HStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 7))
                    if let short = shortTitle {
                        Text(short)
                            .font(.system(size: 8, weight: .semibold))
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
            .background(isActive ? accentColor.opacity(0.25) : Color.white.opacity(0.06))
            .foregroundColor(isActive ? accentColor : Color.white.opacity(0.7))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
