import AppKit
import TimiKit

/// One chip: the prototype's `.mochi-btn` — monospace 11 pt uppercase, 0.12 em
/// letter spacing, 3 pt corner radius, tinted borders, filled when selected.
final class ChipButton: NSButton {
    var chipTint: RGBA = Palette.timi.primary { didSet { restyle() } }
    var isSelectedChip = false { didSet { restyle() } }
    /// Selected-chip text: the prototype's #16120c.
    var darkTextColor = NSColor(srgbRed: 0x16 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)
    private var hovering = false
    private var trackingArea: NSTrackingArea?

    var chipText: String = "" { didSet { restyle() } }
    var chipSymbol: String? { didSet { restyle() } }

    init() {
        super.init(frame: .zero)
        isBordered = false
        bezelStyle = .regularSquare
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.borderWidth = 1
        setButtonType(.momentaryChange)
        focusRingType = .none
        restyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let ta = NSTrackingArea(rect: bounds,
                                options: [.mouseEnteredAndExited, .activeAlways],
                                owner: self, userInfo: nil)
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) { hovering = true; restyle() }
    override func mouseExited(with event: NSEvent) { hovering = false; restyle() }

    private func tintColor(alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat(chipTint.r) / 255, green: CGFloat(chipTint.g) / 255,
                blue: CGFloat(chipTint.b) / 255, alpha: alpha)
    }

    private func restyle() {
        guard let layer else { return }
        let tint = tintColor(alpha: 1)
        if isSelectedChip {
            layer.backgroundColor = tint.cgColor
            layer.borderColor = tint.cgColor
        } else {
            layer.backgroundColor = tintColor(alpha: hovering ? 0.14 : 0.05).cgColor
            layer.borderColor = tintColor(alpha: 0.25).cgColor
        }
        let textColor: NSColor = isSelectedChip
            ? darkTextColor
            : (hovering ? tintColor(alpha: 1) : tintColor(alpha: 0.75))
        if let symbol = chipSymbol {
            let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: chipText)?
                .withSymbolConfiguration(config)
            image = img
            contentTintColor = textColor
            title = ""
        } else {
            image = nil
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .kern: 11 * 0.12,
            ]
            attributedTitle = NSAttributedString(string: chipText.uppercased(), attributes: attrs)
        }
    }

    override var intrinsicContentSize: NSSize {
        if chipSymbol != nil { return NSSize(width: 26, height: 26) }
        let base = super.intrinsicContentSize
        return NSSize(width: base.width + 16, height: 26)
    }
}

/// The hover-revealed controls strip below the pal: preset chips + mute while idle,
/// pause/resume + mute + reset while running/paused. Fades over 300 ms; pinned
/// visible while paused.
final class ControlsStrip: NSView {
    weak var controller: PalController? {
        didSet { rebuild() }
    }

    private let stack = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        alphaValue = 0
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.alignment = .centerY
        addSubview(stack)
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// The prototype hides the strip with `pointerEvents: "none"` alongside the
    /// opacity fade — a hidden strip must never swallow clicks. Gate on the
    /// target-visible state (`isShown`), NOT the model alphaValue: the animator
    /// snaps the model value to the fade target immediately, which would make
    /// the strip untouchable the instant a fade-out starts. Also restrict hits
    /// to the actual chip row, not the panel-wide layout band.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isShown else { return nil }
        let local = convert(point, from: superview)
        guard stack.frame.insetBy(dx: -4, dy: -4).contains(local) else { return nil }
        return super.hitTest(point)
    }

    /// The chip row's rect in the superview's (panel) coordinates — the hover
    /// target, tighter than the full-width layout frame.
    var chipRowFrameInPanel: NSRect {
        stack.frame.offsetBy(dx: frame.origin.x, dy: frame.origin.y)
            .insetBy(dx: -4, dy: -4)
    }

    private var mode: TimerMode { controller?.timer.mode ?? .idle }

    /// Chip label for a custom duration: "12m", or "1:30" when not whole minutes.
    static func compactLabel(ms: Double) -> String {
        let totalSeconds = Int((ms / 1000).rounded())
        let m = totalSeconds / 60, s = totalSeconds % 60
        return s == 0 ? "\(m)m" : "\(m):" + (s < 10 ? "0" : "") + "\(s)"
    }

    func modeChanged() { rebuild() }
    func refreshChips() { rebuild() }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let controller else { return }
        let tint = controller.engine.config.palette.primary

        func chip(_ text: String, symbol: String? = nil, selected: Bool = false,
                  accessibility: String, action: @escaping () -> Void) -> ChipButton {
            let b = ChipButton()
            b.chipTint = tint
            b.chipText = text
            b.chipSymbol = symbol
            b.isSelectedChip = selected
            b.onAction = action
            b.setAccessibilityLabel(accessibility)
            return b
        }

        let muted = controller.settings.muted
        let muteChip = chip("", symbol: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            accessibility: "toggle sound") { [weak controller] in
            controller?.toggleMute()
        }

        switch mode {
        case .idle:
            for (label, ms) in [("30s", 30_000.0), ("5m", 300_000.0),
                                ("15m", 900_000.0), ("25m", 1_500_000.0)] {
                stack.addArrangedSubview(chip(
                    label, selected: controller.timer.durationMs == ms,
                    accessibility: "set timer to \(label)") { [weak controller] in
                        controller?.pickDuration(ms: ms)
                    })
            }
            // "…" opens the custom-duration dialog; when a custom length is set
            // the chip shows it (e.g. 12M, 1:30) and takes the selected style.
            let presets: [Double] = [30_000, 300_000, 900_000, 1_500_000]
            let currentMs = controller.timer.durationMs
            let isCustom = !presets.contains(currentMs)
            stack.addArrangedSubview(chip(
                isCustom ? Self.compactLabel(ms: currentMs) : "…",
                selected: isCustom,
                accessibility: "custom duration") { [weak controller] in
                    controller?.promptCustomDuration()
                })
            stack.addArrangedSubview(muteChip)
        case .running, .paused:
            let running = mode == .running
            stack.addArrangedSubview(chip(
                "", symbol: running ? "pause.fill" : "play.fill",
                accessibility: running ? "pause timer" : "resume timer") { [weak controller] in
                    controller?.tapAction()
                })
            stack.addArrangedSubview(muteChip)
            stack.addArrangedSubview(chip(
                "", symbol: "arrow.counterclockwise",
                accessibility: "reset timer") { [weak controller] in
                    controller?.resetAction()
                })
        case .done:
            break
        }

        stack.setFrameSize(stack.fittingSize)
        stack.setFrameOrigin(NSPoint(x: (bounds.width - stack.frame.width) / 2,
                                     y: (bounds.height - stack.frame.height) / 2))
    }

    /// Target-visible state — true from the moment a show is requested until a
    /// hide fade begins. The hover/click-through logic keys off this.
    private(set) var isShown = false
    private var lastWantedShownAt = -1e9

    /// Prototype `showControls`: idle & paused always show (native: idle shows on
    /// hover), running shows on hover, done hides. Paused pins the strip visible.
    /// A 400 ms grace keeps it open while the cursor travels from the creature
    /// down across the gap to the chips — without it the strip starts fading the
    /// frame the cursor leaves the creature and the presets are unreachable.
    func updateVisibility(hovered: Bool, mode: TimerMode, tMs: Double) {
        let want: Bool
        switch mode {
        case .paused: want = true
        case .idle, .running: want = hovered
        case .done: want = false
        }
        if want { lastWantedShownAt = tMs }
        let inGrace = tMs - lastWantedShownAt < 400
        let show = want || (isShown && inGrace && mode != .done)
        guard show != isShown else { return }
        isShown = show
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            animator().alphaValue = show ? 1 : 0
        }
    }
}

/// Closure-based target/action for buttons.
extension ChipButton {
    private static var actionKey: UInt8 = 0
    var onAction: (() -> Void)? {
        get { objc_getAssociatedObject(self, &Self.actionKey) as? (() -> Void) }
        set {
            objc_setAssociatedObject(self, &Self.actionKey, newValue, .OBJC_ASSOCIATION_RETAIN)
            target = self
            action = #selector(fireAction)
        }
    }

    @objc private func fireAction() {
        onAction?()
    }
}
