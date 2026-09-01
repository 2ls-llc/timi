import AppKit
import TimiKit

/// One-time first-run hint — the prototype's footer line, native-sized: a small
/// dark pill above the cat that reads on any wallpaper, never intercepts clicks,
/// and dismisses on the first interaction (or after a while).
final class HintLabel: NSView {
    private let label = NSTextField(labelWithString: "")

    init(tint: RGBA) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor(srgbRed: 0x16 / 255, green: 0x12 / 255,
                                         blue: 0x0C / 255, alpha: 0.8).cgColor

        let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
        let color = NSColor(srgbRed: CGFloat(tint.r) / 255, green: CGFloat(tint.g) / 255,
                            blue: CGFloat(tint.b) / 255, alpha: 0.95)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2
        label.attributedStringValue = NSAttributedString(
            string: "TAP TO START · HOLD TO PAT\nDRAG OR FLING · SCROLL = TIME",
            attributes: [.font: font, .foregroundColor: color, .kern: 1.0,
                         .paragraphStyle: paragraph])
        label.maximumNumberOfLines = 2
        label.alignment = .center
        label.sizeToFit()
        addSubview(label)

        let w = label.frame.width + 22, h = label.frame.height + 12
        frame = NSRect(x: 0, y: 0, width: w, height: h)
        label.frame.origin = NSPoint(x: 11, y: 6)
        alphaValue = 0
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Tap Timi to start, hold to pat, drag or fling her anywhere, scroll to change the time")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    /// Purely informational — clicks fall through to whatever is beneath.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func show() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            self.animator().alphaValue = 1
        }
    }

    func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.removeFromSuperview()
        })
    }
}
