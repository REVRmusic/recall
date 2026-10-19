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
            
            // Si la modale de personnalisation d'export est active, laisser passer tous les clics
            if SetRecapWindowController.shared.isExportModalPresented {
                super.sendEvent(event)
                return
            }
            
            let loc = event.locationInWindow
            let h = frame.size.height
            let w = frame.size.width
            
            // La barre d'en-tête occupe les 60 points depuis le haut physique de la fenêtre
            let isInHeaderBar = loc.y >= (h - 60)
            
            if isInHeaderBar {
                // 1. Boutons d'action à droite (Partage, Photos, Fermer) : laisser passer le clic sans drag
                let isRightButtonsArea = loc.x >= (w - 125)
                
                // 2. Menu déroulant du sélecteur de session : laisser passer le clic sans drag
                let pickerRange = SetRecapWindowController.shared.sessionPickerHorizontalRange ?? (210...420)
                let isSessionPickerArea = pickerRange.contains(loc.x)
                
                // Tout le reste de la barre d'en-tête (icône, titre "Statistiques du Mix", badge "SET RECAP",
                // sous-titre de statut, et tout l'espace vide central) déclenche le drag fluide natif macOS
                if !isRightButtonsArea && !isSessionPickerArea {
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
    
    /// Plage horizontale dynamique occupée par le sélecteur de session dans la barre d'en-tête
    public var sessionPickerHorizontalRange: ClosedRange<CGFloat>? = nil
    
    /// Indique si la modale de personnalisation avant export est affichée
    public var isExportModalPresented: Bool = false
    
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
