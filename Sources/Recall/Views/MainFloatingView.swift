import SwiftUI

public struct MainFloatingView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    
    @State private var showSearch: Bool = false
    @State private var showGuide: Bool = false
    
    public init() {}
    
    /// Filtrage en direct selon les filtres actifs (Harmonie, BPM, Favoris)
    private var filteredSuggestions: [Track] {
        var list = settings.isFavoritesFilterActive ? monitor.favoriteSuggestions : monitor.historySuggestions
        
        // 1. Filtre Harmonique (Camelot compatible selon la vraie roue)
        if settings.isHarmonicFilterActive {
            list = list.filter { track in
                track.harmonicRelation?.isCompatible == true
            }
        }
        
        // 2. Filtre BPM (tolérance en % + prise en compte du half-time/double-time)
        if settings.isBpmFilterActive, let currentBpm = monitor.currentTrack?.bpm, currentBpm > 0 {
            let tolPercent = settings.bpmTolerancePercent / 100.0
            list = list.filter { track in
                guard track.bpm > 0 else { return false }
                
                // Comparaison directe
                let ratio1 = track.bpm / currentBpm
                if abs(ratio1 - 1.0) <= tolPercent { return true }
                
                // Comparaison double-time (ex: 75 -> 150)
                let ratio2 = (track.bpm / 2.0) / currentBpm
                if abs(ratio2 - 1.0) <= tolPercent { return true }
                
                // Comparaison half-time (ex: 150 -> 75)
                let ratio3 = (track.bpm * 2.0) / currentBpm
                if abs(ratio3 - 1.0) <= tolPercent { return true }
                
                return false
            }
        }
        
        // 3. Masquer les morceaux déjà joués si l'option est activée
        if settings.hidePlayedTracks {
            list = list.filter { !$0.isPlayedInSession }
        }
        
        return list
    }
    
    public var body: some View {
        ZStack {
            // Fond sombre avec verre dépoli ultra moderne épousant rigoureusement tout le cadre
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.darkBg.opacity(0.96))
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.20),
                                    Color.accentCyan.opacity(0.18),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            if settings.isCompactMode {
                // Mode bandeau compact ouvert sur la droite de l'écran
                BandeauCompactView()
            } else {
                VStack(spacing: 0) {
                    // Barre d'en-tête (Logo Recall, Bouton Réduire bien visible, Actions)
                    HeaderView(
                        showSearch: $showSearch,
                        showGuide: $showGuide
                    )
                    
                    // Carte unifiée du morceau en cours de lecture avec sélecteurs de Deck
                    NowPlayingCard()
                    
                    // Barre de filtres en 1 seule ligne ultra compacte
                    FilterBarView(
                        suggestionsCount: filteredSuggestions.count
                    )
                    
                    // Liste des suggestions réelles d'enchaînement
                    SuggestionsListView(
                        suggestions: filteredSuggestions,
                        isLoading: monitor.isLoading
                    )
                }
            }
            
            // Modale de confirmation de combo favori
            if let confirmation = monitor.pendingComboConfirmation {
                ComboConfirmationModalView(data: confirmation)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(100)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(minWidth: 250, maxWidth: .infinity, minHeight: 54, maxHeight: .infinity)
        .ignoresSafeArea() // Indispensable pour que le fond sombre englobe les traffic lights macOS
        .sheet(isPresented: $showSearch) {
            ManualSearchSheetView()
                .environmentObject(monitor)
        }
        .sheet(isPresented: $showGuide) {
            GuideSheetView()
        }
    }
}
