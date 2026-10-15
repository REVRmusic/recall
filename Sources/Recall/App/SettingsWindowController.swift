import Foundation
import AppKit
import SwiftUI

/// Contrôleur dédié à la fenêtre indépendante des paramètres de Recall,
/// s'ouvrant au centre exact de l'écran pour permettre d'observer les modifications
/// en direct sur l'interface principale de Recall.
public class SettingsWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = SettingsWindowController()
    
    @Published public var isVisible: Bool = false
    
    private let defaultWidth: CGFloat = 380
    private let defaultHeight: CGFloat = 560
    private let minWidth: CGFloat = 350
    private let minHeight: CGFloat = 440
    
    public init() {
        let panel = NSPanel(
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
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Ouvre les paramètres au milieu de l'écran de l'ordinateur
    public func show() {
        guard let panel = window else { return }
        
        // Si la fenêtre n'est pas déjà affichée, la positionner au centre géométrique de l'écran
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
        
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            self.isVisible = true
        }
    }
    
    /// Ferme la fenêtre des paramètres
    public func closeWindow() {
        window?.orderOut(nil)
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
        DispatchQueue.main.async {
            self.isVisible = false
        }
    }
}
