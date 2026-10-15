import SwiftUI

public struct FilterBarView: View {
    @EnvironmentObject var settings: UserSettings
    @Binding var searchText: String
    let suggestionsCount: Int
    
    public init(searchText: Binding<String>, suggestionsCount: Int) {
        self._searchText = searchText
        self.suggestionsCount = suggestionsCount
    }
    
    public var body: some View {
        HStack(spacing: 3) {
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
                isActive: settings.isFavoritesFilterActive,
                accentColor: Color(hex: "#FF5252")
            ) {
                settings.isFavoritesFilterActive.toggle()
            }
            
            Spacer(minLength: 2)
            
            // Mini champ de recherche rapide intégré
            HStack(spacing: 2) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.4))
                
                TextField("Filtrer...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                    .frame(minWidth: 26, maxWidth: 44)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2.5)
            .background(Color.white.opacity(0.05))
            .cornerRadius(5)
            
            // Compteur de résultats
            Text("\(suggestionsCount)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 1)
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
