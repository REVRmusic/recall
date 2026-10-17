import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
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
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingWindowController.shared.show()
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        SeratoMonitorService.shared.stopMonitoring()
        UserDefaults.standard.synchronize()
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
        
        let feedbackItem = NSMenuItem(
            title: "Suggérer une amélioration…",
            action: #selector(openFeedbackWebsiteAction),
            keyEquivalent: ""
        )
        feedbackItem.target = self
        appMenu.addItem(feedbackItem)
        
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
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        // -------------------------------------------------------------
        // 4. Menu "Outils de session"
        // -------------------------------------------------------------
        let sessionMenuItem = NSMenuItem()
        let sessionMenu = NSMenu(title: "Outils de session")
        
        let setRecapItem = NSMenuItem(
            title: "Statistiques du Mix (Set Recap)…",
            action: #selector(openSetRecapAction),
            keyEquivalent: "S"
        )
        setRecapItem.keyEquivalentModifierMask = [.command, .shift]
        setRecapItem.target = self
        sessionMenu.addItem(setRecapItem)
        
        let tracklistItem = NSMenuItem(
            title: "Générateur de Tracklist…",
            action: #selector(openTracklistGeneratorAction),
            keyEquivalent: "T"
        )
        tracklistItem.keyEquivalentModifierMask = [.command, .shift]
        tracklistItem.target = self
        sessionMenu.addItem(tracklistItem)
        
        sessionMenuItem.submenu = sessionMenu
        mainMenu.addItem(sessionMenuItem)
        
        // -------------------------------------------------------------
        // 4. Menu "Fenêtre"
        // -------------------------------------------------------------
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenêtre")
        
        let showRecallItem = NSMenuItem(
            title: "Afficher Recall",
            action: #selector(showRecallAction),
            keyEquivalent: ""
        )
        showRecallItem.target = self
        windowMenu.addItem(showRecallItem)
        
        let toggleCompactItem = NSMenuItem(
            title: "Mode Compact",
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
        
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)
        NSApp.windowsMenu = windowMenu
        
        // -------------------------------------------------------------
        // 5. Menu "Aide"
        // -------------------------------------------------------------
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Aide")
        
        let checkUpdateHelpItem = NSMenuItem(
            title: "Rechercher les mises à jour…",
            action: #selector(checkForUpdatesAction),
            keyEquivalent: ""
        )
        checkUpdateHelpItem.target = self
        helpMenu.addItem(checkUpdateHelpItem)
        
        let feedbackHelpItem = NSMenuItem(
            title: "Faire un retour au développeur…",
            action: #selector(openFeedbackWebsiteAction),
            keyEquivalent: ""
        )
        feedbackHelpItem.target = self
        helpMenu.addItem(feedbackHelpItem)
        
        helpMenu.addItem(NSMenuItem.separator())
        
        let websiteItem = NSMenuItem(
            title: "Site officiel",
            action: #selector(openWebsiteAction),
            keyEquivalent: ""
        )
        websiteItem.target = self
        helpMenu.addItem(websiteItem)
        
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
        if let url = URL(string: "https://revrmusic.github.io/recall/?feedback=1&source=app_macos") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func showAboutAction() {
        let alert = NSAlert()
        alert.messageText = "Recall \(AutoUpdateService.shared.currentAppVersion)"
        alert.informativeText = "Compagnon intelligent en direct pour Serato DJ Pro & Rekordbox.\nConçu par REVR pour assister les DJs en live.\n\n100% local • Aucune collecte de données • Léger & Réactif."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Site officiel")
        alert.addButton(withTitle: "Suggérer une idée")
        alert.addButton(withTitle: "Rechercher une mise à jour")
        
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://revrmusic.github.io/recall/") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            openFeedbackWebsiteAction()
        } else if response == NSApplication.ModalResponse(rawValue: 1003) {
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
        UserSettings.shared.isCompactMode.toggle()
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
    
    @objc private func openWebsiteAction() {
        if let url = URL(string: "https://revrmusic.github.io/recall/") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func openGithubAction() {
        if let url = URL(string: "https://github.com/REVRmusic/recall") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Validation Dynamique des Menus (Coches d'état)

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
        }
        return true
    }
}
