import Foundation
import AppKit
import SwiftUI

/// Panneau flottant Recall spécialisé désactivant tout comportement système indésirable lors d'un double-clic
public final class RecallFloatingPanel: NSPanel, NSDraggingDestination {
    public override func zoom(_ sender: Any?) {
        // Bloque le zoom et recentrage automatique de macOS
    }
    
    public override func performZoom(_ sender: Any?) {
        // Bloque le zoom automatique
    }
    
    public override func miniaturize(_ sender: Any?) {
        // Bloque la miniaturisation automatique
    }
    
    public override func performMiniaturize(_ sender: Any?) {
        // Bloque la miniaturisation automatique
    }
    
    public override var isZoomed: Bool {
        return false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return true
    }
    
    public override func sendEvent(_ event: NSEvent) {
        // Activation immédiate si clic alors que l'application n'est pas encore active
        if event.type == .leftMouseDown {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        
        // Raccourci clavier Cmd+, pour ouvrir directement les Paramètres
        if event.type == .keyDown {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == .command && event.charactersIgnoringModifiers == "," {
                SettingsWindowController.shared.toggle()
                return
            }
        }
        
        // Intercepte les double-clics (clickCount >= 2) sur les zones déplaçables du fond de l'application
        // pour empêcher macOS d'exécuter l'action système "Double-click a window's title bar to zoom/center"
        if (event.type == .leftMouseDown || event.type == .leftMouseUp) && event.clickCount >= 2 {
            if let contentView = self.contentView {
                let hitView = contentView.hitTest(event.locationInWindow)
                if !(hitView is NSTextView || hitView is NSTextField) {
                    return
                }
            }
        }
        super.sendEvent(event)
    }
    
    // MARK: - Réception Globale du Glisser-Déposer Serato / Rekordbox / Finder
    
    public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard ToPlayService.canHandle(pasteboard: sender.draggingPasteboard) else {
            return []
        }
        DispatchQueue.main.async {
            ToPlayService.shared.isDraggingFileOver = true
        }
        return .copy
    }
    
    public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard ToPlayService.canHandle(pasteboard: sender.draggingPasteboard) else {
            return []
        }
        return .copy
    }
    
    public func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async {
            ToPlayService.shared.isDraggingFileOver = false
        }
    }
    
    public func draggingEnded(_ sender: NSDraggingInfo) {
        DispatchQueue.main.async {
            ToPlayService.shared.isDraggingFileOver = false
        }
    }
    
    public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        DispatchQueue.main.async {
            ToPlayService.shared.isDraggingFileOver = false
        }
        guard ToPlayService.canHandle(pasteboard: sender.draggingPasteboard) else {
            return false
        }
        return ToPlayService.shared.handleDroppedPasteboard(sender.draggingPasteboard, sender: sender)
    }
}

public class FloatingWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = FloatingWindowController()
    
    public static let defaultNormalWidth: CGFloat = 360
    public static let defaultNormalHeight: CGFloat = 530
    public static let bandeauHeight: CGFloat = 54
    
    public static let minNormalWidth: CGFloat = 300
    public static let minNormalHeight: CGFloat = 227 // Hauteur minimale correspondant à 1 suggestion visible
    
    public static let minCompactWidth: CGFloat = 300 // Largeur minimale du mode réduit permettant un ancrage discret sur Serato
    public static let defaultCompactWidth: CGFloat = 360 // Largeur par défaut confortable pour le bandeau compact
    
    public static let maxWidth: CGFloat = 560
    public static let maxHeight: CGFloat = 720
    
    private var hasPositionedOnLaunch: Bool = false
    private var lastNormalHeight: CGFloat = 530
    private var lastNormalWidth: CGFloat = 360
    private var isAnimatingModeChange: Bool = false
    
    /// Retourne l'écran (NSScreen) sur lequel se trouve actuellement la fenêtre Recall
    public var currentScreen: NSScreen {
        if let win = window {
            if let s = win.screen {
                return s
            }
            let center = NSPoint(x: win.frame.midX, y: win.frame.midY)
            if let matched = NSScreen.screens.first(where: { NSPointInRect(center, $0.frame) }) {
                return matched
            }
            if let matched = NSScreen.screens.first(where: { NSPointInRect(win.frame.origin, $0.frame) }) {
                return matched
            }
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }
    
    public var effectiveMaxWidth: CGFloat {
        return min(Self.maxWidth, currentScreen.visibleFrame.width)
    }
    
    public var effectiveMaxHeight: CGFloat {
        return min(Self.maxHeight, currentScreen.visibleFrame.height)
    }
    
    public init() {
        let isCompact = UserSettings.shared.isCompactMode
        let initW = isCompact ? Self.defaultCompactWidth : Self.defaultNormalWidth
        let initH = isCompact ? Self.bandeauHeight : Self.defaultNormalHeight
        let minW = isCompact ? Self.minCompactWidth : Self.minNormalWidth
        let minH = isCompact ? Self.bandeauHeight : Self.minNormalHeight
        
        let panel = RecallFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: initW, height: initH),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: panel)
        
        // Autorise la hauteur minimale du bandeau pour permettre le passage dynamique au seuil
        panel.minSize = NSSize(width: minW, height: minH)
        panel.maxSize = NSSize(width: effectiveMaxWidth, height: effectiveMaxHeight)
        
        panel.delegate = self
        panel.title = "Recall"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.registerForDraggedTypes(ToPlayService.universalDragTypes)
        
        // Supprime complètement les boutons ronds standard de macOS pour libérer le coin supérieur gauche pour le logo Recall
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.closeButton)?.removeFromSuperview()
        panel.standardWindowButton(.miniaturizeButton)?.removeFromSuperview()
        panel.standardWindowButton(.zoomButton)?.removeFromSuperview()
        
        // Fond en verre dépoli natif macOS floutant les fenêtres sous Recall (Serato, Rekordbox, bureau)
        let effectView = NSVisualEffectView(frame: panel.contentLayoutRect)
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 14
        effectView.layer?.masksToBounds = true
        effectView.autoresizingMask = [.width, .height]
        
        // Configuration de la vue principale SwiftUI avec injection d'environnement
        let contentView = MainFloatingView()
            .environmentObject(SeratoMonitorService.shared)
            .environmentObject(UserSettings.shared)
        
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.frame = effectView.bounds
        if #available(macOS 13.0, *) {
            hostingView.sizingOptions = []
        }
        
        effectView.addSubview(hostingView)
        panel.contentView = effectView
        
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
        guard let window = self.window else { return }
        let screen = currentScreen
        let visibleFrame = screen.visibleFrame
        let isCompact = UserSettings.shared.isCompactMode
        let targetHeight = isCompact ? Self.bandeauHeight : Self.defaultNormalHeight
        let minW = isCompact ? Self.minCompactWidth : Self.minNormalWidth
        let defW = isCompact ? Self.defaultCompactWidth : Self.defaultNormalWidth
        let widthToUse = max(minW, min(effectiveMaxWidth, window.frame.size.width >= minW ? window.frame.size.width : defW))
        
        // Exactement collé au bord inférieur bas et droit de l'écran visible
        let x = visibleFrame.maxX - widthToUse
        let y = visibleFrame.minY
        window.minSize = NSSize(width: minW, height: isCompact ? Self.bandeauHeight : Self.minNormalHeight)
        window.setFrame(NSRect(x: x, y: y, width: widthToUse, height: targetHeight), display: true)
        hasPositionedOnLaunch = true
    }
    
    public func updateAlwaysOnTop(_ enabled: Bool) {
        guard let window = self.window else { return }
        window.level = enabled ? .floating : .normal
    }
    
    public func toggleCompactMode(_ compact: Bool) {
        guard let window = self.window else { return }
        let screen = currentScreen
        let visibleFrame = screen.visibleFrame
        let currentFrame = window.frame
        
        UserSettings.shared.isCompactMode = compact
        isAnimatingModeChange = true
        
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        let duration: TimeInterval = 0.28
        
        if compact {
            // Sauvegarder les dimensions normales si elles étaient valides
            if currentFrame.size.height >= Self.minNormalHeight {
                lastNormalHeight = currentFrame.size.height
            }
            if currentFrame.size.width >= Self.minNormalWidth {
                lastNormalWidth = currentFrame.size.width
            }
            targetHeight = Self.bandeauHeight
            
            // Conserve la largeur actuelle si elle respecte le minimum (300 pt), sinon applique la largeur par défaut (360 pt)
            let minW = Self.minCompactWidth
            let desiredW = currentFrame.size.width >= minW ? currentFrame.size.width : Self.defaultCompactWidth
            targetWidth = max(minW, min(effectiveMaxWidth, desiredW))
            
            // Déverrouille immédiatement la hauteur minimale vers celle du bandeau pour permettre l'animation fluide vers le bas
            window.minSize = NSSize(width: minW, height: Self.bandeauHeight)
            let x = visibleFrame.maxX - targetWidth
            let y = visibleFrame.minY
            let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: { [weak self] in
                self?.isAnimatingModeChange = false
            })
        } else {
            // Rétablir la hauteur et largeur normales
            let desiredH = lastNormalHeight >= Self.minNormalHeight ? lastNormalHeight : Self.defaultNormalHeight
            targetHeight = max(Self.minNormalHeight, min(effectiveMaxHeight, desiredH))
            
            let minW = Self.minNormalWidth
            let desiredW = lastNormalWidth >= minW ? lastNormalWidth : Self.defaultNormalWidth
            targetWidth = max(minW, min(effectiveMaxWidth, desiredW))
            
            let x = visibleFrame.maxX - targetWidth
            let y = visibleFrame.minY
            let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
            
            // NE PAS forcer window.minSize.height = minNormalHeight avant l'animation,
            // sinon Cocoa bloque la hauteur et saute brutalement de 54pt à 227pt sans fluidité.
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: { [weak self] in
                guard let self = self, let win = self.window else { return }
                self.isAnimatingModeChange = false
                if !UserSettings.shared.isCompactMode {
                    win.minSize = NSSize(width: minW, height: Self.minNormalHeight)
                }
            })
        }
    }
    
    // MARK: - Protection Anti-Zoom et Anti-Centrage Système (Double-Clic)
    
    public func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        // Empêche formellement tout zoom ou recentrage automatique provoqué par un double-clic
        return false
    }
    
    public func windowWillUseStandardFrame(_ window: NSWindow, defaultFrame newFrame: NSRect) -> NSRect {
        // Empêche l'agrandissement vers la frame standard ou le centre de l'écran
        return window.frame
    }
    
    // MARK: - Redimensionnement Interactif et Bascule Dynamique
    
    public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if isAnimatingModeChange {
            return frameSize
        }
        let screen = currentScreen
        let visibleFrame = screen.visibleFrame
        let maxH = min(Self.maxHeight, visibleFrame.height)
        let maxW = min(Self.maxWidth, visibleFrame.width)
        
        let isCompact = UserSettings.shared.isCompactMode
        let minW = isCompact ? Self.minCompactWidth : Self.minNormalWidth
        let clampedWidth = max(minW, min(maxW, frameSize.width))
        
        if isCompact {
            // VUE RÉDUITE : Si l'utilisateur agrandit vers le haut (> 89 pt), passage en vue normale
            let expansionThreshold: CGFloat = Self.bandeauHeight + 35 // 89 pt
            if frameSize.height > expansionThreshold {
                let targetH = max(Self.minNormalHeight, min(maxH, frameSize.height))
                lastNormalHeight = targetH
                UserSettings.shared.isCompactMode = false
                sender.minSize = NSSize(width: Self.minNormalWidth, height: Self.minNormalHeight)
                return NSSize(width: clampedWidth, height: targetH)
            } else {
                // Reste verrouillé au bandeau réduit avec la largeur minimale protégée
                return NSSize(width: clampedWidth, height: Self.bandeauHeight)
            }
        } else {
            // VUE NORMALE : Hauteur minimale équivalente à l'image fournie (227pt, 1 suggestion visible)
            let collapseThreshold: CGFloat = Self.minNormalHeight - 15 // 212 pt
            
            if frameSize.height < collapseThreshold {
                // Si on réduit plus que la hauteur minimale -> bascule automatique en vue réduite
                UserSettings.shared.isCompactMode = true
                sender.minSize = NSSize(width: Self.minCompactWidth, height: Self.bandeauHeight)
                let compactW = max(Self.minCompactWidth, clampedWidth)
                return NSSize(width: compactW, height: Self.bandeauHeight)
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
        if isAnimatingModeChange {
            return
        }
        guard let window = self.window else { return }
        let screen = currentScreen
        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        var adjusted = false
        
        // Empêcher tout débordement hors de l'écran en bas à droite
        if UserSettings.shared.isCompactMode {
            if frame.size.height != Self.bandeauHeight {
                frame.size.height = Self.bandeauHeight
                adjusted = true
            }
            if frame.size.width < Self.minCompactWidth {
                frame.size.width = Self.minCompactWidth
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
        guard let window = self.window else { return }
        let screen = currentScreen
        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        
        if UserSettings.shared.isCompactMode {
            let targetW = max(Self.minCompactWidth, min(effectiveMaxWidth, frame.size.width))
            window.minSize = NSSize(width: Self.minCompactWidth, height: Self.bandeauHeight)
            window.setFrame(NSRect(x: visibleFrame.maxX - targetW, y: visibleFrame.minY, width: targetW, height: Self.bandeauHeight), display: true)
        } else {
            let targetW = max(Self.minNormalWidth, min(effectiveMaxWidth, frame.size.width))
            let targetH = max(Self.minNormalHeight, min(effectiveMaxHeight, frame.size.height))
            let targetY = max(visibleFrame.minY, min(visibleFrame.maxY - targetH, frame.origin.y))
            let targetX = max(visibleFrame.minX, min(visibleFrame.maxX - targetW, frame.origin.x))
            window.minSize = NSSize(width: Self.minNormalWidth, height: Self.minNormalHeight)
            window.setFrame(NSRect(x: targetX, y: targetY, width: targetW, height: targetH), display: true)
        }
    }
    
    public func windowDidMove(_ notification: Notification) {
        guard let window = self.window else { return }
        let screen = currentScreen
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
