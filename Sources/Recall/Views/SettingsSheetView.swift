import SwiftUI
import UniformTypeIdentifiers

public struct SettingsSheetView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    @ObservedObject private var favService = FavoriteCombosService.shared
    @ObservedObject private var sessionService = SessionHistoryService.shared
    @ObservedObject private var rbService = RekordboxService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showGuideFromSettings: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // En-tête moderne & épuré
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.accentCyan.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.accentCyan)
                }
                
                Text("Paramètres Recall")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Bouton de fermeture élégant sans focus ring
                Button {
                    SettingsWindowController.shared.closeWindow()
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .background(Color.darkBg)
            
            Divider()
                .background(Color.white.opacity(0.10))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    
                    // SECTION 0 : Logiciel DJ & Source des données
                    settingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Logiciel DJ")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "music.note.tv.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                // Statut de connexion dynamique
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill((monitor.isSeratoConnected || monitor.isRekordboxConnected) ? Color.accentCyan : Color.white.opacity(0.35))
                                        .frame(width: 5, height: 5)
                                    
                                    Text(monitor.isSeratoConnected ? "Serato actif" : (monitor.isRekordboxConnected ? "Rekordbox actif" : "En attente"))
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(4)
                            }
                            
                            // Sélecteur de mode (Automatique, Serato, Rekordbox)
                            HStack(spacing: 5) {
                                ForEach(DJSoftwareMode.allCases) { mode in
                                    Button {
                                        settings.djSoftwareMode = mode
                                        monitor.checkDatabaseUpdates()
                                    } label: {
                                        Text(mode.shortLabel)
                                            .font(.system(size: 10, weight: settings.djSoftwareMode == mode ? .bold : .medium))
                                            .foregroundColor(settings.djSoftwareMode == mode ? .white : .white.opacity(0.6))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .background(settings.djSoftwareMode == mode ? Color.accentCyan.opacity(0.3) : Color.white.opacity(0.05))
                                            .cornerRadius(5)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(settings.djSoftwareMode == mode ? Color.accentCyan.opacity(0.75) : Color.clear, lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)
                                }
                            }
                            
                            // Détails selon le logiciel sélectionné / actif
                            if monitor.activeDJSoftware == .rekordbox {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Collection & Enchaînements Rekordbox XML")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("\(rbService.totalTracksCount) morceaux • \(rbService.totalTransitionsCount) enchaînements mémorisés")
                                                .font(.system(size: 9))
                                                .foregroundColor(.white.opacity(0.55))
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            selectRekordboxXmlFile()
                                        } label: {
                                            Text("Parcourir...")
                                                .font(.system(size: 9.5, weight: .bold))
                                                .foregroundColor(Color.accentCyan)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 3)
                                                .background(Color.accentCyan.opacity(0.18))
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                        .focusable(false)
                                    }
                                    
                                    if !settings.effectiveRekordboxXmlPath.isEmpty {
                                        Text(settings.effectiveRekordboxXmlPath)
                                            .font(.system(size: 8.5, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.4))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    
                                    if let err = rbService.errorMessage {
                                        Text(err)
                                            .font(.system(size: 8.5))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                }
                                .padding(7)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(6)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.accentCyan)
                                    Text("Accès direct SQLite WAL Serato (Deck 1 / Deck 2 en temps réel)")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    
                    // SECTION 1 : Période d'historique
                    settingCard {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Label {
                                    Text("Historique analysé")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                Text("\(settings.historyDaysLookback) jours")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(Color.accentCyan.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            // Curseur sur-mesure ultra lisible
                            CustomSlider(
                                value: Binding(
                                    get: { Double(settings.historyDaysLookback) },
                                    set: { settings.historyDaysLookback = Int($0) }
                                ),
                                range: 30...730,
                                step: 15
                            )
                            
                            // Raccourcis de sélection rapide
                            HStack(spacing: 4) {
                                quickDayButton(days: 90, label: "3 mois")
                                quickDayButton(days: 180, label: "6 mois")
                                quickDayButton(days: 360, label: "1 an")
                                quickDayButton(days: 720, label: "2 ans")
                            }
                        }
                    }
                    
                    // SECTION 2 : Nombre de suggestions
                    settingCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("Nombre de suggestions")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "list.number")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.accentCyan)
                            }
                            
                            CustomSegmentedPicker(
                                items: [
                                    ("Top 20", 20),
                                    ("Top 30", 30),
                                    ("Top 50", 50)
                                ],
                                selection: $settings.maxSuggestions
                            )
                        }
                    }
                    
                    // SECTION 3 : Tolérance BPM
                    settingCard {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Label {
                                    Text("Tolérance BPM")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "metronome")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                Text("±\(Int(settings.bpmTolerancePercent))%")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(Color.accentCyan)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(Color.accentCyan.opacity(0.2))
                                    .cornerRadius(4)
                            }
                            
                            CustomSlider(
                                value: $settings.bpmTolerancePercent,
                                range: 4...16,
                                step: 1
                            )
                            
                            Text("Marge acceptée lors du filtre BPM (inclus demi & double tempo).")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    
                    // SECTION 4 : Format d'affichage des clés Camelot
                    settingCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text("Format des clés")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "music.quarternote.3")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.accentCyan)
                            }
                            
                            CustomSegmentedPicker(
                                items: [
                                    ("Camelot (9A)", 0),
                                    ("Musicale (Em)", 1),
                                    ("Combiné", 2)
                                ],
                                selection: $settings.keyDisplayMode
                            )
                        }
                    }
                    
                    // SECTION 5 : Comportement de la fenêtre
                    settingCard {
                        VStack(alignment: .leading, spacing: 9) {
                            Label {
                                Text("Fenêtre & Affichage")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "macwindow")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.accentCyan)
                            }
                            
                            HStack {
                                Text("Toujours au premier plan (Floating)")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Spacer()
                                
                                Toggle("", isOn: $settings.alwaysOnTop)
                                    .toggleStyle(.switch)
                                    .tint(Color.accentCyan)
                                    .scaleEffect(0.85)
                                    .onChange(of: settings.alwaysOnTop) { val in
                                        FloatingWindowController.shared.updateAlwaysOnTop(val)
                                    }
                            }
                            
                            SettingActionButton(
                                icon: "arrow.down.right.and.arrow.up.left",
                                title: "Recentrer en bas à droite de l'écran"
                            ) {
                                FloatingWindowController.shared.positionAtBottomRight()
                            }
                        }
                    }
                    
                    // SECTION 6 : Combinaisons mémorisées (Favoris)
                    settingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Combos Favoris (\(favService.combos.count))")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#FF5252"))
                                }
                                
                                Spacer()
                                
                                if !favService.combos.isEmpty {
                                    Button {
                                        favService.clearAllCombos()
                                    } label: {
                                        Text("Tout effacer")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            if favService.combos.isEmpty {
                                Text("Aucune combinaison enregistrée. Cliquez sur le cœur ❤️ ou sur '+ Combo' pour sauvegarder un coup de cœur.")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.5))
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                VStack(spacing: 5) {
                                    ForEach(favService.combos.prefix(15)) { combo in
                                        HStack(spacing: 6) {
                                            Image(systemName: "heart.fill")
                                                .font(.system(size: 8))
                                                .foregroundColor(Color(hex: "#FF5252"))
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(combo.track1.title)
                                                    .font(.system(size: 9.5, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "arrow.right")
                                                        .font(.system(size: 7))
                                                        .foregroundColor(Color.accentCyan)
                                                    Text(combo.track2.title)
                                                        .font(.system(size: 9.5, weight: .semibold))
                                                        .foregroundColor(Color.accentCyan)
                                                        .lineLimit(1)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                favService.deleteCombo(byId: combo.id)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 8.5))
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .padding(3)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.25))
                                        .cornerRadius(5)
                                    }
                                    
                                    if favService.combos.count > 15 {
                                        Text("+ \(favService.combos.count - 15) autres combinaisons...")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                    }
                    
                    // SECTION 7 : Session en cours & Morceaux déjà joués
                    settingCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label {
                                    Text("Session en cours")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.white)
                                } icon: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.accentCyan)
                                }
                                
                                Spacer()
                                
                                Text("\(sessionService.playedCount) joués")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(sessionService.playedCount > 0 ? Color.accentCyan : .white.opacity(0.45))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1.5)
                                    .background(sessionService.playedCount > 0 ? Color.accentCyan.opacity(0.18) : Color.white.opacity(0.06))
                                    .cornerRadius(4)
                            }
                            
                            HStack {
                                Text("Masquer les morceaux déjà joués")
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                Spacer()
                                
                                Toggle("", isOn: $settings.hidePlayedTracks)
                                    .toggleStyle(.switch)
                                    .tint(Color.accentCyan)
                                    .scaleEffect(0.85)
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.08))
                            
                            // Délai de validation (anti-préécoute)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Délai de validation (anti-préécoute)")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        if settings.playedMinDurationSeconds == 25 {
                                            Text("Défaut")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(Color.accentCyan.opacity(0.85))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1.5)
                                                .background(Color.accentCyan.opacity(0.15))
                                                .cornerRadius(3)
                                        }
                                        
                                        Text("\(settings.playedMinDurationSeconds) sec")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(Color.accentCyan)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(Color.accentCyan.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                }
                                
                                CustomSlider(
                                    value: Binding(
                                        get: { Double(settings.playedMinDurationSeconds) },
                                        set: { newVal in
                                            settings.playedMinDurationSeconds = Int(newVal)
                                            monitor.triggerSessionResync()
                                        }
                                    ),
                                    range: 5...90,
                                    step: 5
                                )
                                
                                HStack(spacing: 4) {
                                    quickSecondButton(seconds: 10, label: "10s")
                                    quickSecondButton(seconds: 15, label: "15s")
                                    quickSecondButton(seconds: 25, label: "25s", isDefault: true)
                                    quickSecondButton(seconds: 45, label: "45s")
                                    quickSecondButton(seconds: 60, label: "60s")
                                }
                                
                                Text("Un morceau doit tourner au moins \(settings.playedMinDurationSeconds)s pour être mémorisé (25s par défaut). Les pré-écoutes au casque plus courtes sont ignorées.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.50))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 2)
                            
                            Divider()
                                .background(Color.white.opacity(0.08))
                            
                            // Personnalisation de la couleur des morceaux joués
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Couleur d'identification")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                    
                                    Spacer()
                                    
                                    let presetNames: [String: String] = [
                                        "#0FA2FF": "Bleu Platine",
                                        "#00D2D3": "Cyan Électrique",
                                        "#AC63FE": "Violet Néon",
                                        "#2ECC71": "Vert Émeraude",
                                        "#FF9F43": "Orange DJ",
                                        "#FF5252": "Rose Fluo"
                                    ]
                                    
                                    Text(presetNames[settings.playedTrackColorHex.uppercased()] ?? settings.playedTrackColorHex)
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(settings.playedTrackColor)
                                }
                                
                                let presetColors: [(hex: String, name: String)] = [
                                    ("#0FA2FF", "Bleu Platine"),
                                    ("#00D2D3", "Cyan Électrique"),
                                    ("#AC63FE", "Violet Néon"),
                                    ("#2ECC71", "Vert Émeraude"),
                                    ("#FF9F43", "Orange DJ"),
                                    ("#FF5252", "Rose Fluo")
                                ]
                                
                                HStack(spacing: 8) {
                                    ForEach(presetColors, id: \.hex) { preset in
                                        let isSelected = settings.playedTrackColorHex.uppercased() == preset.hex.uppercased()
                                        Button {
                                            settings.playedTrackColorHex = preset.hex
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: preset.hex))
                                                    .frame(width: 22, height: 22)
                                                
                                                if isSelected {
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: 2)
                                                        .frame(width: 25, height: 25)
                                                    
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 8, weight: .black))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .help(preset.name)
                                    }
                                    
                                    // Sélecteur de couleur libre
                                    ColorPicker("", selection: Binding(
                                        get: { settings.playedTrackColor },
                                        set: { newCol in
                                            if let hex = newCol.toHex() {
                                                settings.playedTrackColorHex = hex
                                            }
                                        }
                                    ))
                                    .labelsHidden()
                                    .scaleEffect(0.85)
                                    .help("Choisir une couleur personnalisée")
                                }
                            }
                            
                            // Style d'affichage (Texte seul, Fond teinté, ou les deux)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Style d'affichage")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                HStack(spacing: 4) {
                                    ForEach(PlayedTrackHighlightStyle.allCases) { style in
                                        let isSelected = settings.playedTrackHighlightStyle == style
                                        Button {
                                            settings.playedTrackHighlightStyle = style
                                        } label: {
                                            Text(style.label)
                                                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 4.5)
                                                .background(isSelected ? settings.playedTrackColor.opacity(0.25) : Color.white.opacity(0.06))
                                                .foregroundColor(isSelected ? settings.playedTrackColor : .white.opacity(0.65))
                                                .cornerRadius(4)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(isSelected ? settings.playedTrackColor.opacity(0.7) : Color.white.opacity(0.08), lineWidth: 0.8)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Aperçu en direct du morceau joué
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Aperçu en direct :")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.45))
                                
                                HStack(spacing: 6) {
                                    Text("3")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor : .white.opacity(0.4))
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Were-Vana - Casanova (Tomy B Intro)")
                                            .font(.system(size: 10.5, weight: .semibold))
                                            .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor : .white)
                                            .lineLimit(1)
                                        Text("Were-Vana")
                                            .font(.system(size: 8.5))
                                            .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor.opacity(0.7) : .white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 2.5) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 6, weight: .black))
                                        Text("JOUÉ")
                                            .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(settings.playedTrackColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(settings.playedTrackColor.opacity(0.20))
                                    .cornerRadius(3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(settings.playedTrackColor.opacity(0.55), lineWidth: 0.8)
                                    )
                                    .fixedSize(horizontal: true, vertical: false)
                                    
                                    Text("11A")
                                        .font(.system(size: 8.5, weight: .heavy))
                                        .padding(.horizontal, 3.5)
                                        .padding(.vertical, 1)
                                        .background(Color.accentCyan.opacity(0.2))
                                        .foregroundColor(Color.accentCyan)
                                        .cornerRadius(3)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(settings.playedTrackHighlightStyle != .textOnly ? settings.playedTrackColor.opacity(0.14) : Color.cardBg.opacity(0.55))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(settings.playedTrackHighlightStyle != .textOnly ? settings.playedTrackColor.opacity(0.40) : Color.white.opacity(0.1), lineWidth: 0.8)
                                )
                            }
                            .padding(.top, 2)
                            
                            SettingActionButton(
                                icon: "arrow.counterclockwise",
                                title: "Démarrer une nouvelle session (Reset)"
                            ) {
                                sessionService.resetSession()
                            }
                        }
                    }
                    
                    // SECTION 8 : Guide & Explication des symboles
                    Button {
                        showGuideFromSettings = true
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentCyan.opacity(0.2))
                                    .frame(width: 20, height: 20)
                                Image(systemName: "questionmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(Color.accentCyan)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Guide & Légende des symboles")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Comprendre les flammes, clés Camelot et BPM")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(8)
                        .background(Color.cardBg)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentCyan.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // SECTION 9 : Mentions Légales & Confidentialité
                    settingCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.accentCyan)
                                
                                Text("Mentions Légales & Confidentialité")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• **100 % Local & Hors-ligne** : Aucune donnée personnelle ni télémétrie n'est collectée ou transmise.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("• **Lecture seule** : Accès non destructif à l'historique local (`PRAGMA query_only = ON`).")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text("• **Marques déposées** : Serato DJ Pro est une marque déposée de Serato Limited. Rekordbox est une marque déposée d'AlphaTheta Corporation (Pioneer DJ). Recall est un compagnon indépendant conçu par REVR, sans affiliation, parrainage ni approbation par Serato Limited ou AlphaTheta Corporation.")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.white.opacity(0.50))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    
                    // Bouton Réinitialiser
                    Button {
                        settings.resetToDefaults()
                        monitor.refreshSuggestions()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 9))
                            Text("Restaurer les réglages par défaut")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .frame(minWidth: 350, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
        .background(
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
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .ignoresSafeArea()
        .onExitCommand {
            SettingsWindowController.shared.closeWindow()
            dismiss()
        }
        .sheet(isPresented: $showGuideFromSettings) {
            GuideSheetView()
        }
    }
    
    // Conteneur de carte de réglage avec contraste élevé
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(9)
        .background(Color.cardBg)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }
    
    private func selectRekordboxXmlFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.xml]
        panel.prompt = "Sélectionner la collection Rekordbox"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.rekordboxXmlCustomPath = url.path
            RekordboxService.shared.reloadCollection(from: url.path)
            monitor.refreshSuggestions()
        }
    }
    
    private func quickDayButton(days: Int, label: String) -> some View {
        let isSelected = settings.historyDaysLookback == days
        return Button {
            settings.historyDaysLookback = days
        } label: {
            Text(label)
                .font(.system(size: 9.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(isSelected ? Color.accentCyan.opacity(0.30) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? Color.accentCyan : Color.white.opacity(0.80))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentCyan.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help("\(days) jours d'historique")
    }
    
    private func quickSecondButton(seconds: Int, label: String, isDefault: Bool = false) -> some View {
        let isSelected = settings.playedMinDurationSeconds == seconds
        return Button {
            settings.playedMinDurationSeconds = seconds
            monitor.triggerSessionResync()
        } label: {
            Text(label)
                .font(.system(size: 9.5, weight: isSelected ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .background(isSelected ? Color.accentCyan.opacity(0.30) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? Color.accentCyan : Color.white.opacity(0.80))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentCyan.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isDefault ? "\(label) (délai recommandé par défaut)" : "\(seconds) secondes")
    }
}

// MARK: - Sélecteur segmenté personnalisé à fort contraste

struct CustomSegmentedPicker<T: Hashable>: View {
    let items: [(title: String, value: T)]
    @Binding var selection: T
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.value) { item in
                let isSelected = item.value == selection
                Button {
                    selection = item.value
                } label: {
                    Text(item.title)
                        .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.70))
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(isSelected ? Color.accentCyan.opacity(0.35) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isSelected ? Color.accentCyan.opacity(0.75) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2.5)
        .background(Color.black.opacity(0.35))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Curseur personnalisé haute visibilité

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let percent = max(0.0, min(1.0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            
            ZStack(alignment: .leading) {
                // Piste arrière
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 5)
                
                // Piste active illuminée
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentCyan, Color.accentBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, width * CGFloat(percent)), height: 5)
                
                // Curseur tactile (Thumb)
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().stroke(Color.accentCyan, lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .offset(x: max(0, min(width - 15, width * CGFloat(percent) - 7.5)))
            }
            .frame(height: 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newPercent = max(0.0, min(1.0, gesture.location.x / width))
                        let rawVal = range.lowerBound + Double(newPercent) * (range.upperBound - range.lowerBound)
                        let stepped = (rawVal / step).rounded() * step
                        self.value = max(range.lowerBound, min(range.upperBound, stepped))
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - Bouton d'action standardisé pour les cartes de réglages (sans chrome macOS)

struct SettingActionButton: View {
    let icon: String
    let title: String
    var color: Color = Color.accentCyan
    let action: () -> Void
    
    @State private var isHovered: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isHovered ? color.opacity(0.20) : color.opacity(0.12))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isHovered ? color.opacity(0.55) : color.opacity(0.30), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
