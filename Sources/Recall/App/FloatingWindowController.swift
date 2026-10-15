import Foundation
import AppKit
import SwiftUI

public class FloatingWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = FloatingWindowController()
    
    private let defaultWidth: CGFloat = 360
    private let defaultHeight: CGFloat = 530
    private let bandeauHeight: CGFloat = 54
    private let minWidth: CGFloat = 250
    private let minHeight: CGFloat = 260
    
    public init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        panel.minSize = NSSize(width: minWidth, height: minHeight)
        panel.maxSize = NSSize(width: 800, height: 1400)
        
        panel.delegate = self
        panel.title = "Recall"
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
        
        // Supprime complètement les boutons ronds standard de macOS pour libérer le coin supérieur gauche pour le logo Recall
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.closeButton)?.removeFromSuperview()
        panel.standardWindowButton(.miniaturizeButton)?.removeFromSuperview()
        panel.standardWindowButton(.zoomButton)?.removeFromSuperview()
        
        // Configuration de la vue principale SwiftUI avec injection d'environnement
        let contentView = MainFloatingView()
            .environmentObject(SeratoMonitorService.shared)
            .environmentObject(UserSettings.shared)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        
        // Positionnement initial au coin inférieur droit de l'écran principal
        positionAtBottomRight()
        panel.orderFrontRegardless()
    }
    
    public func show() {
        positionAtBottomRight()
        window?.orderFrontRegardless()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func positionAtBottomRight() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let targetHeight = UserSettings.shared.isCompactMode ? bandeauHeight : defaultHeight
        let widthToUse = window.frame.size.width >= minWidth ? window.frame.size.width : defaultWidth
        let x = visibleFrame.maxX - widthToUse - 20
        let y = visibleFrame.minY + 20
        window.setFrame(NSRect(x: x, y: y, width: widthToUse, height: targetHeight), display: true)
    }
    
    public func updateAlwaysOnTop(_ enabled: Bool) {
        guard let window = self.window else { return }
        window.level = enabled ? .floating : .normal
    }
    
    public func toggleCompactMode(_ compact: Bool) {
        guard let window = self.window, let screen = NSScreen.main else { return }
        var currentFrame = window.frame
        let targetHeight = compact ? bandeauHeight : defaultHeight
        
        window.minSize = NSSize(width: minWidth, height: compact ? bandeauHeight : minHeight)
        window.maxSize = NSSize(width: 800, height: compact ? bandeauHeight : 1400)
        
        let visibleFrame = screen.visibleFrame
        if currentFrame.size.width < minWidth {
            currentFrame.size.width = minWidth
        }
        currentFrame.size.height = targetHeight
        
        // Empêcher tout débordement hors de l'écran
        if currentFrame.maxX > visibleFrame.maxX {
            currentFrame.origin.x = visibleFrame.maxX - currentFrame.size.width
        }
        if currentFrame.minX < visibleFrame.minX {
            currentFrame.origin.x = visibleFrame.minX
        }
        if currentFrame.maxY > visibleFrame.maxY {
            currentFrame.origin.y = visibleFrame.maxY - targetHeight
        }
        if currentFrame.minY < visibleFrame.minY {
            currentFrame.origin.y = visibleFrame.minY + 20
        }
        
        window.setFrame(currentFrame, display: true, animate: true)
    }
}
