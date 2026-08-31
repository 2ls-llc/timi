import AppKit
import PixelPalKit

/// One chip: the prototype's `.pip-btn` — monospace 11 pt uppercase, 0.12 em letter
/// spacing, 3 pt corner radius, tinted borders, filled when selected.
final class ChipButton: NSButton {
    var chipTint: RGBA = Palette.pip.primary { didSet { restyle() } }
    var isSelectedChip = false { didSet { restyle() } }
    var darkTextColor = NSColor(srgbRed: 0x10 / 255, green: 0x12 / 255, blue: 0x16 / 255, alpha: 1)
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
    weak var controller: PalController?

    private let stack = NSStackView()
    private var visible = false

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

    private var mode: TimerMode { controller?.timer.mode ?? .idle }

    func modeChanged() { rebuild() }
    func characterChanged() { rebuild() }
    func refreshChips() { rebuild() }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let controller else { return }
        let tint = controller.engine.config.palette.primary
        let dark = controller.engine.config.id == .pip
            ? NSColor(srgbRed: 0x10 / 255, green: 0x12 / 255, blue: 0x16 / 255, alpha: 1)
            : NSColor(srgbRed: 0x16 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1)

        func chip(_ text: String, symbol: String? = nil, selected: Bool = false,
                  accessibility: String, action: @escaping () -> Void) -> ChipButton {
            let b = ChipButton()
            b.chipTint = tint
            b.darkTextColor = dark
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

    /// Prototype `showControls`: idle & paused always show (native: idle shows on
    /// hover), running shows on hover, done hides. Paused pins the strip visible.
    func updateVisibility(hovered: Bool, mode: TimerMode, tMs: Double) {
        let show: Bool
        switch mode {
        case .paused: show = true
        case .idle, .running: show = hovered
        case .done: show = false
        }
        guard show != visible else { return }
        visible = show
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
