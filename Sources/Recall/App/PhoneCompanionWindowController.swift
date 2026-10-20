import Foundation
import AppKit
import SwiftUI

/// Panneau flottant du Compagnon Téléphone (QR code, adresse, PIN, statut)
private class PhoneCompanionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    override func cancelOperation(_ sender: Any?) {
        PhoneCompanionWindowController.shared.closeWindow()
    }
    
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command && event.charactersIgnoringModifiers == "w" {
            PhoneCompanionWindowController.shared.closeWindow()
            return
        }
        super.keyDown(with: event)
    }
}

/// Contrôleur de la fenêtre indépendante du Compagnon Téléphone
public class PhoneCompanionWindowController: NSWindowController, NSWindowDelegate, ObservableObject {
    public static let shared = PhoneCompanionWindowController()
    
    @Published public var isVisible: Bool = false
    
    private let defaultWidth: CGFloat = 440
    private let defaultHeight: CGFloat = 560
    
    public init() {
        let panel = PhoneCompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.delegate = self
        panel.title = "Compagnon Téléphone"
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
        
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        let contentView = PhoneCompanionView { [weak self] in
            self?.closeWindow()
        }
        .environmentObject(UserSettings.shared)
        
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
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
        
        // Ouvrir la fenêtre démarre le serveur : le DJ veut scanner tout de suite
        Task { @MainActor in
            PhoneCompanionService.shared.refreshLocalAddresses()
            PhoneCompanionService.shared.start()
        }
    }
    
    public func toggle() {
        if isVisible { closeWindow() } else { show() }
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    public func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
}
