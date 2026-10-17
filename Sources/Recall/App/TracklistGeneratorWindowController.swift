import Foundation
import AppKit
import SwiftUI

/// Sous-classe de NSPanel pour gérer l'échappement (Escape), Cmd+W et la navigation au clavier
private class TracklistPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func cancelOperation(_ sender: Any?) {
        TracklistGeneratorWindowController.shared.closeWindow()
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.charactersIgnoringModifiers == "w" {
            TracklistGeneratorWindowController.shared.closeWindow()
            return
        }
        super.keyDown(with: event)
    }
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let loc = event.locationInWindow
            let h = frame.size.height
            let w = frame.size.width
            
            // Zone du bouton fermer en haut à droite : ne jamais déclencher de drag
            let isCloseArea = loc.x >= (w - 60) && loc.y >= (h - 65)
            if isCloseArea {
                super.sendEvent(event)
                return
            }
            
            // Déplacement fluide de la modale via toute la barre d'en-tête
            if loc.y >= (h - 60) {
                self.performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }
}

/// Contrôleur dédié à la fenêtre indépendante du Générateur de Tracklist de Recall
public class TracklistGeneratorWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = TracklistGeneratorWindowController()
    
    @Published public var isVisible: Bool = false
    
    private let defaultWidth: CGFloat = 580
    private let defaultHeight: CGFloat = 660
    private let minWidth: CGFloat = 520
    private let minHeight: CGFloat = 540
    
    public init() {
        let panel = TracklistPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.maxSize = NSSize(width: 900, height: 1100)
        
        panel.delegate = self
        panel.title = "Générateur de Tracklist Recall"
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
        
        let contentView = TracklistGeneratorView { [weak self] in
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
        
        let screen = FloatingWindowController.shared.currentScreen
        if !panel.isVisible || panel.screen != screen {
            let vf = screen.visibleFrame
            let w = panel.frame.width
            let h = panel.frame.height
            let x = vf.midX - (w / 2.0)
            let y = vf.midY - (h / 2.0)
            panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
        }
        
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}
