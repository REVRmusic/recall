import SwiftUI

public struct ManualSearchSheetView: View {
    @EnvironmentObject var monitor: SeratoMonitorService
    @EnvironmentObject var settings: UserSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    
    private let dbService = SeratoDatabaseService()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // En-tête
            HStack {
                Text(monitor.activeDJSoftware == .rekordbox ? "Rechercher dans Rekordbox" : "Rechercher dans la bibliothèque")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            
            // Champ de recherche
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.accentCyan)
                
                TextField("Titre, artiste ou nom de fichier...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .onChange(of: searchQuery) { query in
                        performSearch(query: query)
                    }
                
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.cardBg)
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.borderSubtle)
            
            // Liste des résultats
            if isSearching {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text("Aucun résultat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Essayez avec un autre mot-clé")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(searchResults) { track in
                            Button {
                                monitor.setManualReferenceTrack(track)
                                dismiss()
                            } label: {
                                HStack {
                                    let isPlayed = SessionHistoryService.shared.isPlayed(track: track)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.displayTitle)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(isPlayed ? .white.opacity(0.60) : .white)
                                            .lineLimit(1)
                                        
                                        Text(track.displayArtist)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(isPlayed ? 0.35 : 0.55))
                                            .lineLimit(1)
                                    }
                                    .help(track.fullTooltip)
                                    
                                    Spacer()
                                    
                                    if isPlayed {
                                        HStack(spacing: 2) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 6, weight: .black))
                                            Text("JOUÉ")
                                                .font(.system(size: 7, weight: .heavy, design: .rounded))
                                        }
                                        .foregroundColor(Color(hex: "#7ED6DF"))
                                        .padding(.horizontal, 3.5)
                                        .padding(.vertical, 1.5)
                                        .background(Color(hex: "#7ED6DF").opacity(0.18))
                                        .cornerRadius(3)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color(hex: "#7ED6DF").opacity(0.5), lineWidth: 0.8)
                                        )
                                    }
                                    
                                    if let camelot = track.camelotKey {
                                        Text(camelot.displayText(mode: settings.keyDisplayMode))
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(camelot.color.opacity(0.2))
                                            .foregroundColor(camelot.color)
                                            .cornerRadius(4)
                                    }
                                    
                                    Text("\(track.displayBpm)")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    // Bouton d'association rapide en combo avec le morceau en cours
                                    if let current = monitor.currentTrack,
                                       FavoriteCombosService.normalize(current.displayTitle) != FavoriteCombosService.normalize(track.displayTitle) {
                                        let isFav = FavoriteCombosService.shared.isComboFavorite(track1: current, track2: track)
                                        Button {
                                            FavoriteCombosService.shared.toggleCombo(track1: current, track2: track)
                                        } label: {
                                            Image(systemName: isFav ? "heart.fill" : "heart")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(isFav ? Color(hex: "#FF5252") : .white.opacity(0.5))
                                                .frame(width: 20, height: 20)
                                                .background(isFav ? Color(hex: "#FF5252").opacity(0.2) : Color.white.opacity(0.06))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .help(isFav ? "Retirer de vos combos avec « \(current.displayTitle) »" : "Enregistrer comme combo avec « \(current.displayTitle) »")
                                    }
                                }
                                .padding(8)
                                .background(Color.cardBg.opacity(0.7))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 320, height: 420)
        .background(Color.darkBg)
    }
    
    private func performSearch(query: String) {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        let isRekordbox = monitor.activeDJSoftware == .rekordbox
        let db = self.dbService
        
        Task.detached(priority: .userInitiated) {
            let results: [Track]
            if isRekordbox {
                results = await MainActor.run {
                    RekordboxService.shared.searchTracks(query: query, limit: 30)
                }
            } else {
                results = db.searchTracks(query: query, limit: 30)
            }
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}
