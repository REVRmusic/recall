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
        HStack(spacing: 5) {
            // Filtre BPM ±10%
            filterTogglePill(
                title: "BPM ±10%",
                icon: "metronome",
                isActive: settings.isBpmFilterActive,
                accentColor: Color.accentCyan
            ) {
                settings.isBpmFilterActive.toggle()
            }
            
            // Filtre Harmonique (Camelot compatible)
            filterTogglePill(
                title: "Harmonie",
                icon: "circle.grid.cross.fill",
                isActive: settings.isHarmonicFilterActive,
                accentColor: Color(hex: "#C471ED")
            ) {
                settings.isHarmonicFilterActive.toggle()
            }
            
            // Filtre Combos Favoris
            filterTogglePill(
                title: "Favs",
                icon: "heart.fill",
                isActive: settings.isFavoritesFilterActive,
                accentColor: Color(hex: "#FF5252")
            ) {
                settings.isFavoritesFilterActive.toggle()
            }
            
            Spacer(minLength: 2)
            
            // Mini champ de recherche rapide intégré
            HStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 8.5))
                    .foregroundColor(.white.opacity(0.4))
                
                TextField("Filtrer...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9.5))
                    .foregroundColor(.white)
                    .frame(width: 48)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05))
            .cornerRadius(6)
            
            // Compteur de résultats
            Text("\(suggestionsCount)")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }
    
    private func filterTogglePill(
        title: String,
        icon: String,
        isActive: Bool,
        accentColor: Color = Color.accentCyan,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 7.5, weight: .bold))
                Text(title)
                    .font(.system(size: 8.5, weight: .semibold))
            }
            .padding(.horizontal, 5.5)
            .padding(.vertical, 3.5)
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
