import SwiftUI
import UniformTypeIdentifiers

// MARK: - Catégories de réglages (Onglets)

public enum SettingsTab: String, CaseIterable, Identifiable {
    case djMix = "djMix"
    case appearance = "appearance"
    case session = "session"
    case hotkeys = "hotkeys"
    case about = "about"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .djMix: return "DJ & Mix"
        case .appearance: return "Apparence"
        case .session: return "Session"
        case .hotkeys: return "Raccourcis"
        case .about: return "À propos"
        }
    }
    
    public var icon: String {
        switch self {
        case .djMix: return "slider.horizontal.3"
        case .appearance: return "paintpalette.fill"
        case .session: return "clock.arrow.circlepath"
        case .hotkeys: return "command.square.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Vue Principale des Paramètres

public struct SettingsSheetView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var monitor: SeratoMonitorService
    @ObservedObject private var favService = FavoriteCombosService.shared
    @ObservedObject private var sessionService = SessionHistoryService.shared
    @ObservedObject private var rbService = RekordboxService.shared
    @ObservedObject private var autoUpdate = AutoUpdateService.shared
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("recall_settings_active_tab") private var selectedTabRaw: String = SettingsTab.djMix.rawValue
    @State private var showGuideFromSettings: Bool = false
    
    private var selectedTab: SettingsTab {
        SettingsTab(rawValue: selectedTabRaw) ?? .djMix
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: 1. En-tête supérieur
            headerBar
            
            // MARK: 2. Barre de navigation par onglets
            tabNavigationBar
            
            Divider()
                .background(Color.white.opacity(0.10))
            
            // MARK: 3. Contenu principal selon l'onglet actif
            TabViewContent
        }
        .frame(minWidth: 620, maxWidth: .infinity, minHeight: 520, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.darkBg.opacity(settings.effectiveGlassTintOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    settings.accentColor.opacity(0.25),
                                    Color.white.opacity(0.08)
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
    
    // MARK: - En-tête Supérieur
    
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [settings.accentColor.opacity(0.35), Color.accentBlue.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(settings.accentColor.opacity(0.50), lineWidth: 1)
                    )
                
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(settings.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Paramètres Recall")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("v\(autoUpdate.currentAppVersion)")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        .foregroundColor(settings.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(settings.accentColor.opacity(0.18))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(settings.accentColor.opacity(0.40), lineWidth: 0.8)
                        )
                }
                
                Text("Configurez votre flux de travail DJ, l'apparence et les raccourcis système")
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            Spacer()
            
            Button {
                SettingsWindowController.shared.closeWindow()
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .help("Fermer les paramètres (Échap ou ⌘,)")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color.darkBg.opacity(min(0.95, settings.effectiveGlassTintOpacity + 0.15)))
    }
    
    // MARK: - Barre d'onglets Pro
    
    private var tabNavigationBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                tabButton(for: tab)
            }
            
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .background(Color.darkBg.opacity(min(0.95, settings.effectiveGlassTintOpacity + 0.15)))
    }
    
    private func tabButton(for tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        let fgColor = isSelected ? settings.accentColor : Color.white.opacity(0.70)
        let bgColor = isSelected ? settings.accentColor.opacity(0.18) : Color.white.opacity(0.04)
        let strokeColor = isSelected ? settings.accentColor.opacity(0.65) : Color.white.opacity(0.08)
        
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTabRaw = tab.rawValue
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
                
                Text(tab.title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(fgColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
    
    // MARK: - Contenu de l'onglet actif
    
    @ViewBuilder
    private var TabViewContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                switch selectedTab {
                case .djMix:
                    djMixTabContent
                case .appearance:
                    appearanceTabContent
                case .session:
                    sessionTabContent
                case .hotkeys:
                    hotkeysTabContent
                case .about:
                    aboutTabContent
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: ==========================================
    // MARK: ONGLET 1 : DJ & MIX
    // MARK: ==========================================
    
    @ViewBuilder
    private var djMixTabContent: some View {
        // CARTE 1 : Logiciel DJ & Connexion
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader(icon: "music.note.tv.fill", title: "Logiciel DJ & Source des données")
                    
                    Spacer()
                    
                    // Statut de connexion dynamique
                    HStack(spacing: 5) {
                        Circle()
                            .fill((monitor.isSeratoConnected || monitor.isRekordboxConnected) ? settings.accentColor : Color.white.opacity(0.35))
                            .frame(width: 6, height: 6)
                        
                        Text(monitor.isSeratoConnected ? "Serato actif" : (monitor.isRekordboxConnected ? "Rekordbox actif" : "En attente du logiciel DJ"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor((monitor.isSeratoConnected || monitor.isRekordboxConnected) ? settings.accentColor : .white.opacity(0.65))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(5)
                }
                
                // Sélecteur de mode DJ
                HStack(spacing: 8) {
                    ForEach(DJSoftwareMode.allCases) { mode in
                        let isSelected = settings.djSoftwareMode == mode
                        Button {
                            settings.djSoftwareMode = mode
                            monitor.checkDatabaseUpdates()
                        } label: {
                            Text(mode.shortLabel)
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(isSelected ? settings.accentColor.opacity(0.28) : Color.white.opacity(0.05))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? settings.accentColor.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                    }
                }
                
                // Détails de la source selon le mode
                if monitor.activeDJSoftware == .rekordbox {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Collection & Enchaînements Rekordbox XML")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("\(rbService.totalTracksCount) morceaux • \(rbService.totalTransitionsCount) enchaînements mémorisés")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.white.opacity(0.60))
                            }
                            
                            Spacer()
                            
                            Button {
                                selectRekordboxXmlFile()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.gearshape")
                                        .font(.system(size: 10))
                                    Text("Parcourir...")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(settings.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(settings.accentColor.opacity(0.18))
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(settings.accentColor.opacity(0.45), lineWidth: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                        }
                        
                        if !settings.effectiveRekordboxXmlPath.isEmpty {
                            Text(settings.effectiveRekordboxXmlPath)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        if let err = rbService.errorMessage {
                            Text(err)
                                .font(.system(size: 9))
                                .foregroundColor(.red.opacity(0.85))
                        }
                    }
                    .padding(9)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(7)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(settings.accentColor)
                        
                        Text("Accès direct SQLite WAL Serato (Deck 1 / Deck 2 en temps réel et historique sessions)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.top, 2)
                }
            }
        }
        
        // CARTE 2 : Algorithme de Recommandation & Filtrage
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "waveform.badge.magnifyingglass", title: "Moteur de Recommandation & Filtrage")
                
                // 1. Historique analysé
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Période d'historique analysée")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.90))
                            Text("Recall analyse vos enchaînements passés sur cette durée pour prédire vos transitions favorites.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        Text("\(settings.historyDaysLookback) jours")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .foregroundColor(settings.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(settings.accentColor.opacity(0.20))
                            .cornerRadius(5)
                    }
                    
                    CustomSlider(
                        value: Binding(
                            get: { Double(settings.historyDaysLookback) },
                            set: { settings.historyDaysLookback = Int($0) }
                        ),
                        range: 30...730,
                        step: 15
                    )
                    
                    HStack(spacing: 6) {
                        quickDayButton(days: 90, label: "3 mois (90j)")
                        quickDayButton(days: 180, label: "6 mois (180j)")
                        quickDayButton(days: 360, label: "1 an (360j)")
                        quickDayButton(days: 720, label: "2 ans (720j)")
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // 2. Nombre de suggestions
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Nombre de suggestions affichées en direct")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.90))
                            Text("Quantité maximale de morceaux suggérés par deck.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        CustomSegmentedPicker(
                            items: [
                                ("Top 20", 20),
                                ("Top 30", 30),
                                ("Top 50", 50)
                            ],
                            selection: $settings.maxSuggestions
                        )
                        .frame(width: 220)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // 3. Tolérance BPM
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Tolérance de tempo BPM")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.90))
                            Text("Marge acceptée lors du filtre BPM (inclus demi & double tempo).")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        Text("±\(Int(settings.bpmTolerancePercent))%")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .foregroundColor(settings.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(settings.accentColor.opacity(0.20))
                            .cornerRadius(5)
                    }
                    
                    CustomSlider(
                        value: $settings.bpmTolerancePercent,
                        range: 4...16,
                        step: 1
                    )
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // 4. Cumul des variantes (Edits, Remixes)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cumuler les versions & remixes d'un même morceau")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                        
                        Text("Additionne l'historique d'enchaînements des versions alternatives (Extended, Club Edit, Radio...) partageant la même tonalité et un BPM similaire.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.50))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.cumulateVariantSuggestions)
                        .toggleStyle(.switch)
                        .tint(settings.accentColor)
                        .scaleEffect(0.90)
                }
            }
        }
        
        // CARTE 3 : Harmonie Musicale & Clés Camelot
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "music.quarternote.3", title: "Harmonie Musicale & Clés Camelot")
                
                // Format d'affichage des clés
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Système de notation des clés harmoniques")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.90))
                            Text("Choisissez votre affichage favori pour la roue harmonique.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        CustomSegmentedPicker(
                            items: [
                                ("Camelot (9A)", 0),
                                ("Musicale (Em)", 1),
                                ("Combiné (9A / Em)", 2)
                            ],
                            selection: $settings.keyDisplayMode
                        )
                        .frame(width: 270)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Options harmoniques avancées
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sauts d'énergie (Energy Boost)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                            Text("Inclure les montées d'énergie +1 demi-ton (+7) et +1 ton (+2) sur la roue Camelot.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.includeEnergyBoostInHarmonicFilter)
                            .toggleStyle(.switch)
                            .tint(settings.accentColor)
                            .scaleEffect(0.90)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Transitions diagonales modales")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                            Text("Autoriser les passages entre modes Majeur ⇄ Mineur voisins (ex: 8A ⇄ 9B).")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.includeDiagonalInHarmonicFilter)
                            .toggleStyle(.switch)
                            .tint(settings.accentColor)
                            .scaleEffect(0.90)
                    }
                }
            }
        }
    }
    
    // MARK: ==========================================
    // MARK: ONGLET 2 : APPARENCE & FENÊTRE
    // MARK: ==========================================
    
    @ViewBuilder
    private var appearanceTabContent: some View {
        // CARTE 1 : Thèmes DJ & Verre dépoli
        settingCard {
            DJThemeSettingsCard()
        }
        
        // CARTE 2 : Comportement de la Fenêtre
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "macwindow", title: "Fenêtre & Positionnement")
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toujours au premier plan (Floating Window)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                        Text("Conserve la fenêtre Recall au-dessus de Rekordbox ou Serato pendant le mix.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.50))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.alwaysOnTop)
                        .toggleStyle(.switch)
                        .tint(settings.accentColor)
                        .scaleEffect(0.90)
                        .onChange(of: settings.alwaysOnTop) { val in
                            FloatingWindowController.shared.updateAlwaysOnTop(val)
                        }
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                SettingActionButton(
                    icon: "arrow.down.right.and.arrow.up.left",
                    title: "Recentrer Recall en bas à droite de l'écran principal"
                ) {
                    FloatingWindowController.shared.positionAtBottomRight()
                }
            }
        }
    }
    
    // MARK: ==========================================
    // MARK: ONGLET 3 : SESSION & EN DIRECT
    // MARK: ==========================================
    
    @ViewBuilder
    private var sessionTabContent: some View {
        // CARTE 1 : Détection & Filtrage
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader(icon: "clock.arrow.circlepath", title: "Détection en Direct de la Session")
                    
                    Spacer()
                    
                    Text("\(sessionService.playedCount) morceaux joués")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundColor(sessionService.playedCount > 0 ? settings.accentColor : .white.opacity(0.45))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(sessionService.playedCount > 0 ? settings.accentColor.opacity(0.18) : Color.white.opacity(0.06))
                        .cornerRadius(5)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Masquer automatiquement les morceaux déjà joués")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                        Text("Retire les titres déjà passés de la liste de suggestions pour éviter les doublons.")
                            .font(.system(size: 9.5))
                            .foregroundColor(.white.opacity(0.50))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.hidePlayedTracks)
                        .toggleStyle(.switch)
                        .tint(settings.accentColor)
                        .scaleEffect(0.90)
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Délai anti-préécoute
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Délai de validation (anti-préécoute au casque)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.90))
                            Text("Un morceau doit tourner au moins \(settings.playedMinDurationSeconds)s pour être mémorisé comme joué (25s par défaut).")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            if settings.playedMinDurationSeconds == 25 {
                                Text("Recommandé")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(settings.accentColor.opacity(0.85))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(settings.accentColor.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Text("\(settings.playedMinDurationSeconds) sec")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundColor(settings.accentColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(settings.accentColor.opacity(0.20))
                                .cornerRadius(5)
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
                    
                    HStack(spacing: 6) {
                        quickSecondButton(seconds: 10, label: "10s (Ultra rapide)")
                        quickSecondButton(seconds: 15, label: "15s")
                        quickSecondButton(seconds: 25, label: "25s (Défaut DJ)", isDefault: true)
                        quickSecondButton(seconds: 45, label: "45s")
                        quickSecondButton(seconds: 60, label: "60s (Mix posé)")
                    }
                }
            }
        }
        
        // CARTE 2 : Marquage Visuel & Couleur
        settingCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "eyedropper.halffull", title: "Marquage Visuel des Morceaux Joués")
                
                // Sélecteur de couleur
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Couleur d'identification")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.90))
                        
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
                            .font(.system(size: 10, weight: .bold))
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
                    
                    HStack(spacing: 12) {
                        ForEach(presetColors, id: \.hex) { preset in
                            let isSelected = settings.playedTrackColorHex.uppercased() == preset.hex.uppercased()
                            Button {
                                settings.playedTrackColorHex = preset.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 24, height: 24)
                                    
                                    if isSelected {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }
                        
                        // Sélecteur de couleur natif macOS
                        ColorPicker("", selection: Binding(
                            get: { settings.playedTrackColor },
                            set: { newCol in
                                if let hex = newCol.toHex() {
                                    settings.playedTrackColorHex = hex
                                }
                            }
                        ))
                        .labelsHidden()
                        .scaleEffect(0.90)
                        .help("Choisir une couleur personnalisée")
                        
                        Spacer()
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.08))
                
                // Style d'affichage
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style d'affichage dans la liste")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                    
                    HStack(spacing: 8) {
                        ForEach(PlayedTrackHighlightStyle.allCases) { style in
                            let isSelected = settings.playedTrackHighlightStyle == style
                            Button {
                                settings.playedTrackHighlightStyle = style
                            } label: {
                                Text(style.label)
                                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? settings.playedTrackColor.opacity(0.25) : Color.white.opacity(0.06))
                                    .foregroundColor(isSelected ? settings.playedTrackColor : .white.opacity(0.70))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? settings.playedTrackColor.opacity(0.75) : Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Grand aperçu en direct
                VStack(alignment: .leading, spacing: 5) {
                    Text("Aperçu en direct :")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.50))
                    
                    HStack(spacing: 10) {
                        Text("3")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor : .white.opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Were-Vana - Casanova (Tomy B Intro)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor : .white)
                                .lineLimit(1)
                            Text("Were-Vana • Afrobeats")
                                .font(.system(size: 9.5))
                                .foregroundColor(settings.playedTrackHighlightStyle != .bgOnly ? settings.playedTrackColor.opacity(0.75) : .white.opacity(0.50))
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 7, weight: .black))
                            Text("JOUÉ")
                                .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(settings.playedTrackColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(settings.playedTrackColor.opacity(0.22))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(settings.playedTrackColor.opacity(0.60), lineWidth: 0.8)
                        )
                        
                        Text(CamelotKey(number: 11, letter: "A").displayText(mode: settings.keyDisplayMode))
                            .font(.system(size: 9.5, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(settings.accentColor.opacity(0.22))
                            .foregroundColor(settings.accentColor)
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(settings.playedTrackHighlightStyle != .textOnly ? settings.playedTrackColor.opacity(0.14) : Color.cardBg.opacity(0.60))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(settings.playedTrackHighlightStyle != .textOnly ? settings.playedTrackColor.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .padding(.top, 2)
            }
        }
        
        // CARTE 3 : Outils de Session
        settingCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(icon: "wrench.and.screwdriver.fill", title: "Outils de Session & Récapitulatif")
                
                HStack(spacing: 8) {
                    SettingActionButton(
                        icon: "chart.bar.xaxis",
                        title: "Statistiques du Mix (Set Recap…)"
                    ) {
                        SettingsWindowController.shared.closeWindow()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            SetRecapWindowController.shared.show()
                        }
                    }
                    
                    SettingActionButton(
                        icon: "list.bullet.rectangle.portrait",
                        title: "Générateur de Tracklist (YouTube, 1001TL…)"
                    ) {
                        SettingsWindowController.shared.closeWindow()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            TracklistGeneratorWindowController.shared.show()
                        }
                    }
                }
                
                SettingActionButton(
                    icon: "arrow.counterclockwise",
                    title: "Démarrer une nouvelle session (Reset)",
                    color: Color(hex: "#FF5252")
                ) {
                    sessionService.resetSession()
                }
            }
        }
    }
    
    // MARK: ==========================================
    // MARK: ONGLET 4 : RACCOURCIS CLAVIER
    // MARK: ==========================================
    
    @ViewBuilder
    private var hotkeysTabContent: some View {
        settingCard {
            HotKeySettingsCard()
        }
    }
    
    // MARK: ==========================================
    // MARK: ONGLET 5 : À PROPOS & FAVORIS
    // MARK: ==========================================
    
    @ViewBuilder
    private var aboutTabContent: some View {
        // CARTE 1 : Combos Favoris
        settingCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader(icon: "heart.fill", title: "Combos Favoris Mémorisés (\(favService.combos.count))", iconColor: Color(hex: "#FF5252"))
                    
                    Spacer()
                    
                    if !favService.combos.isEmpty {
                        Button {
                            favService.clearAllCombos()
                        } label: {
                            Text("Tout effacer")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if favService.combos.isEmpty {
                    Text("Aucune combinaison enregistrée. Cliquez sur le cœur ❤️ ou sur '+ Combo' dans Recall pour sauvegarder vos meilleurs enchaînements.")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 6) {
                        ForEach(favService.combos.prefix(10)) { combo in
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "#FF5252"))
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(combo.track1.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 7))
                                            .foregroundColor(settings.accentColor)
                                        Text(combo.track2.title)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(settings.accentColor)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    favService.deleteCombo(byId: combo.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.40))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(6)
                        }
                        
                        if favService.combos.count > 10 {
                            Text("+ \(favService.combos.count - 10) autres combinaisons...")
                                .font(.system(size: 9.5))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
            }
        }
        
        // CARTE 2 : Mises à jour du logiciel Recall
        settingCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader(icon: "arrow.triangle.2.circlepath.circle.fill", title: "Mises à jour du logiciel Recall")
                    
                    Spacer()
                    
                    Text("v\(autoUpdate.currentAppVersion)")
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundColor(settings.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(settings.accentColor.opacity(0.18))
                        .cornerRadius(5)
                }
                
                if autoUpdate.isUpdateAvailable, let release = autoUpdate.availableUpdate {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(settings.accentColor)
                        
                        Text("Version \(release.tagName) disponible !")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            autoUpdate.openDownload()
                        } label: {
                            Text("Télécharger (DMG)")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(settings.accentColor)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(9)
                    .background(settings.accentColor.opacity(0.14))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(settings.accentColor.opacity(0.45), lineWidth: 0.8)
                    )
                } else {
                    Text("Recall vérifie automatiquement les nouvelles versions au démarrage si une connexion Internet est active.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let status = autoUpdate.manualCheckStatus {
                    Text(status)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(autoUpdate.isUpdateAvailable ? settings.accentColor : .white.opacity(0.70))
                }
                
                SettingActionButton(
                    icon: "arrow.clockwise",
                    title: autoUpdate.isChecking ? "Recherche en cours..." : "Rechercher une mise à jour maintenant"
                ) {
                    UpdateWindowController.shared.show()
                }
            }
        }
        
        // CARTE 3 : Ressources & Retours REVR
        settingCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(icon: "questionmark.circle.fill", title: "Documentation & Retours d'expérience")
                
                HStack(spacing: 8) {
                    SettingActionButton(
                        icon: "book.fill",
                        title: "Guide & Légende des symboles"
                    ) {
                        showGuideFromSettings = true
                    }
                    
                    SettingActionButton(
                        icon: "paperplane.fill",
                        title: "Faire un retour à REVR (Web) ↗"
                    ) {
                        if let url = URL(string: "https://revrmusic.github.io/recall/?feedback=1&source=app_macos") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        
        // CARTE 4 : Mentions Légales & Confidentialité
        settingCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(icon: "lock.shield.fill", title: "Mentions Légales & Confidentialité")
                
                VStack(alignment: .leading, spacing: 5) {
                    Text("• **100 % Local & Hors-ligne** : Aucune donnée personnelle, statistique d'écoute ni télémétrie n'est collectée ou transmise.")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("• **Lecture seule** : Accès non destructif à l'historique local SQLite (`PRAGMA query_only = ON`).")
                        .font(.system(size: 9.5))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("• **Marques déposées** : Serato DJ Pro est une marque déposée de Serato Limited. Rekordbox est une marque déposée d'AlphaTheta Corporation (Pioneer DJ). Recall est un outil indépendant conçu par REVR, sans affiliation, parrainage ni approbation par Serato Limited ou AlphaTheta Corporation.")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.50))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        
        // Bouton Réinitialiser par défaut
        Button {
            settings.resetToDefaults()
            monitor.refreshSuggestions()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 9.5))
                Text("Restaurer tous les réglages par défaut")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Composants UI Communs
    
    private func sectionHeader(icon: String, title: String, iconColor: Color? = nil) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(iconColor ?? settings.accentColor)
            
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(13)
        .background(Color.cardBg.opacity(min(0.85, 0.25 + (1.0 - settings.glassTranslucency) * 0.60)))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
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
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(isSelected ? settings.accentColor.opacity(0.30) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? settings.accentColor : Color.white.opacity(0.80))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? settings.accentColor.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
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
                .font(.system(size: 10, weight: isSelected ? .bold : .semibold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(isSelected ? settings.accentColor.opacity(0.30) : Color.white.opacity(0.06))
                .foregroundColor(isSelected ? settings.accentColor : Color.white.opacity(0.80))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isSelected ? settings.accentColor.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isDefault ? "\(label) (délai recommandé par défaut)" : "\(seconds) secondes")
    }
}

// MARK: - Sélecteur segmenté personnalisé haute lisibilité

struct CustomSegmentedPicker<T: Hashable>: View {
    let items: [(title: String, value: T)]
    @Binding var selection: T
    @EnvironmentObject var settings: UserSettings
    
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
                                .fill(isSelected ? settings.accentColor.opacity(0.35) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isSelected ? settings.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
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
    @EnvironmentObject var settings: UserSettings
    
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
                            colors: [settings.accentColor, settings.accentColor.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, width * CGFloat(percent)), height: 5)
                
                // Curseur tactile (Thumb)
                Circle()
                    .fill(Color.white)
                    .frame(width: 15, height: 15)
                    .overlay(Circle().stroke(settings.accentColor, lineWidth: 2))
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

// MARK: - Bouton d'action standardisé pour les cartes de réglages

struct SettingActionButton: View {
    let icon: String
    let title: String
    var color: Color? = nil
    let action: () -> Void
    
    @EnvironmentObject var settings: UserSettings
    @State private var isHovered: Bool = false
    
    private var effectiveColor: Color {
        color ?? settings.accentColor
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(effectiveColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isHovered ? effectiveColor.opacity(0.20) : effectiveColor.opacity(0.12))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? effectiveColor.opacity(0.55) : effectiveColor.opacity(0.30), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("setting_btn_\(title)")
        .onHover { isHovered = $0 }
    }
}
