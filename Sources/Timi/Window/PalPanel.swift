import AppKit
import TimiKit

/// Geometry shared by the panel and its layers. The creature's world position
/// (`PalEngine.pos`) maps to `creatureCenter` in panel coordinates.
enum PanelGeometry {
    static let size = NSSize(width: 340, height: 300)
    /// Creature center offset from the panel's bottom-left.
    static let creatureCenter = NSPoint(x: 170, y: 170)
    /// The 56×48 canvas at 3 pt per logical pixel.
    static let canvasSize = NSSize(width: 168, height: 144)
    static let glowSize = NSSize(width: 260, height: 230)
    /// Creature reaction halo (the prototype's canvas hover area), panel coords —
    /// drives gaze, the hover scale, the strip reveal, and cadence.
    static var creatureRect: NSRect {
        NSRect(x: creatureCenter.x - canvasSize.width / 2,
               y: creatureCenter.y - canvasSize.height / 2,
               width: canvasSize.width, height: canvasSize.height)
    }

    /// Interactive hit area — tight around the drawn cat (~50×36 pt of sprite
    /// plus grab slack), NOT the full halo. Clicks and scrolls outside this pass
    /// through to whatever is beneath; the halo alone must never eat input.
    static var creatureHitRect: NSRect {
        creatureRect.insetBy(dx: 40, dy: 30)
    }
    /// Controls strip: top edge 84 pt below the creature center (prototype `top: 84`).
    static let stripHeight: CGFloat = 26
    static var stripRect: NSRect {
        NSRect(x: 0, y: creatureCenter.y - 84 - stripHeight,
               width: size.width, height: stripHeight)
    }

    static func panelOrigin(forCreatureAt pos: Vec2) -> NSPoint {
        NSPoint(x: pos.x - creatureCenter.x, y: pos.y - creatureCenter.y)
    }
}

/// The floating, non-activating, click-through panel the pal lives in.
final class PalPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(origin: .zero, size: PanelGeometry.size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        animationBehavior = .none
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

protocol PalViewDelegate: AnyObject {
    func palViewMouseDown(at screenPoint: NSPoint)
    func palViewMouseDragged(to screenPoint: NSPoint)
    func palViewMouseUp()
    func palViewScrolled(deltaY: CGFloat, precise: Bool, gestureBegan: Bool)
}

/// Content view: hosts the glow + canvas layers and forwards mouse input.
/// Exposed to VoiceOver as a button whose value reads the timer state.
final class PalView: NSView {
    weak var delegate: PalViewDelegate?
    /// Set by the controller: ("Timi — pixel cat timer", "running, 12:34 remaining").
    var axLabel: String = "Pixel cat timer"
    var axValue: String = ""
    var onAccessibilityPress: (() -> Void)?
    /// Mode-appropriate VoiceOver actions (pause, reset, presets, sound…),
    /// built fresh by the controller each time VoiceOver asks.
    var axActionsProvider: (() -> [NSAccessibilityCustomAction])?

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { axLabel }
    override func accessibilityValue() -> Any? { axValue }
    override func accessibilityPerformPress() -> Bool {
        onAccessibilityPress?()
        return true
    }

    override func accessibilityCustomActions() -> [NSAccessibilityCustomAction]? {
        axActionsProvider?()
    }

    let glowLayer = CALayer()
    let cabinetLayer = CALayer()
    let canvasLayer = CALayer()
    let scanlineLayer = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never

        let noAnimations: [String: CAAction] = [
            "contents": NSNull(), "transform": NSNull(), "opacity": NSNull(),
            "position": NSNull(), "bounds": NSNull(), "hidden": NSNull(),
        ]

        glowLayer.frame = NSRect(
            x: PanelGeometry.creatureCenter.x - PanelGeometry.glowSize.width / 2,
            y: PanelGeometry.creatureCenter.y - PanelGeometry.glowSize.height / 2,
            width: PanelGeometry.glowSize.width, height: PanelGeometry.glowSize.height)
        glowLayer.actions = noAnimations
        layer?.addSublayer(glowLayer)

        cabinetLayer.frame = PanelGeometry.creatureRect.insetBy(dx: -16, dy: -16)
        cabinetLayer.actions = noAnimations
        cabinetLayer.isHidden = true
        layer?.addSublayer(cabinetLayer)

        canvasLayer.frame = PanelGeometry.creatureRect
        canvasLayer.magnificationFilter = .nearest
        canvasLayer.minificationFilter = .nearest
        canvasLayer.contentsGravity = .resize
        canvasLayer.actions = noAnimations
        layer?.addSublayer(canvasLayer)

        scanlineLayer.frame = cabinetLayer.frame
        scanlineLayer.actions = noAnimations
        scanlineLayer.isHidden = true
        layer?.addSublayer(scanlineLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window else { return .zero }
        let p = event.locationInWindow
        return NSPoint(x: window.frame.origin.x + p.x, y: window.frame.origin.y + p.y)
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.palViewMouseDown(at: screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        delegate?.palViewMouseDragged(to: screenPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        delegate?.palViewMouseUp()
    }

    override func scrollWheel(with event: NSEvent) {
        // Trackpad momentum would keep nudging the duration long after the
        // fingers lift; only the gesture itself counts.
        guard event.momentumPhase.isEmpty else { return }
        delegate?.palViewScrolled(deltaY: event.scrollingDeltaY,
                                  precise: event.hasPreciseScrollingDeltas,
                                  gestureBegan: event.phase == .began)
    }
}
