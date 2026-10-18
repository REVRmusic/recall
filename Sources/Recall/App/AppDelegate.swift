import Cocoa
import SwiftUI

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        // Enregistrement du gestionnaire de crash pour consigner les erreurs fatales
        AppLogger.shared.registerCrashHandler()
        AppLogger.info("Démarrage de Recall...", category: .system)
        
        // Délai de survol optimisé (0.9s) évitant les déclenchements intempestifs tout en restant réactif
        let tooltipDelayMs = 900
        UserDefaults.standard.register(defaults: [
            "NSInitialToolTipDelay": tooltipDelayMs,
            "NSReshowToolTipDelay": tooltipDelayMs,
            "NSAutoToolTipDelay": tooltipDelayMs
        ])
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSInitialToolTipDelay")
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSReshowToolTipDelay")
        UserDefaults.standard.set(tooltipDelayMs, forKey: "NSAutoToolTipDelay")
        
        // Configuration de la barre de menus native de macOS
        setupMainMenu()
        
        let windowController = FloatingWindowController.shared
        windowController.show()
        NSApp.activate(ignoringOtherApps: true)
        
        // Enregistrement des raccourcis clavier globaux système (Hotkeys)
        GlobalHotKeyService.shared.updateRegistrations(preset: UserSettings.shared.hotKeyPreset)
        
        // Surveillance active
        SeratoMonitorService.shared.startMonitoring()
        
        // Recherche de mise à jour automatique au démarrage (uniquement si connecté à Internet)
        AutoUpdateService.shared.checkForUpdatesOnStartup()
        
        AppLogger.info("Recall initialisé avec succès et prêt.", category: .system)
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppLogger.info("Fermeture de Recall en cours...", category: .system)
        SeratoMonitorService.shared.stopMonitoring()
        UserDefaults.standard.synchronize()
        AppLogger.shared.handleApplicationWillTerminate()
    }
    
    // MARK: - Configuration de la Barre de Menus macOS (Menu Bar)
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // -------------------------------------------------------------
        // 1. Menu Application : "Recall"
        // -------------------------------------------------------------
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Recall")
        
        let aboutItem = NSMenuItem(
            title: "À propos de Recall",
            action: #selector(showAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        let checkUpdateItem = NSMenuItem(
            title: "Rechercher les mises à jour…",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        checkUpdateItem.target = self
        appMenu.addItem(checkUpdateItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(
            title: "Paramètres…",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        // Sous-menu Services standard macOS
        let servicesMenuItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesMenuItem.submenu = servicesMenu
        appMenu.addItem(servicesMenuItem)
        NSApp.servicesMenu = servicesMenu
        
        appMenu.addItem(NSMenuItem.separator())
        
        let hideItem = NSMenuItem(
            title: "Masquer Recall",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)
        
        let hideOthersItem = NSMenuItem(
            title: "Masquer les autres",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        
        let showAllItem = NSMenuItem(
            title: "Tout afficher",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(
            title: "Quitter Recall",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // -------------------------------------------------------------
        // 2. Menu "Fichier"
        // -------------------------------------------------------------
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "Fichier")
        
        let newSessionItem = NSMenuItem(
            title: "Nouvelle session DJ…",
            action: #selector(resetSessionAction),
            keyEquivalent: "n"
        )
        newSessionItem.target = self
        fileMenu.addItem(newSessionItem)
        
        let resyncItem = NSMenuItem(
            title: "Resynchroniser avec le logiciel DJ",
            action: #selector(triggerSessionResyncAction),
            keyEquivalent: "r"
        )
        resyncItem.target = self
        fileMenu.addItem(resyncItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        
        let tracklistItem = NSMenuItem(
            title: "Générateur de Tracklist…",
            action: #selector(openTracklistGeneratorAction),
            keyEquivalent: "T"
        )
        tracklistItem.keyEquivalentModifierMask = [.command, .shift]
        tracklistItem.target = self
        fileMenu.addItem(tracklistItem)
        
        let setRecapItem = NSMenuItem(
            title: "Statistiques du Mix (Set Recap)…",
            action: #selector(openSetRecapAction),
            keyEquivalent: "S"
        )
        setRecapItem.keyEquivalentModifierMask = [.command, .shift]
        setRecapItem.target = self
        fileMenu.addItem(setRecapItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        
        let closeWindowItem = NSMenuItem(
            title: "Fermer la fenêtre",
            action: #selector(closeWindowAction),
            keyEquivalent: "w"
        )
        closeWindowItem.target = self
        fileMenu.addItem(closeWindowItem)
        
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)
        
        // -------------------------------------------------------------
        // 3. Menu "Édition" (Annuler, Rétablir, Couper, Copier, Coller)
        // -------------------------------------------------------------
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Édition")
        
        editMenu.addItem(NSMenuItem(title: "Annuler", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Rétablir", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Couper", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copier", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Coller", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Tout sélectionner", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        editMenu.addItem(NSMenuItem.separator())
        
        let searchItem = NSMenuItem(
            title: "Rechercher un morceau…",
            action: #selector(openSearchAction),
            keyEquivalent: "f"
        )
        searchItem.target = self
        editMenu.addItem(searchItem)
        
        editMenu.addItem(NSMenuItem.separator())
        
        let clearToPlayItem = NSMenuItem(
            title: "Vider la liste « À jouer »…",
            action: #selector(clearToPlayAction),
            keyEquivalent: ""
        )
        clearToPlayItem.target = self
        editMenu.addItem(clearToPlayItem)
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // -------------------------------------------------------------
        // 4. Menu "Outils de session"
        // -------------------------------------------------------------
        let sessionMenuItem = NSMenuItem()
        let sessionMenu = NSMenu(title: "Outils de session")
        sessionMenu.delegate = self
        
        let sessionRecapItem = NSMenuItem(
            title: "Statistiques du Mix (Set Recap)…",
            action: #selector(openSetRecapAction),
            keyEquivalent: "S"
        )
        sessionRecapItem.keyEquivalentModifierMask = [.command, .shift]
        sessionRecapItem.target = self
        sessionMenu.addItem(sessionRecapItem)
        
        let sessionTracklistItem = NSMenuItem(
            title: "Générateur de Tracklist…",
            action: #selector(openTracklistGeneratorAction),
            keyEquivalent: "T"
        )
        sessionTracklistItem.keyEquivalentModifierMask = [.command, .shift]
        sessionTracklistItem.target = self
        sessionMenu.addItem(sessionTracklistItem)
        
        let sessionSearchItem = NSMenuItem(
            title: "Rechercher dans la bibliothèque DJ…",
            action: #selector(openSearchAction),
            keyEquivalent: "F"
        )
        sessionSearchItem.keyEquivalentModifierMask = [.command, .option]
        sessionSearchItem.target = self
        sessionMenu.addItem(sessionSearchItem)
        
        sessionMenu.addItem(NSMenuItem.separator())
        
        let sessionResyncItem = NSMenuItem(
            title: "Resynchroniser avec Serato / Rekordbox",
            action: #selector(triggerSessionResyncAction),
            keyEquivalent: "R"
        )
        sessionResyncItem.keyEquivalentModifierMask = [.command, .shift]
        sessionResyncItem.target = self
        sessionMenu.addItem(sessionResyncItem)
        
        let sessionResetItem = NSMenuItem(
            title: "Nouvelle session DJ (Réinitialiser le set)…",
            action: #selector(resetSessionAction),
            keyEquivalent: "N"
        )
        sessionResetItem.keyEquivalentModifierMask = [.command, .shift]
        sessionResetItem.target = self
        sessionMenu.addItem(sessionResetItem)
        
        let sessionClearToPlayItem = NSMenuItem(
            title: "Vider la liste « À jouer »…",
            action: #selector(clearToPlayAction),
            keyEquivalent: ""
        )
        sessionClearToPlayItem.target = self
        sessionMenu.addItem(sessionClearToPlayItem)
        
        let sessionClearOverrideItem = NSMenuItem(
            title: "Effacer le forçage manuel de morceau",
            action: #selector(clearManualOverrideAction),
            keyEquivalent: ""
        )
        sessionClearOverrideItem.target = self
        sessionMenu.addItem(sessionClearOverrideItem)
        
        sessionMenu.addItem(NSMenuItem.separator())
        
        // Section Télémétrie & État en direct
        let statusHeaderItem = NSMenuItem(title: "ÉTAT EN DIRECT", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        sessionMenu.addItem(statusHeaderItem)
        
        let liveTrackItem = NSMenuItem(title: "▶︎ Morceau : Aucun morceau détecté", action: nil, keyEquivalent: "")
        liveTrackItem.tag = 1001
        liveTrackItem.isEnabled = false
        sessionMenu.addItem(liveTrackItem)
        
        let liveCountItem = NSMenuItem(title: "● 0 morceau joué dans ce set", action: nil, keyEquivalent: "")
        liveCountItem.tag = 1002
        liveCountItem.isEnabled = false
        sessionMenu.addItem(liveCountItem)
        
        let liveSoftwareItem = NSMenuItem(title: "● En attente de connexion DJ", action: nil, keyEquivalent: "")
        liveSoftwareItem.tag = 1003
        liveSoftwareItem.isEnabled = false
        sessionMenu.addItem(liveSoftwareItem)
        
        sessionMenuItem.submenu = sessionMenu
        mainMenu.addItem(sessionMenuItem)
        
        // -------------------------------------------------------------
        // 5. Menu "Fenêtre"
        // -------------------------------------------------------------
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenêtre")
        
        let toggleVisibilityItem = NSMenuItem(
            title: "Afficher / Masquer Recall",
            action: #selector(toggleVisibilityAction),
            keyEquivalent: "r"
        )
        toggleVisibilityItem.keyEquivalentModifierMask = [.command, .option]
        toggleVisibilityItem.target = self
        windowMenu.addItem(toggleVisibilityItem)
        
        let toggleCompactItem = NSMenuItem(
            title: "Mode Compact (Bandeau DJ)",
            action: #selector(toggleCompactAction),
            keyEquivalent: "k"
        )
        toggleCompactItem.target = self
        windowMenu.addItem(toggleCompactItem)
        
        let togglePinItem = NSMenuItem(
            title: "Toujours au premier plan",
            action: #selector(toggleAlwaysOnTopAction),
            keyEquivalent: ""
        )
        togglePinItem.target = self
        windowMenu.addItem(togglePinItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        // Sous-menu Thème DJ
        let themeSubmenuItem = NSMenuItem(title: "Thème DJ", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "Thème DJ")
        
        let cyanItem = NSMenuItem(title: "Cyan Neon (Défaut)", action: #selector(setThemeCyanNeonAction), keyEquivalent: "")
        cyanItem.target = self
        themeMenu.addItem(cyanItem)
        
        let purpleItem = NSMenuItem(title: "Electric Purple", action: #selector(setThemeElectricPurpleAction), keyEquivalent: "")
        purpleItem.target = self
        themeMenu.addItem(purpleItem)
        
        let amberItem = NSMenuItem(title: "Sunset Amber", action: #selector(setThemeSunsetAmberAction), keyEquivalent: "")
        amberItem.target = self
        themeMenu.addItem(amberItem)
        
        let greenItem = NSMenuItem(title: "Acid Green", action: #selector(setThemeAcidGreenAction), keyEquivalent: "")
        greenItem.target = self
        themeMenu.addItem(greenItem)
        
        themeSubmenuItem.submenu = themeMenu
        windowMenu.addItem(themeSubmenuItem)
        
        // Sous-menu Translucidité (Verre dépoli)
        let glassSubmenuItem = NSMenuItem(title: "Translucidité du verre", action: nil, keyEquivalent: "")
        let glassMenu = NSMenu(title: "Translucidité du verre")
        
        let glass80Item = NSMenuItem(title: "Flou discret (80%)", action: #selector(setGlassTranslucency80Action), keyEquivalent: "")
        glass80Item.target = self
        glassMenu.addItem(glass80Item)
        
        let glass50Item = NSMenuItem(title: "Équilibré (50% - Recommandé)", action: #selector(setGlassTranslucency50Action), keyEquivalent: "")
        glass50Item.target = self
        glassMenu.addItem(glass50Item)
        
        let glass20Item = NSMenuItem(title: "Très transparent (20%)", action: #selector(setGlassTranslucency20Action), keyEquivalent: "")
        glass20Item.target = self
        glassMenu.addItem(glass20Item)
        
        let glass0Item = NSMenuItem(title: "Opaque (0%)", action: #selector(setGlassTranslucency0Action), keyEquivalent: "")
        glass0Item.target = self
        glassMenu.addItem(glass0Item)
        
        glassSubmenuItem.submenu = glassMenu
        windowMenu.addItem(glassSubmenuItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        let minimizeItem = NSMenuItem(
            title: "Réduire",
            action: #selector(NSWindow.miniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)
        
        let zoomItem = NSMenuItem(
            title: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoomItem)
        
        windowMenu.addItem(NSMenuItem.separator())
        
        let bringAllItem = NSMenuItem(
            title: "Tout ramener au premier plan",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(bringAllItem)
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        
        // -------------------------------------------------------------
        // 6. Menu "Aide"
        // -------------------------------------------------------------
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Aide")
        
        let guideItem = NSMenuItem(
            title: "Guide d'utilisation de Recall…",
            action: #selector(openGuideAction),
            keyEquivalent: ""
        )
        guideItem.target = self
        helpMenu.addItem(guideItem)
        
        let hotkeyItem = NSMenuItem(
            title: "Raccourcis Clavier DJ…",
            action: #selector(openHotKeySettingsAction),
            keyEquivalent: ""
        )
        hotkeyItem.target = self
        helpMenu.addItem(hotkeyItem)
        
        helpMenu.addItem(NSMenuItem.separator())
        
        let checkUpdateHelpItem = NSMenuItem(
            title: "Rechercher les mises à jour…",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        checkUpdateHelpItem.target = self
        helpMenu.addItem(checkUpdateHelpItem)
        
        helpMenu.addItem(NSMenuItem.separator())
        
        let websiteItem = NSMenuItem(
            title: "Site officiel (mixify.fr)",
            action: #selector(openWebsiteAction),
            keyEquivalent: ""
        )
        websiteItem.target = self
        helpMenu.addItem(websiteItem)
        
        let supportItem = NSMenuItem(
            title: "Support DJ (support@mixify.fr)",
            action: #selector(openSupportEmailAction),
            keyEquivalent: ""
        )
        supportItem.target = self
        helpMenu.addItem(supportItem)
        
        let feedbackHelpItem = NSMenuItem(
            title: "Suggérer une amélioration…",
            action: #selector(openFeedbackWebsiteAction),
            keyEquivalent: ""
        )
        feedbackHelpItem.target = self
        helpMenu.addItem(feedbackHelpItem)
        
        helpMenu.addItem(NSMenuItem.separator())
        
        let logsHeaderItem = NSMenuItem(title: "DIAGNOSTICS & LOGS", action: nil, keyEquivalent: "")
        logsHeaderItem.isEnabled = false
        helpMenu.addItem(logsHeaderItem)
        
        let showLogsItem = NSMenuItem(
            title: "Afficher les logs dans le Finder",
            action: #selector(openLogsFolderAction),
            keyEquivalent: ""
        )
        showLogsItem.target = self
        helpMenu.addItem(showLogsItem)
        
        let exportLogsItem = NSMenuItem(
            title: "Exporter le rapport de diagnostic (Logs)…",
            action: #selector(exportDiagnosticReportAction),
            keyEquivalent: ""
        )
        exportLogsItem.target = self
        helpMenu.addItem(exportLogsItem)
        
        helpMenu.addItem(NSMenuItem.separator())
        
        let githubItem = NSMenuItem(
            title: "Dépôt GitHub",
            action: #selector(openGithubAction),
            keyEquivalent: ""
        )
        githubItem.target = self
        helpMenu.addItem(githubItem)
        
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)
        NSApp.helpMenu = helpMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Actions du Menu
    
    @objc private func openSettingsAction() {
        SettingsWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openTracklistGeneratorAction() {
        TracklistGeneratorWindowController.shared.show()
    }
    
    @objc private func openSetRecapAction() {
        SetRecapWindowController.shared.show()
    }
    
    @objc private func checkForUpdatesAction() {
        UpdateWindowController.shared.show()
    }
    
    @objc private func openFeedbackWebsiteAction() {
        if let url = URL(string: "https://mixify.fr") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openSupportEmailAction() {
        if let url = URL(string: "mailto:support@mixify.fr?subject=Recall%20Support%20DJ") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openGuideAction() {
        FloatingWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .recallTriggerGuide, object: nil)
    }
    
    @objc private func openHotKeySettingsAction() {
        UserDefaults.standard.set(SettingsTab.hotkeys.rawValue, forKey: "recall_settings_active_tab")
        SettingsWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func openSearchAction() {
        GlobalHotKeyService.shared.performOpenSearch()
    }
    
    @objc private func triggerSessionResyncAction() {
        SeratoMonitorService.shared.triggerSessionResync()
    }
    
    @objc private func resetSessionAction() {
        let alert = NSAlert()
        alert.messageText = "Démarrer une nouvelle session de mix ?"
        alert.informativeText = "Cette action réinitialise l'historique des morceaux joués pour le set en cours.\nLes suggestions et statistiques repartiront à zéro.\n\nVos favoris, combos et préréglages restent intacts."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Réinitialiser la session")
        alert.addButton(withTitle: "Annuler")
        
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SessionHistoryService.shared.resetSession()
        }
    }
    
    @objc private func clearToPlayAction() {
        let count = ToPlayService.shared.tracks.count
        guard count > 0 else { return }
        
        let alert = NSAlert()
        alert.messageText = "Vider la liste « À jouer » ?"
        alert.informativeText = "Cette action retirera les \(count) morceau(x) actuellement mis en attente pour votre mix."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Vider la liste")
        alert.addButton(withTitle: "Annuler")
        
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            ToPlayService.shared.clearAll()
        }
    }
    
    @objc private func clearManualOverrideAction() {
        SeratoMonitorService.shared.clearManualOverride()
    }
    
    @objc private func toggleVisibilityAction() {
        GlobalHotKeyService.shared.performToggleVisibility()
    }
    
    @objc private func showAboutAction() {
        let alert = NSAlert()
        alert.messageText = "Recall \(AutoUpdateService.shared.currentAppVersion)"
        alert.informativeText = "Compagnon intelligent en direct pour Serato DJ Pro & Rekordbox.\nConçu pour assister les DJs en live.\n\n100% local • Aucune collecte de données • Léger & Réactif."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Site officiel")
        alert.addButton(withTitle: "Rechercher une mise à jour")
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            openWebsiteAction()
        } else if response == .alertThirdButtonReturn {
            checkForUpdatesAction()
        }
    }
    
    @objc private func closeWindowAction() {
        if SetRecapWindowController.shared.isVisible {
            SetRecapWindowController.shared.closeWindow()
        } else if TracklistGeneratorWindowController.shared.isVisible {
            TracklistGeneratorWindowController.shared.closeWindow()
        } else if UpdateWindowController.shared.isVisible {
            UpdateWindowController.shared.closeWindow()
        } else if SettingsWindowController.shared.isVisible {
            SettingsWindowController.shared.closeWindow()
        } else {
            FloatingWindowController.shared.window?.orderOut(nil)
        }
    }
    
    @objc private func showRecallAction() {
        FloatingWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func toggleCompactAction() {
        GlobalHotKeyService.shared.performToggleCompact()
    }
    
    @objc private func toggleAlwaysOnTopAction() {
        UserSettings.shared.alwaysOnTop.toggle()
        FloatingWindowController.shared.updateAlwaysOnTop(UserSettings.shared.alwaysOnTop)
    }
    
    @objc private func setThemeCyanNeonAction() {
        UserSettings.shared.djTheme = .cyanNeon
    }
    
    @objc private func setThemeElectricPurpleAction() {
        UserSettings.shared.djTheme = .electricPurple
    }
    
    @objc private func setThemeSunsetAmberAction() {
        UserSettings.shared.djTheme = .sunsetAmber
    }
    
    @objc private func setThemeAcidGreenAction() {
        UserSettings.shared.djTheme = .acidGreen
    }
    
    @objc private func setGlassTranslucency80Action() {
        UserSettings.shared.glassTranslucency = 0.80
    }
    
    @objc private func setGlassTranslucency50Action() {
        UserSettings.shared.glassTranslucency = 0.50
    }
    
    @objc private func setGlassTranslucency20Action() {
        UserSettings.shared.glassTranslucency = 0.20
    }
    
    @objc private func setGlassTranslucency0Action() {
        UserSettings.shared.glassTranslucency = 0.0
    }
    
    @objc private func openWebsiteAction() {
        if let url = URL(string: "https://mixify.fr") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openLogsFolderAction() {
        AppLogger.shared.revealInFinder()
    }
    
    @objc private func exportDiagnosticReportAction() {
        let savePanel = NSSavePanel()
        savePanel.title = "Exporter le rapport de diagnostic Recall"
        savePanel.prompt = "Enregistrer"
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmm"
        savePanel.nameFieldStringValue = "Recall_Diagnostic_\(df.string(from: Date())).txt"
        savePanel.canCreateDirectories = true
        
        NSApp.activate(ignoringOtherApps: true)
        if savePanel.runModal() == .OK, let url = savePanel.url {
            let report = AppLogger.shared.generateDiagnosticReport()
            do {
                try report.write(to: url, atomically: true, encoding: .utf8)
                let alert = NSAlert()
                alert.messageText = "Rapport de diagnostic exporté"
                alert.informativeText = "Le rapport de diagnostic a été enregistré avec succès.\nVous pouvez l'envoyer à support@mixify.fr pour nous aider à analyser tout dysfonctionnement."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Afficher dans le Finder")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Erreur lors de l'exportation"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    @objc private func openGithubAction() {
        if let url = URL(string: "https://github.com/REVRmusic/recall") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Délégation Dynamique des Menus (Mise à jour en temps réel)

extension AppDelegate: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        if menu.title == "Outils de session" {
            updateSessionMenuLiveInfo(menu)
        }
    }
    
    private func updateSessionMenuLiveInfo(_ menu: NSMenu) {
        if let liveTrackItem = menu.item(withTag: 1001) {
            if let current = SeratoMonitorService.shared.currentTrack {
                let title = current.smartParsed.title.isEmpty ? current.title : current.smartParsed.title
                let artist = current.smartParsed.artist ?? current.artist
                let label = artist.isEmpty ? title : "\(artist) – \(title)"
                liveTrackItem.title = "▶︎ Morceau : \(label)"
            } else {
                liveTrackItem.title = "▶︎ Morceau : Aucun morceau détecté"
            }
        }
        
        if let liveCountItem = menu.item(withTag: 1002) {
            let count = SessionHistoryService.shared.playedTracks.count
            if count == 0 {
                liveCountItem.title = "● 0 morceau joué dans ce set"
            } else if count == 1 {
                liveCountItem.title = "● 1 morceau joué dans ce set"
            } else {
                liveCountItem.title = "● \(count) morceaux joués dans ce set"
            }
        }
        
        if let liveSoftwareItem = menu.item(withTag: 1003) {
            if SeratoMonitorService.shared.isSeratoConnected {
                liveSoftwareItem.title = "● Serato DJ Pro connecté"
            } else if SeratoMonitorService.shared.isRekordboxConnected {
                liveSoftwareItem.title = "● Rekordbox connecté"
            } else {
                liveSoftwareItem.title = "○ En attente de connexion DJ (Serato / Rekordbox)"
            }
        }
    }
}

// MARK: - Validation Dynamique des Menus (Coches d'état & Grisement)

extension AppDelegate: NSMenuItemValidation {
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleCompactAction) {
            menuItem.state = UserSettings.shared.isCompactMode ? .on : .off
        } else if menuItem.action == #selector(toggleAlwaysOnTopAction) {
            menuItem.state = UserSettings.shared.alwaysOnTop ? .on : .off
        } else if menuItem.action == #selector(setThemeCyanNeonAction) {
            menuItem.state = UserSettings.shared.djTheme == .cyanNeon ? .on : .off
        } else if menuItem.action == #selector(setThemeElectricPurpleAction) {
            menuItem.state = UserSettings.shared.djTheme == .electricPurple ? .on : .off
        } else if menuItem.action == #selector(setThemeSunsetAmberAction) {
            menuItem.state = UserSettings.shared.djTheme == .sunsetAmber ? .on : .off
        } else if menuItem.action == #selector(setThemeAcidGreenAction) {
            menuItem.state = UserSettings.shared.djTheme == .acidGreen ? .on : .off
        } else if menuItem.action == #selector(setGlassTranslucency80Action) {
            menuItem.state = abs(UserSettings.shared.glassTranslucency - 0.80) < 0.05 ? .on : .off
        } else if menuItem.action == #selector(setGlassTranslucency50Action) {
            menuItem.state = abs(UserSettings.shared.glassTranslucency - 0.50) < 0.05 ? .on : .off
        } else if menuItem.action == #selector(setGlassTranslucency20Action) {
            menuItem.state = abs(UserSettings.shared.glassTranslucency - 0.20) < 0.05 ? .on : .off
        } else if menuItem.action == #selector(setGlassTranslucency0Action) {
            menuItem.state = abs(UserSettings.shared.glassTranslucency - 0.0) < 0.05 ? .on : .off
        } else if menuItem.action == #selector(clearToPlayAction) {
            let count = ToPlayService.shared.tracks.count
            menuItem.title = count > 0 ? "Vider la liste « À jouer » (\(count))…" : "Vider la liste « À jouer »…"
            return count > 0
        } else if menuItem.action == #selector(clearManualOverrideAction) {
            return SeratoMonitorService.shared.manualTrackOverride != nil
        }
        return true
    }
}
