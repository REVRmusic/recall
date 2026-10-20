import SwiftUI

public struct FilterBarView: View {
    @EnvironmentObject var settings: UserSettings
    @ObservedObject var toPlayService: ToPlayService = .shared
    let suggestionsCount: Int
    
    public init(suggestionsCount: Int) {
        self.suggestionsCount = suggestionsCount
    }
    
    public var body: some View {
        GeometryReader { proxy in
            // Seuil 1 (< 345px) : On retire le texte "sélec" pour n'avoir que le chiffre (ex: 🔖 10)
            // Seuil 2 (< 275px) : Si la fenêtre devenait encore plus étroite, on masque les libellés BPM/Harm/Favs
            let isSelecCompact = proxy.size.width < 345
            let isUltraNarrow = proxy.size.width < 275
            
            HStack(spacing: 3.5) {
                // Mini sélecteur de direction d'enchaînement (Après / Avant / Tout)
                directionSegmentedPicker
                
                // Séparateur vertical discret
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 13)
                    .padding(.horizontal, 1)
                
                // Filtre BPM
                filterButton(
                    icon: "metronome",
                    title: "BPM",
                    hideTitle: isUltraNarrow,
                    isActive: settings.isBpmFilterActive,
                    accentColor: Color.accentCyan
                ) {
                    settings.isBpmFilterActive.toggle()
                }
                .help("Filtrer par BPM compatible (±\(Int(settings.bpmTolerancePercent))%)")
                
                // Filtre Harmonique (Camelot compatible)
                filterButton(
                    icon: "circle.grid.cross.fill",
                    title: "Harm.",
                    hideTitle: isUltraNarrow,
                    isActive: settings.isHarmonicFilterActive,
                    accentColor: Color(hex: "#C471ED")
                ) {
                    settings.isHarmonicFilterActive.toggle()
                }
                .help("Filtrer par clé harmonique Camelot compatible")
                
                // Filtre Combos Favoris
                filterButton(
                    icon: "heart.fill",
                    title: "Favs",
                    hideTitle: isUltraNarrow,
                    isActive: settings.isFavoritesFilterActive && !settings.isToPlayFilterActive,
                    accentColor: Color(hex: "#FF5252")
                ) {
                    if settings.isToPlayFilterActive {
                        settings.isToPlayFilterActive = false
                    }
                    settings.isFavoritesFilterActive.toggle()
                }
                .help("Afficher uniquement vos transitions favorites mémorisées")
                
                // Filtre / Onglet Morceaux Sélec (compact = chiffre seul)
                toPlayFilterButton(isCompact: isSelecCompact)
                
                Spacer(minLength: 2)
                
                // Compteur de résultats
                matchCountBadge(isCompact: isSelecCompact)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: 22)
        .padding(.horizontal, 8)
        .padding(.bottom, 5)
    }
    
    // MARK: - Bouton Filtre Standard
    
    private func filterButton(
        icon: String,
        title: String,
        hideTitle: Bool,
        isActive: Bool,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 2.5) {
                Image(systemName: icon)
                    .font(.system(size: hideTitle ? 8 : 7.5, weight: .bold))
                
                if !hideTitle {
                    Text(title)
                        .font(.system(size: 8.5, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, hideTitle ? 5 : 5.5)
            .frame(height: 20)
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
    
    // MARK: - Bouton Filtre Sélec (Spécial : affiche le nombre seul quand l'espace manque)
    
    private func toPlayFilterButton(isCompact: Bool) -> some View {
        let count = toPlayService.tracks.count
        let isActive = settings.isToPlayFilterActive
        let accentColor = Color(hex: "#FFB300")
        
        return Button {
            settings.isToPlayFilterActive.toggle()
        } label: {
            HStack(spacing: 2.5) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: isCompact ? 8 : 7.5, weight: .bold))
                
                if isCompact {
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                } else {
                    if count > 0 {
                        Text("\(count) sélec")
                            .font(.system(size: 8.5, weight: .semibold))
                            .lineLimit(1)
                    } else {
                        Text("Sélec")
                            .font(.system(size: 8.5, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, isCompact ? 5 : 5.5)
            .frame(height: 20)
            .background(isActive ? accentColor.opacity(0.25) : Color.white.opacity(0.06))
            .foregroundColor(isActive ? accentColor : Color.white.opacity(0.7))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isActive ? accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(count > 0 ? "Afficher les \(count) morceaux préparés dans votre Sélec" : "Afficher votre liste de morceaux préparés (« À jouer »)")
    }
    
    // MARK: - Badge Compteur de matchs
    
    private func matchCountBadge(isCompact: Bool) -> some View {
        let countLabel = settings.isToPlayFilterActive ?
            "sélec" :
            (suggestionsCount > 1 ? "matchs" : "match")
        
        return HStack(spacing: 2.5) {
            Text("\(suggestionsCount)")
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundColor(settings.isToPlayFilterActive ? Color(hex: "#FFB300") : .white.opacity(0.65))
            
            if !isCompact {
                Text(countLabel)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.40))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, isCompact ? 4 : 5)
        .frame(height: 20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(5)
    }
    
    private var directionSegmentedPicker: some View {
        HStack(spacing: 1.5) {
            ForEach(TransitionDirection.allCases) { dir in
                let isSelected = settings.transitionDirection == dir
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        settings.transitionDirection = dir
                    }
                } label: {
                    HStack(spacing: 2.5) {
                        Image(systemName: dir.icon)
                            .font(.system(size: 7.5, weight: .bold))
                        if isSelected {
                            Text(dir.label)
                                .font(.system(size: 8, weight: .bold))
                                .fixedSize()
                        }
                    }
                    .padding(.horizontal, isSelected ? 5 : 3.5)
                    .frame(height: 16)
                    .background(
                        isSelected ?
                            Color.white.opacity(0.18) :
                            Color.clear
                    )
                    .foregroundColor(
                        isSelected ?
                            Color.white :
                            Color.white.opacity(0.40)
                    )
                    .cornerRadius(3.5)
                }
                .buttonStyle(.plain)
                .help(dir.tooltip)
            }
        }
        .padding(1.5)
        .frame(height: 19)
        .background(Color.white.opacity(0.06))
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}
