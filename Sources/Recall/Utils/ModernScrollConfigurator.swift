import SwiftUI
import AppKit

/// Scroller moderne, discret et élégant pour le mode sombre de Recall.
/// Remplace la barre blanche épaisse native de macOS par une fine pilule translucide.
public class DarkModernScroller: NSScroller {
    public override class var isCompatibleWithOverlayScrollers: Bool {
        return true
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    /// Empêche tout dessin d'arrière-plan ou de rail blanc/gris opaque.
    public override func drawKnobSlot(in rect: NSRect, highlight: Bool) {
        // Laisser 100% transparent pour ne jamais faire tâche sur le thème sombre
    }
    
    /// Dessine une pilule de défilement ultra fine, discrète et esthétique.
    public override func drawKnob() {
        let knobRect = rect(for: .knob)
        guard knobRect.width > 0 && knobRect.height > 0 else { return }
        
        let thinWidth: CGFloat = 3.5
        let x = knobRect.maxX - thinWidth - 2.0
        let pillHeight = max(knobRect.height - 4, 18)
        let pillRect = NSRect(
            x: x,
            y: knobRect.origin.y + 2,
            width: thinWidth,
            height: pillHeight
        )
        
        let path = NSBezierPath(roundedRect: pillRect, xRadius: 1.75, yRadius: 1.75)
        
        // Opacité subtile et discrète
        let alpha: CGFloat = (hitPart == .knob) ? 0.45 : 0.22
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
    }
}

/// Modificateur appliquant le scroller moderne à n'importe quel NSScrollView SwiftUI
public struct ModernScrollConfigurator: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view: view)
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(view: nsView)
        }
    }
    
    private func configure(view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        
        if !(scrollView.verticalScroller is DarkModernScroller) {
            let customScroller = DarkModernScroller()
            customScroller.controlSize = .mini
            scrollView.verticalScroller = customScroller
        }
    }
}

public extension View {
    func modernDarkScrollbar() -> some View {
        self.background(ModernScrollConfigurator())
    }
}
