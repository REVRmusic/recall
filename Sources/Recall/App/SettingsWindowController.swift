import Foundation
import AppKit
import SwiftUI

/// Vue de fond d'écran obscurci (dimming backdrop) avec effet de flou et assombrissement translucide moderne.
private class SettingsDimmingBackdropView: NSVisualEffectView {
    var onClick: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEffect()
    }
    
    private func setupEffect() {
        appearance = NSAppearance(named: .darkAqua)
        material = .fullScreenUI
        blendingMode = .behindWindow
        state = .active
    }
    
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

/// Sous-classe de NSPanel pour gérer l'échappement (Escape), le raccourci Cmd+, et la fermeture propre
private class SettingsPanel: NSPanel {
    override func cancelOperation(_ sender: Any?) {
        SettingsWindowController.shared.closeWindow()
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.charactersIgnoringModifiers == "," {
            SettingsWindowController.shared.closeWindow()
            return
        }
        super.keyDown(with: event)
    }
}

/// Contrôleur dédié à la fenêtre indépendante des paramètres de Recall,
/// s'ouvrant au centre exact de l'écran avec un arrière-plan obscurci sur l'ensemble de l'écran.
public class SettingsWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = SettingsWindowController()
    
    @Published public var isVisible: Bool = false
    
    private var dimmingWindow: NSWindow?
    
    private let defaultWidth: CGFloat = 380
    private let defaultHeight: CGFloat = 560
    private let minWidth: CGFloat = 350
    private let minHeight: CGFloat = 440
    
    public init() {
        let panel = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.maxSize = NSSize(width: 700, height: 1000)
        
        panel.delegate = self
        panel.title = "Paramètres Recall"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        // Niveau au-dessus du fond obscurci
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        
        // Supprime les boutons macOS standard pour utiliser le design de fermeture personnalisé
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.closeButton)?.removeFromSuperview()
        panel.standardWindowButton(.miniaturizeButton)?.removeFromSuperview()
        panel.standardWindowButton(.zoomButton)?.removeFromSuperview()
        
        let contentView = SettingsSheetView()
            .environmentObject(SeratoMonitorService.shared)
            .environmentObject(UserSettings.shared)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        setupDimmingWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupDimmingWindow() {
        let dimWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        dimWindow.isOpaque = false
        dimWindow.backgroundColor = .clear
        dimWindow.hasShadow = false
        dimWindow.ignoresMouseEvents = false
        dimWindow.appearance = NSAppearance(named: .darkAqua)
        // Niveau juste au-dessus des applications hôtes (Serato/Rekordbox à .normal = 0)
        // et strictement en-dessous de la fenêtre principale Recall (élevée à .floating + 1)
        dimWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) + 1)
        dimWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        dimWindow.isReleasedWhenClosed = false
        
        let backdropView = SettingsDimmingBackdropView(frame: dimWindow.contentLayoutRect)
        backdropView.autoresizingMask = [.width, .height]
        backdropView.onClick = { [weak self] in
            self?.closeWindow()
        }
        dimWindow.contentView = backdropView
        
        self.dimmingWindow = dimWindow
    }
    
    /// Ouvre les paramètres au milieu de l'écran avec un fond obscurci doux sur l'ensemble de l'écran
    public func show() {
        guard let panel = window else { return }
        
        // 1. Calcul du cadre recouvrant tous les écrans connectés
        var totalScreenFrame = NSScreen.screens.first?.frame ?? NSRect(x: 0, y: 0, width: 2560, height: 1440)
        for screen in NSScreen.screens.dropFirst() {
            totalScreenFrame = totalScreenFrame.union(screen.frame)
        }
        
        // 2. Affichage et animation du fond obscurci translucide et flouté (effet verre dépoli)
        if let dim = dimmingWindow {
            dim.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)) + 1)
            dim.setFrame(totalScreenFrame, display: true)
            dim.alphaValue = 0
            dim.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                dim.animator().alphaValue = 0.72
            }
        }

        // 3. Maintien garanti et absolu de la fenêtre principale Recall au premier plan (au-dessus du fond obscurci)
        if let mainWindow = FloatingWindowController.shared.window {
            mainWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            if let dim = dimmingWindow {
                mainWindow.order(.above, relativeTo: dim.windowNumber)
            }
            mainWindow.orderFrontRegardless()
        }
        
        // 4. Positionnement au centre de l'écran principal
        if !panel.isVisible {
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let w = panel.frame.width >= minWidth ? panel.frame.width : defaultWidth
                let h = panel.frame.height >= minHeight ? panel.frame.height : defaultHeight
                let x = screenFrame.midX - (w / 2.0)
                let y = screenFrame.midY - (h / 2.0)
                panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
            } else {
                panel.center()
            }
        }
        
        // 5. Affichage de la fenêtre des paramètres au-dessus de tout
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 2)
        if let mainWindow = FloatingWindowController.shared.window {
            panel.order(.above, relativeTo: mainWindow.windowNumber)
        }
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            self.isVisible = true
        }
    }
    
    /// Ferme la fenêtre des paramètres et retire l'arrière-plan obscurci
    public func closeWindow() {
        window?.orderOut(nil)
        
        if let dim = dimmingWindow, dim.isVisible {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                dim.animator().alphaValue = 0.0
            }, completionHandler: {
                dim.orderOut(nil)
            })
        }

        // Rétablir le niveau standard selon le réglage Always on Top
        FloatingWindowController.shared.updateAlwaysOnTop(UserSettings.shared.alwaysOnTop)
        FloatingWindowController.shared.window?.orderFrontRegardless()
        
        DispatchQueue.main.async {
            self.isVisible = false
        }
    }
    
    /// Bascule l'affichage (affiche si masquée, masque si affichée)
    public func toggle() {
        if isVisible && (window?.isVisible == true) {
            closeWindow()
        } else {
            show()
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        if let dim = dimmingWindow, dim.isVisible {
            dim.orderOut(nil)
        }
        FloatingWindowController.shared.updateAlwaysOnTop(UserSettings.shared.alwaysOnTop)
        FloatingWindowController.shared.window?.orderFrontRegardless()
        DispatchQueue.main.async {
            self.isVisible = false
        }
    }
}
