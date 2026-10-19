import Foundation
import AppKit
import SwiftUI

/// Écrivain personnalisé pour le Pasteboard macOS garantissant la compatibilité totale
/// avec Serato DJ Pro (support simultané de .fileURL et NSFilenamesPboardType)
public final class AudioFilePasteboardWriter: NSObject, NSPasteboardWriting {
    public let fileURL: URL
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ]
    }
    
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .fileURL {
            return fileURL.absoluteString
        } else if type == NSPasteboard.PasteboardType("NSFilenamesPboardType") {
            return [fileURL.path]
        }
        return nil
    }
}

/// Vue AppKit native capturant le clic-glisser (Drag) vers Serato DJ Pro
public class DraggableGripNSView: NSView, NSDraggingSource {
    public var track: Track?
    private var mouseDownLocation: NSPoint?
    private var isDraggingActive: Bool = false
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
    
    public override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        isDraggingActive = false
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownLocation, !isDraggingActive else { return }
        
        let current = event.locationInWindow
        let dx = current.x - start.x
        let dy = current.y - start.y
        let distance = sqrt(dx * dx + dy * dy)
        
        // Seuil de déclenchement du glisser (3 pixels)
        if distance > 3.0 {
            isDraggingActive = true
            startDragSession(with: event)
        }
    }
    
    public override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
        isDraggingActive = false
    }
    
    private func startDragSession(with event: NSEvent) {
        guard let track = track,
              let path = track.filePath,
              FileManager.default.fileExists(atPath: path) else {
            // Fichier non trouvé sur le disque
            NSSound.beep()
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        let dragItem = NSDraggingItem(pasteboardWriter: (fileURL as NSURL))
        
        // Génération d'une vignette de glisser moderne
        let previewImage = createDragPreviewImage(for: track)
        let imageSize = previewImage.size
        let dragFrame = NSRect(
            x: bounds.midX - imageSize.width / 2,
            y: bounds.midY - imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        dragItem.setDraggingFrame(dragFrame, contents: previewImage)
        
        // Lancement de la session de glisser native macOS
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }
    
    // MARK: - NSDraggingSource
    
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    // MARK: - Création de l'image de prévisualisation flottante
    
    private func createDragPreviewImage(for track: Track) -> NSImage {
        let size = NSSize(width: 220, height: 44)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Fond sombre translucide avec bordure
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor(red: 0.12, green: 0.12, blue: 0.16, alpha: 0.95).setFill()
        path.fill()
        
        NSColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 0.8).setStroke()
        path.lineWidth = 1.5
        path.stroke()
        
        // Icône de disque / poignée
        let discRect = NSRect(x: 10, y: 12, width: 20, height: 20)
        let discPath = NSBezierPath(ovalIn: discRect)
        NSColor(red: 0.25, green: 0.65, blue: 1.0, alpha: 1.0).setFill()
        discPath.fill()
        
        // Texte du titre
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let titleString = NSString(string: track.displayTitle)
        titleString.draw(in: NSRect(x: 36, y: 22, width: 170, height: 16), withAttributes: titleAttrs)
        
        // Détails (BPM & Clé)
        let subText = "\(track.displayBpm) BPM • \(track.displayKey)"
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor(white: 0.75, alpha: 1.0)
        ]
        let subString = NSString(string: subText)
        subString.draw(in: NSRect(x: 36, y: 8, width: 170, height: 14), withAttributes: subAttrs)
        
        image.unlockFocus()
        return image
    }
}

/// Pont SwiftUI vers la vue AppKit de glisser-déposer
public struct DraggableGripRepresentable: NSViewRepresentable {
    public let track: Track
    
    public init(track: Track) {
        self.track = track
    }
    
    public func makeNSView(context: Context) -> DraggableGripNSView {
        let view = DraggableGripNSView()
        view.track = track
        return view
    }
    
    public func updateNSView(_ nsView: DraggableGripNSView, context: Context) {
        nsView.track = track
    }
}
