import SwiftUI

/// Vue affichant la liste des morceaux que le DJ a mis de côté pour les jouer prochainement
public struct ToPlayListView: View {
    @ObservedObject var toPlayService: ToPlayService = .shared
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    
    public init() {}
    
    /// Morceaux à jouer filtrés selon les filtres harmoniques/BPM si un morceau est en cours
    private var displayedTracks: [Track] {
        var list = toPlayService.toTrackList(referenceTrack: monitor.currentTrack)
        
        // Filtrage Harmonique si activé et un morceau tourne
        if settings.isHarmonicFilterActive, monitor.currentTrack != nil {
            list = list.filter { $0.harmonicRelation?.isCompatible == true }
        }
        
        // Filtrage BPM si activé et un morceau tourne
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
        
        // Masquer les morceaux déjà joués
        if settings.hidePlayedTracks {
            list = list.filter { !$0.isPlayedInSession }
        }
        
        return list
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if toPlayService.tracks.isEmpty {
                // État vide initial : invitation claire au glisser-déposer
                VStack(spacing: 8) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FFB300").opacity(0.12))
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFB300").opacity(0.9))
                    }
                    
                    Text("Aucun morceau dans votre Sélec")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Faites glisser un morceau depuis Serato ou Rekordbox pour l'ajouter à votre sélection de sets.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if displayedTracks.isEmpty {
                // Morceaux présents mais masqués par les filtres actifs
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "#FFB300").opacity(0.4))
                    
                    Text("Aucun morceau compatible")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                    
                    Text("Désactivez les filtres BPM ou Harmonie pour voir l'intégralité de votre sélection (\(toPlayService.tracks.count) morceaux).")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                // Sous-barre d'action rapide pour vider la liste si plusieurs morceaux
                if toPlayService.tracks.count >= 2 {
                    HStack {
                        Text("\(displayedTracks.count) morceau\(displayedTracks.count > 1 ? "x" : "") en sélec")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.45))
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                toPlayService.clearAll()
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "trash")
                                    .font(.system(size: 7.5))
                                Text("Vider la sélec")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Vider intégralement votre sélection de set")
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 3) {
                        ForEach(Array(displayedTracks.enumerated()), id: \.element.id) { index, track in
                            ToPlayTrackRow(track: track, rank: index + 1)
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
