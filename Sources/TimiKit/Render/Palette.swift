import Foundation

/// Timi's amber palette. Names follow the prototype (mochi-timer.jsx lines 31–40).
public struct Palette: Sendable {
    public var primary: RGBA   // CREAM
    public var dim: RGBA       // CREAM_DIM
    public var slot: RGBA
    public var amber: RGBA
    public var red: RGBA
    public var pink: RGBA
    public var cyan: RGBA
    public var txt: RGBA
    public var eye: RGBA
    public var shadow: RGBA
    /// Popped progress-bar segment flash color (#fff3dd).
    public var segPop: RGBA
    /// Milestone flash alpha (0.15).
    public var flashAlpha: Double

    public init(primary: RGBA, dim: RGBA, slot: RGBA, amber: RGBA, red: RGBA,
                pink: RGBA, cyan: RGBA, txt: RGBA, eye: RGBA, shadow: RGBA,
                segPop: RGBA, flashAlpha: Double) {
        self.primary = primary; self.dim = dim; self.slot = slot
        self.amber = amber; self.red = red; self.pink = pink; self.cyan = cyan
        self.txt = txt; self.eye = eye; self.shadow = shadow
        self.segPop = segPop; self.flashAlpha = flashAlpha
    }

    public static let timi = Palette(
        primary: RGBA(hex: 0xFFE2B0), dim: RGBA(hex: 0x8A7048), slot: RGBA(hex: 0x2E2519),
        amber: RGBA(hex: 0xFFC86E), red: RGBA(hex: 0xFF7A76), pink: RGBA(hex: 0xFF8BA4),
        cyan: RGBA(hex: 0x9FD8EF), txt: RGBA(hex: 0xE6B377), eye: RGBA(hex: 0x120E08),
        shadow: RGBA(hex: 0x080604),
        segPop: RGBA(hex: 0xFFF3DD), flashAlpha: 0.15)

    /// The tail-tip highlight (#fff0d0).
    public static let tailTip = RGBA(hex: 0xFFF0D0)
}
