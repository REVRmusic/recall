import Foundation
import AppKit
import SwiftUI

public class FloatingWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = FloatingWindowController()
    
    private let defaultWidth: CGFloat = 360
    private let defaultHeight: CGFloat = 530
    private let bandeauHeight: CGFloat = 54
    private let minWidth: CGFloat = 250
    public static let minNormalHeight: CGFloat = 227 // Hauteur minimale correspondant à 1 suggestion visible
    public static let maxWidth: CGFloat = 480
    public static let maxHeight: CGFloat = 720
    
    private var hasPositionedOnLaunch: Bool = false
    private var lastNormalHeight: CGFloat = 530
    
    public var effectiveMaxWidth: CGFloat {
        if let screen = window?.screen ?? NSScreen.main {
            return min(Self.maxWidth, screen.visibleFrame.width)
        }
        return Self.maxWidth
    }
    
    public var effectiveMaxHeight: CGFloat {
        if let screen = window?.screen ?? NSScreen.main {
            return min(Self.maxHeight, screen.visibleFrame.height)
        }
        return Self.maxHeight
    }
    
    public init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: defaultWidth, height: defaultHeight),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        // Autorise la hauteur minimale du bandeau pour permettre le passage dynamique au seuil
        panel.minSize = NSSize(width: minWidth, height: bandeauHeight)
        panel.maxSize = NSSize(width: effectiveMaxWidth, height: effectiveMaxHeight)
        
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
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        panel.contentView = hostingView
        
        // Positionnement initial au coin inférieur droit de l'écran principal
        positionAtBottomRight()
        panel.orderFrontRegardless()
    }
    
    public func show() {
        if !hasPositionedOnLaunch {
            positionAtBottomRight()
        }
        window?.orderFrontRegardless()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func positionAtBottomRight() {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let isCompact = UserSettings.shared.isCompactMode
        let targetHeight = isCompact ? bandeauHeight : defaultHeight
        let widthToUse = max(minWidth, min(effectiveMaxWidth, window.frame.size.width >= minWidth ? window.frame.size.width : defaultWidth))
        
        // Exactement collé au bord inférieur bas et droit de l'écran visible
        let x = visibleFrame.maxX - widthToUse
        let y = visibleFrame.minY
        window.setFrame(NSRect(x: x, y: y, width: widthToUse, height: targetHeight), display: true)
        hasPositionedOnLaunch = true
    }
    
    public func updateAlwaysOnTop(_ enabled: Bool) {
        guard let window = self.window else { return }
        window.level = enabled ? .floating : .normal
    }
    
    public func toggleCompactMode(_ compact: Bool) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let currentFrame = window.frame
        
        UserSettings.shared.isCompactMode = compact
        
        let targetWidth = max(minWidth, min(effectiveMaxWidth, currentFrame.size.width >= minWidth ? currentFrame.size.width : defaultWidth))
        let targetHeight: CGFloat
        
        if compact {
            // Sauvegarder la hauteur avant de réduire si elle était valide
            if currentFrame.size.height >= Self.minNormalHeight {
                lastNormalHeight = currentFrame.size.height
            }
            targetHeight = bandeauHeight
            
            // Toujours positionné impérativement en bas à droite de l'écran visible
            let x = visibleFrame.maxX - targetWidth
            let y = visibleFrame.minY
            let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            window.setFrame(newFrame, display: true)
        } else {
            // Rétablir la hauteur normale (au moins minNormalHeight, au plus effectiveMaxHeight)
            let desiredH = lastNormalHeight >= Self.minNormalHeight ? lastNormalHeight : defaultHeight
            targetHeight = max(Self.minNormalHeight, min(effectiveMaxHeight, desiredH))
            
            // Déplier vers le haut en restant parfaitement collé au bord inférieur droit
            let x = visibleFrame.maxX - targetWidth
            let y = visibleFrame.minY
            let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            window.setFrame(newFrame, display: true)
        }
    }
    
    // MARK: - Redimensionnement Interactif et Bascule Dynamique
    
    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard let screen = sender.screen ?? NSScreen.main else { return frameSize }
        let visibleFrame = screen.visibleFrame
        let maxH = min(Self.maxHeight, visibleFrame.height)
        let maxW = min(Self.maxWidth, visibleFrame.width)
        let clampedWidth = max(minWidth, min(maxW, frameSize.width))
        
        let isCompact = UserSettings.shared.isCompactMode
        
        if isCompact {
            // VUE RÉDUITE : Si l'utilisateur agrandit vers le haut (> 89 pt), passage en vue normale
            let expansionThreshold: CGFloat = bandeauHeight + 35 // 89 pt
            if frameSize.height > expansionThreshold {
                let targetH = max(Self.minNormalHeight, min(maxH, frameSize.height))
                lastNormalHeight = targetH
                UserSettings.shared.isCompactMode = false
                return NSSize(width: clampedWidth, height: targetH)
            } else {
                // Reste verrouillé au bandeau réduit
                return NSSize(width: clampedWidth, height: bandeauHeight)
            }
        } else {
            // VUE NORMALE : Hauteur minimale équivalente à l'image fournie (227pt, 1 suggestion visible)
            let collapseThreshold: CGFloat = Self.minNormalHeight - 15 // 212 pt
            
            if frameSize.height < collapseThreshold {
                // Si on réduit plus que la hauteur minimale -> bascule automatique en vue réduite
                UserSettings.shared.isCompactMode = true
                return NSSize(width: clampedWidth, height: bandeauHeight)
            } else if frameSize.height < Self.minNormalHeight {
                // Butée magnétique sur la hauteur minimale
                return NSSize(width: clampedWidth, height: Self.minNormalHeight)
            } else {
                // Redimensionnement normal
                let clampedH = min(maxH, frameSize.height)
                lastNormalHeight = clampedH
                return NSSize(width: clampedWidth, height: clampedH)
            }
        }
    }
    
    public func windowDidResize(_ notification: Notification) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        var adjusted = false
        
        // Empêcher tout débordement hors de l'écran en bas à droite
        if UserSettings.shared.isCompactMode {
            if frame.size.height != bandeauHeight {
                frame.size.height = bandeauHeight
                adjusted = true
            }
            if frame.origin.y != visibleFrame.minY {
                frame.origin.y = visibleFrame.minY
                adjusted = true
            }
            if frame.maxX != visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.size.width
                adjusted = true
            }
        } else {
            if frame.minY < visibleFrame.minY {
                frame.origin.y = visibleFrame.minY
                adjusted = true
            }
            if frame.maxX > visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.size.width
                adjusted = true
            }
            if frame.minX < visibleFrame.minX {
                frame.origin.x = visibleFrame.minX
                adjusted = true
            }
            if frame.maxY > visibleFrame.maxY {
                frame.origin.y = visibleFrame.maxY - frame.size.height
                adjusted = true
            }
        }
        
        if adjusted {
            window.setFrame(frame, display: true)
        }
    }
    
    public func windowDidEndLiveResize(_ notification: Notification) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        
        if UserSettings.shared.isCompactMode {
            let targetW = max(minWidth, min(effectiveMaxWidth, frame.size.width))
            window.setFrame(NSRect(x: visibleFrame.maxX - targetW, y: visibleFrame.minY, width: targetW, height: bandeauHeight), display: true)
        } else {
            let targetW = max(minWidth, min(effectiveMaxWidth, frame.size.width))
            let targetH = max(Self.minNormalHeight, min(effectiveMaxHeight, frame.size.height))
            let targetY = max(visibleFrame.minY, min(visibleFrame.maxY - targetH, frame.origin.y))
            let targetX = max(visibleFrame.minX, min(visibleFrame.maxX - targetW, frame.origin.x))
            window.setFrame(NSRect(x: targetX, y: targetY, width: targetW, height: targetH), display: true)
        }
    }
    
    public func windowDidMove(_ notification: Notification) {
        guard let window = self.window, let screen = window.screen ?? NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        var adjusted = false
        
        if UserSettings.shared.isCompactMode {
            // En vue réduite, toujours plaqué en bas à droite
            if frame.origin.y != visibleFrame.minY {
                frame.origin.y = visibleFrame.minY
                adjusted = true
            }
            if frame.maxX != visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.size.width
                adjusted = true
            }
        } else {
            // Empêcher tout débordement hors de l'écran visible
            if frame.minX < visibleFrame.minX {
                frame.origin.x = visibleFrame.minX
                adjusted = true
            }
            if frame.maxX > visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.size.width
                adjusted = true
            }
            if frame.minY < visibleFrame.minY {
                frame.origin.y = visibleFrame.minY
                adjusted = true
            }
            if frame.maxY > visibleFrame.maxY {
                frame.origin.y = visibleFrame.maxY - frame.size.height
                adjusted = true
            }
        }
        
        if adjusted {
            window.setFrame(frame, display: true)
        }
    }
}
