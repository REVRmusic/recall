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
    
    /// Dessine une icône de vinyle haute précision qui reproduit fidèlement le disque vinyle officiel de Recall
    /// avec les micro-sillons, le reflet de lumière et le macaron central aux couleurs du thème DJ actif.
    private func createVinylStatusImage(size: CGFloat = 18.0) -> NSImage {
        let theme = UserSettings.shared.djTheme
        let accent1 = theme.nsAccentColor
        let accent2 = theme.nsSecondaryColor
        
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = (size - 2.0) / 2.0
            
            // 1. Corps principal du vinyle (noir profond avec texture vinyle)
            let discRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let discPath = NSBezierPath(ovalIn: discRect)
            NSColor(white: 0.11, alpha: 1.0).setFill()
            discPath.fill()
            
            // 2. Reflet spéculaire des sillons (deux éclats coniques opposés à 40° et 220°)
            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.saveGState()
            discPath.addClip()
            for angleDeg in [40.0, 220.0] {
                let sheenPath = NSBezierPath()
                sheenPath.move(to: center)
                sheenPath.appendArc(withCenter: center, radius: radius, startAngle: CGFloat(angleDeg - 22.0), endAngle: CGFloat(angleDeg + 22.0), clockwise: false)
                sheenPath.close()
                NSColor(white: 0.95, alpha: 0.11).setFill()
                sheenPath.fill()
            }
            ctx?.restoreGState()
            
            // 3. Sillons concentriques du disque
            for gr in [radius * 0.82, radius * 0.67, radius * 0.52] {
                let gp = NSBezierPath(ovalIn: CGRect(x: center.x - gr, y: center.y - gr, width: gr * 2, height: gr * 2))
                NSColor(white: 0.75, alpha: 0.30).setStroke()
                gp.lineWidth = 0.65
                gp.stroke()
            }
            
            // 4. Filet extérieur de contraste métallique (visibilité parfaite sur fond sombre comme clair)
            let rimColor = NSColor(white: 0.45, alpha: 0.85)
            rimColor.setStroke()
            discPath.lineWidth = 0.8
            discPath.stroke()
            
            // 5. Macaron central aux couleurs du thème DJ de Recall
            let labelRadius = radius * 0.38
            let labelRect = CGRect(x: center.x - labelRadius, y: center.y - labelRadius, width: labelRadius * 2, height: labelRadius * 2)
            let labelPath = NSBezierPath(ovalIn: labelRect)
            
            let gradient = NSGradient(colors: [accent1, accent2])
            gradient?.draw(in: labelPath, angle: 45)
            
            // Anneau fin délimitant le macaron
            NSColor(white: 0.05, alpha: 0.7).setStroke()
            labelPath.lineWidth = 0.5
            labelPath.stroke()
            
            // 6. Trou central du vinyle (spindle)
            let holeRadius = radius * 0.13
            let holeRect = CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2, height: holeRadius * 2)
            let holePath = NSBezierPath(ovalIn: holeRect)
            NSColor(white: 0.07, alpha: 1.0).setFill()
            holePath.fill()
            
            return true
        }
        
        img.isTemplate = false
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
