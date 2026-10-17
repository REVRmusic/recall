import SwiftUI
import UniformTypeIdentifiers

public struct MainFloatingView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    @ObservedObject var toPlayService: ToPlayService = .shared
    @ObservedObject var autoUpdateService: AutoUpdateService = .shared
    
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
    
    /// Nombre de morceaux à jouer affichés en tenant compte des filtres harmoniques/BPM
    private var displayedToPlayCount: Int {
        var list = toPlayService.toTrackList(referenceTrack: monitor.currentTrack)
        if settings.isHarmonicFilterActive, monitor.currentTrack != nil {
            list = list.filter { $0.harmonicRelation?.isCompatible == true }
        }
        if settings.isBpmFilterActive, let currentBpm = monitor.currentTrack?.bpm, currentBpm > 0 {
            let tolPercent = settings.bpmTolerancePercent / 100.0
            list = list.filter { track in
                guard track.bpm > 0 else { return false }
                let ratio1 = track.bpm / currentBpm
                if abs(ratio1 - 1.0) <= tolPercent { return true }
                let ratio2 = (track.bpm / 2.0) / currentBpm
                if abs(ratio2 - 1.0) <= tolPercent { return true }
                let ratio3 = (track.bpm * 2.0) / currentBpm
                if abs(ratio3 - 1.0) <= tolPercent { return true }
                return false
            }
        }
        if settings.hidePlayedTracks {
            list = list.filter { !$0.isPlayedInSession }
        }
        return list.count
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Teinte d'ambiance avec opacité réglable sur le verre dépoli natif macOS de la fenêtre
            Color.darkBg.opacity(settings.effectiveGlassTintOpacity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    settings.accentColor.opacity(0.28),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            
            // Vue de réception AppKit native assurant 100% de fiabilité lors d'un glisser depuis Serato ou Rekordbox
            RecallDropTargetViewRepresentable(
                onDropURLs: { urls in
                    for url in urls {
                        toPlayService.addTrack(fromURL: url)
                    }
                },
                onDraggingChanged: { isOver in
                    toPlayService.isDraggingFileOver = isOver
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if settings.isCompactMode {
                // Mode bandeau compact ouvert sur la droite de l'écran
                BandeauCompactView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    // Barre d'en-tête (Logo Recall, Bouton Réduire bien visible, Actions)
                    HeaderView(
                        showSearch: $showSearch,
                        showGuide: $showGuide
                    )
                    
                    // Notification discrète si une nouvelle version est disponible
                    if autoUpdateService.isUpdateAvailable && autoUpdateService.showUpdateBanner,
                       let release = autoUpdateService.availableUpdate {
                        UpdateBannerView(release: release)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Carte unifiée du morceau en cours de lecture avec sélecteurs de Deck
                    NowPlayingCard()
                    
                    // Barre de filtres en 1 seule ligne ultra compacte
                    FilterBarView(
                        suggestionsCount: settings.isToPlayFilterActive ? displayedToPlayCount : filteredSuggestions.count
                    )
                    
                    // Liste des suggestions réelles ou Liste des morceaux à jouer selon le filtre actif
                    if settings.isToPlayFilterActive {
                        ToPlayListView()
                    } else {
                        SuggestionsListView(
                            suggestions: filteredSuggestions,
                            isLoading: monitor.isLoading
                        )
                    }
                }
                .frame(minHeight: FloatingWindowController.minNormalHeight, alignment: .top)
                .clipped()
                .transition(.opacity)
            }
            
            // Overlay visuel lors du survol d'un glisser de morceau audio
            if toPlayService.isDraggingFileOver {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentCyan.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                Color.accentCyan,
                                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                            )
                    )
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(Color.accentCyan)
                            Text("Ajouter à la Sélec")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("Déposez le morceau dans votre sélection")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                    )
                    .transition(.opacity)
                    .zIndex(90)
            }
            
            // Toast flottant de confirmation d'ajout
            if let toast = toPlayService.toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(hex: "#00E676"))
                            .font(.system(size: 11, weight: .bold))
                        Text(toast)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#1A1A22").opacity(0.96))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#00E676").opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 3)
                    )
                    .padding(.bottom, 12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(95)
            }
            
            // Modale de confirmation de combo favori
            if let confirmation = monitor.pendingComboConfirmation {
                ComboConfirmationModalView(data: confirmation)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(100)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(
            minWidth: settings.isCompactMode ? FloatingWindowController.minCompactWidth : FloatingWindowController.minNormalWidth,
            maxWidth: FloatingWindowController.maxWidth,
            minHeight: settings.isCompactMode ? FloatingWindowController.bandeauHeight : FloatingWindowController.minNormalHeight,
            maxHeight: FloatingWindowController.maxHeight
        )
        .ignoresSafeArea() // Indispensable pour que le fond sombre englobe les traffic lights macOS
        .sheet(isPresented: $showSearch) {
            ManualSearchSheetView()
                .environmentObject(monitor)
        }
        .sheet(isPresented: $showGuide) {
            GuideSheetView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recallTriggerSearch)) { _ in
            showSearch = true
        }
    }
}
