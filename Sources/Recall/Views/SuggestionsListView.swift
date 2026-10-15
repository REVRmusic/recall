import SwiftUI

public struct SuggestionsListView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    let suggestions: [Track]
    let isLoading: Bool
    
    public init(suggestions: [Track], isLoading: Bool) {
        self.suggestions = suggestions
        self.isLoading = isLoading
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                VStack(spacing: 10) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentCyan))
                        .scaleEffect(0.85)
                    
                    Text("Recherche des enchaînements en cours...")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if monitor.currentTrack == nil {
                VStack(spacing: 8) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.accentCyan.opacity(0.12))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundColor(Color.accentCyan.opacity(0.85))
                    }
                    
                    Text("Lancer la lecture")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Démarrez un morceau sur une platine Serato DJ Pro pour faire apparaître vos suggestions d'enchaînement en direct.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if suggestions.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: settings.isFavoritesFilterActive ? "heart.slash" : "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(settings.isFavoritesFilterActive ? Color(hex: "#FF5252").opacity(0.3) : .white.opacity(0.2))
                    
                    Text(settings.isFavoritesFilterActive ? "Aucune combinaison favorite" : "Aucun enchaînement historique")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(settings.isFavoritesFilterActive ? "Enregistrez une combinaison favorite avec le bouton '+ Sauvegarder combo' ou l'icône cœur d'un morceau." : "Aucune transition enregistrée dans vos sessions pour ce morceau.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, track in
                            DraggableTrackRow(track: track, rank: index + 1)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                    .modernDarkScrollbar()
                }
            }
        }
    }
}
