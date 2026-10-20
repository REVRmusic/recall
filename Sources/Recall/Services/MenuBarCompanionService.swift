import Cocoa
import SwiftUI
import Combine

/// Service gérant la présence d'un compagnon résident Recall dans la barre des menus macOS
@MainActor
public final class MenuBarCompanionService: NSObject, NSMenuDelegate, ObservableObject {
    public static let shared = MenuBarCompanionService()
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
    }
    
    /// Initialisation du compagnon
    public func setup() {
        UserSettings.shared.$enableMenuBarCompanion
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.setEnabled(enabled)
            }
            .store(in: &cancellables)
        
        UserSettings.shared.$djTheme
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemIcon()
            }
            .store(in: &cancellables)
        
        if UserSettings.shared.enableMenuBarCompanion {
            createStatusItem()
        }
    }
    
    /// Active ou désactive dynamiquement l'icône dans la barre des menus
    public func setEnabled(_ enabled: Bool) {
        if enabled {
            if statusItem == nil {
                createStatusItem()
            }
        } else {
            removeStatusItem()
        }
    }
    
    /// Met à jour dynamiquement l'icône dans la barre des menus (ex: lors d'un changement de thème DJ)
    public func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        button.image = createVinylStatusImage(size: 18.0)
    }
    
    /// Dessine une icône de vinyle monochrome native macOS (Template Image).
    /// Sur macOS, `isTemplate = true` permet d'adapter automatiquement le rendu en blanc pur sur fond sombre
    /// et en noir sur fond clair, s'intégrant parfaitement avec les autres icônes système de la barre des menus.
    private func createVinylStatusImage(size: CGFloat = 18.0) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = (size - 2.0) / 2.0
            
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            
            // 1. Cercle extérieur du vinyle (contour net)
            let discRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let discPath = NSBezierPath(ovalIn: discRect)
            NSColor.black.setStroke()
            discPath.lineWidth = 1.3
            discPath.stroke()
            
            // 2. Micro-sillons concentriques stylisés
            for gr in [radius * 0.76, radius * 0.58] {
                let groovePath = NSBezierPath(ovalIn: CGRect(x: center.x - gr, y: center.y - gr, width: gr * 2, height: gr * 2))
                NSColor.black.withAlphaComponent(0.7).setStroke()
                groovePath.lineWidth = 0.8
                groovePath.stroke()
            }
            
            // 3. Macaron central plein
            let labelRadius = radius * 0.36
            let labelRect = CGRect(x: center.x - labelRadius, y: center.y - labelRadius, width: labelRadius * 2, height: labelRadius * 2)
            let labelPath = NSBezierPath(ovalIn: labelRect)
            NSColor.black.setFill()
            labelPath.fill()
            
            // 4. Trou central (spindle) évidé
            let holeRadius = radius * 0.14
            let holeRect = CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2, height: holeRadius * 2)
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: holeRect)
            ctx.restoreGState()
            
            return true
        }
        
        img.isTemplate = true
        return img
    }
    
    private func createStatusItem() {
        guard statusItem == nil else { return }
        
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = createVinylStatusImage(size: 18.0)
            button.toolTip = "Recall — Copilote DJ Intelligent"
        }
        
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        
        self.statusItem = item
        AppLogger.info("Compagnon barre des menus Recall initialisé avec succès.", category: .system)
    }
    
    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
            AppLogger.info("Compagnon barre des menus Recall désactivé.", category: .system)
        }
    }
    
    // MARK: - NSMenuDelegate (Mise à jour dynamique en direct lors du clic)
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let monitor = SeratoMonitorService.shared
        let session = SessionHistoryService.shared
        let settings = UserSettings.shared
        let isVisible = FloatingWindowController.shared.isVisible
        
        // 1. En-tête : Titre & Version
        let titleItem = NSMenuItem(title: "Recall • Copilote DJ (v1.0.10)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        // 2. Statut en direct
        var statusStr = "🎧 En attente du logiciel DJ"
        if let track = monitor.currentTrack {
            statusStr = "▶️ \(track.artist) — \(track.title)"
        } else if monitor.isSeratoConnected {
            statusStr = "🟢 Serato DJ Pro connecté (\(session.playedCount) joués)"
        } else if monitor.isRekordboxConnected {
            statusStr = "🟢 Rekordbox connecté (\(session.playedCount) joués)"
        } else if session.playedCount > 0 {
            statusStr = "🟢 Surveillance active (\(session.playedCount) joués)"
        }
        
        let statusItem = NSMenuItem(title: statusStr, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Afficher / Masquer Recall
        let toggleTitle = isVisible ? "Masquer Recall" : "Afficher Recall"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleRecallAction), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let recenterItem = NSMenuItem(title: "Recentrer au coin inférieur droit", action: #selector(recenterRecallAction), keyEquivalent: "")
        recenterItem.target = self
        menu.addItem(recenterItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Outils DJ
        let recapItem = NSMenuItem(title: "Statistiques du Mix (Set Recap)…", action: #selector(openSetRecapAction), keyEquivalent: "S")
        recapItem.keyEquivalentModifierMask = [.command, .shift]
        recapItem.target = self
        menu.addItem(recapItem)
        
        let tracklistItem = NSMenuItem(title: "Générateur de Tracklist…", action: #selector(openTracklistGeneratorAction), keyEquivalent: "T")
        tracklistItem.keyEquivalentModifierMask = [.command, .shift]
        tracklistItem.target = self
        menu.addItem(tracklistItem)
        
        let phoneClients = PhoneCompanionService.shared.connectedClients
        let phoneTitle = phoneClients > 0
            ? "Compagnon Téléphone (\(phoneClients) connecté\(phoneClients > 1 ? "s" : ""))…"
            : "Compagnon Téléphone (QR code)…"
        let phoneItem = NSMenuItem(title: phoneTitle, action: #selector(openPhoneCompanionAction), keyEquivalent: "P")
        phoneItem.keyEquivalentModifierMask = [.command, .shift]
        phoneItem.target = self
        phoneItem.state = PhoneCompanionService.shared.isRunning ? .on : .off
        menu.addItem(phoneItem)
        
        let resyncItem = NSMenuItem(title: "Resynchroniser avec le logiciel DJ", action: #selector(resyncAction), keyEquivalent: "r")
        resyncItem.target = self
        menu.addItem(resyncItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Paramètres & Options
        let settingsItem = NSMenuItem(title: "Paramètres…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let launchItem = NSMenuItem(title: "Lancer au démarrage du Mac", action: #selector(toggleLaunchAtStartupAction), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = settings.launchAtLogin ? .on : .off
        menu.addItem(launchItem)
        
        let updateItem = NSMenuItem(title: "Rechercher les mises à jour…", action: #selector(checkForUpdatesAction), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quitter
        let quitItem = NSMenuItem(title: "Quitter Recall", action: #selector(quitAppAction), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Actions
    
    @objc private func toggleRecallAction() {
        FloatingWindowController.shared.toggle()
    }
    
    @objc private func recenterRecallAction() {
        FloatingWindowController.shared.positionAtBottomRight()
        FloatingWindowController.shared.show()
    }
    
    @objc private func openSetRecapAction() {
        SetRecapWindowController.shared.show()
    }
    
    @objc private func openTracklistGeneratorAction() {
        TracklistGeneratorWindowController.shared.show()
    }
    
    @objc private func openPhoneCompanionAction() {
        PhoneCompanionWindowController.shared.show()
    }
    
    @objc private func resyncAction() {
        SeratoMonitorService.shared.triggerSessionResync()
    }
    
    @objc private func openSettingsAction() {
        SettingsWindowController.shared.show()
    }
    
    @objc private func checkForUpdatesAction() {
        AutoUpdateService.shared.checkForUpdatesManually()
        UpdateWindowController.shared.show()
    }
    
    @objc private func toggleLaunchAtStartupAction() {
        UserSettings.shared.launchAtLogin.toggle()
    }
    
    @objc private func quitAppAction() {
        NSApp.terminate(nil)
    }
}
