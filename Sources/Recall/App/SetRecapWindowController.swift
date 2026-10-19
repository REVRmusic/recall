import Foundation
import AppKit
import SwiftUI

/// Sous-classe de NSPanel pour gérer l'échappement (Escape), Cmd+W et la navigation au clavier pour le récapitulatif
private class SetRecapPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func cancelOperation(_ sender: Any?) {
        SetRecapWindowController.shared.closeWindow()
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.charactersIgnoringModifiers == "w" {
            SetRecapWindowController.shared.closeWindow()
            return
        }
        super.keyDown(with: event)
    }
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            let loc = event.locationInWindow
            let h = frame.size.height
            
            // Seule la zone du titre en haut à gauche (icône + texte, x < 180) déclenche le drag de la fenêtre.
            // Le sélecteur de session (x >= 180) et les boutons d'action (Photos, Partage, Fermer) reçoivent 100% des clics sans interférence.
            let isTitleDragArea = loc.x < 180 && loc.y >= (h - 70)
            if isTitleDragArea {
                self.performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }
}

/// Contrôleur dédié à la fenêtre indépendante du Bilan Statistique du Mix (Set Recap) de Recall
public class SetRecapWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = SetRecapWindowController()
    
    @Published public var isVisible: Bool = false
    
    private let defaultWidth: CGFloat = 560
    private let defaultHeight: CGFloat = 640
    private let minWidth: CGFloat = 500
    private let minHeight: CGFloat = 520
    
    public init() {
        let panel = SetRecapPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.maxSize = NSSize(width: 850, height: 1050)
        
        panel.delegate = self
        panel.title = "Statistiques du Mix Recall"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 4)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        
        // Supprime les boutons macOS standard (remplacés par le design SwiftUI Recall)
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        updateContentView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Re-monte ou rafraîchit la vue SwiftUI pour garantir que l'affichage est 100% à jour (0 état résiduel)
    private func updateContentView() {
        guard let panel = window else { return }
        let contentView = SetRecapView(
            onClose: { [weak self] in
                self?.closeWindow()
            },
            onOpenTracklist: { [weak self] in
                self?.closeWindow()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    TracklistGeneratorWindowController.shared.show()
                }
            }
        )
        
        if let hostingView = panel.contentView as? NSHostingView<SetRecapView> {
            hostingView.rootView = contentView
        } else {
            let hostingView = NSHostingView(rootView: contentView)
            hostingView.autoresizingMask = [.width, .height]
            panel.contentView = hostingView
        }
    }
    
    public func show() {
        guard let panel = window else { return }
        
        let screen = FloatingWindowController.shared.currentScreen
        if !panel.isVisible || panel.screen != screen {
            let vf = screen.visibleFrame
            let w = panel.frame.width
            let h = panel.frame.height
            let x = vf.midX - (w / 2.0)
            let y = vf.midY - (h / 2.0)
            panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }
        
        updateContentView()
        
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func toggle() {
        if isVisible && (window?.isVisible == true) {
            closeWindow()
        } else {
            show()
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}
