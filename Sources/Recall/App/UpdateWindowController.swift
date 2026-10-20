import Foundation
import AppKit
import SwiftUI

/// Sous-classe de NSPanel pour gérer l'échappement (Escape), Cmd+W et la fermeture propre
private class UpdatePanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func cancelOperation(_ sender: Any?) {
        UpdateWindowController.shared.closeWindow()
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.charactersIgnoringModifiers == "w" {
            UpdateWindowController.shared.closeWindow()
            return
        }
        super.keyDown(with: event)
    }
}

/// Contrôleur dédié à la fenêtre indépendante de recherche et d'affichage des mises à jour de Recall
public class UpdateWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = UpdateWindowController()
    
    @Published public var isVisible: Bool = false
    
    private let defaultWidth: CGFloat = 410
    private let defaultHeight: CGFloat = 280
    
    public init() {
        let panel = UpdatePanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.delegate = self
        panel.title = "Mise à jour logicielle"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        
        // Supprime les boutons macOS standard (remplacés par le design SwiftUI)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        let contentView = UpdateModalView { [weak self] in
            self?.closeWindow()
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show() {
        guard let panel = window else { return }
        
        // Centrage sur l'écran actif
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
        
        // Déclenchement automatique de la recherche si aucune installation ou mise à jour n'est déjà prête
        if !AutoUpdateService.shared.isInstalling && !AutoUpdateService.shared.isUpdateAvailable {
            AutoUpdateService.shared.checkForUpdatesManually()
        }
    }
    
    /// Ouvre la fenêtre de mise à jour et démarre immédiatement l'installation automatique en 1 clic
    public func showAndInstall() {
        guard let panel = window else { return }
        
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
        
        AutoUpdateService.shared.installUpdate()
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}
