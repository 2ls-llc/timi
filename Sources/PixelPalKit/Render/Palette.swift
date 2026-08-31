import Foundation

/// Character palette. Names follow the prototypes.
public struct Palette: Sendable {
    public var primary: RGBA   // MINT / CREAM
    public var dim: RGBA       // MINT_DIM / CREAM_DIM
    public var slot: RGBA
    public var amber: RGBA
    public var red: RGBA
    public var pink: RGBA
    public var cyan: RGBA
    public var txt: RGBA
    public var eye: RGBA
    public var shadow: RGBA
    /// Popped progress-bar segment flash color (#eafff3 pip / #fff3dd mochi).
    public var segPop: RGBA
    /// Milestone flash alpha (0.16 pip / 0.15 mochi).
    public var flashAlpha: Double

    public init(primary: RGBA, dim: RGBA, slot: RGBA, amber: RGBA, red: RGBA,
                pink: RGBA, cyan: RGBA, txt: RGBA, eye: RGBA, shadow: RGBA,
                segPop: RGBA, flashAlpha: Double) {
        self.primary = primary; self.dim = dim; self.slot = slot
        self.amber = amber; self.red = red; self.pink = pink; self.cyan = cyan
        self.txt = txt; self.eye = eye; self.shadow = shadow
        self.segPop = segPop; self.flashAlpha = flashAlpha
    }

    /// Pip — pip-timer-v4-3.jsx lines 27–36.
    public static let pip = Palette(
        primary: RGBA(hex: 0xBAF2D0), dim: RGBA(hex: 0x5F9D80), slot: RGBA(hex: 0x243029),
        amber: RGBA(hex: 0xFFD27A), red: RGBA(hex: 0xFF7A76), pink: RGBA(hex: 0xFF7A9E),
        cyan: RGBA(hex: 0x8FE3FF), txt: RGBA(hex: 0x8FD8B4), eye: RGBA(hex: 0x0D0F12),
        shadow: RGBA(hex: 0x070809),
        segPop: RGBA(hex: 0xEAFFF3), flashAlpha: 0.16)

    /// Mochi — mochi-timer.jsx lines 31–40.
    public static let mochi = Palette(
        primary: RGBA(hex: 0xFFE2B0), dim: RGBA(hex: 0x8A7048), slot: RGBA(hex: 0x2E2519),
        amber: RGBA(hex: 0xFFC86E), red: RGBA(hex: 0xFF7A76), pink: RGBA(hex: 0xFF8BA4),
        cyan: RGBA(hex: 0x9FD8EF), txt: RGBA(hex: 0xE6B377), eye: RGBA(hex: 0x120E08),
        shadow: RGBA(hex: 0x080604),
        segPop: RGBA(hex: 0xFFF3DD), flashAlpha: 0.15)

    /// Mochi's tail-tip highlight (#fff0d0).
    public static let mochiTailTip = RGBA(hex: 0xFFF0D0)
}
