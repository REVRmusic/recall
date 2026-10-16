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
            let loc = event.locationInWindow
            let h = frame.size.height
            let w = frame.size.width
            
            // Déplacement fluide de la modale via toute la barre d'en-tête (sauf bouton fermer en haut à droite)
            if loc.y >= (h - 60) {
                let isCloseButton = loc.x >= (w - 48) && loc.y >= (h - 48)
                if !isCloseButton {
                    self.performDrag(with: event)
                    return
                }
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
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func show() {
        guard let panel = window else { return }
        
        panel.center()
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
