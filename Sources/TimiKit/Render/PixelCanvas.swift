import Foundation

/// The 56×48 logical-pixel canvas. Non-premultiplied RGBA8, row-major, origin top-left
/// (y down) — identical addressing to the prototype's `<canvas>`.
public struct PixelCanvas {
    public static let width = 56
    public static let height = 48

    public private(set) var buffer: [UInt8]

    public init() {
        buffer = [UInt8](repeating: 0, count: Self.width * Self.height * 4)
    }

    public mutating func clear() {
        for i in buffer.indices { buffer[i] = 0 }
    }

    /// `px(g, x, y, c, w, h)` — clipped fillRect.
    public mutating func px(_ x: Int, _ y: Int, _ c: RGBA, _ w: Int = 1, _ h: Int = 1) {
        let x0 = max(0, x), y0 = max(0, y)
        let x1 = min(Self.width, x + w), y1 = min(Self.height, y + h)
        guard x0 < x1, y0 < y1 else { return }
        for yy in y0..<y1 {
            var i = (yy * Self.width + x0) * 4
            for _ in x0..<x1 {
                buffer[i] = c.r; buffer[i + 1] = c.g; buffer[i + 2] = c.b; buffer[i + 3] = c.a
                i += 4
            }
        }
    }

    /// `sprite(g, rows, x0, y0, c)` — "#" cells become pixels.
    public mutating func sprite(_ rows: [String], _ x0: Int, _ y0: Int, _ c: RGBA) {
        for (r, row) in rows.enumerated() {
            for (cc, ch) in row.utf8.enumerated() where ch == UInt8(ascii: "#") {
                px(x0 + cc, y0 + r, c)
            }
        }
    }

    /// `spriteLean` — top half rows shifted by `lean` (walking body tilt).
    public mutating func spriteLean(_ rows: [String], _ x0: Int, _ y0: Int, _ c: RGBA, _ lean: Int) {
        let half = Double(rows.count) / 2
        for (r, row) in rows.enumerated() {
            let off = Double(r) < half ? lean : 0
            for (cc, ch) in row.utf8.enumerated() where ch == UInt8(ascii: "#") {
                px(x0 + cc + off, y0 + r, c)
            }
        }
    }

    /// `drawText` — 3×5 font, advance = width+1, colon suppressible for blinking.
    public mutating func text(_ s: String, _ x0: Int, _ y0: Int, _ c: RGBA, colonOn: Bool = true) {
        var x = x0
        for ch in s {
            if let gl = Font3x5.glyphs[ch] {
                if ch != ":" || colonOn { sprite(gl, x, y0, c) }
                x += gl[0].count + 1
            } else {
                x += 4
            }
        }
    }

    /// Full-canvas alpha blend, used only by the 90 ms milestone flash
    /// (`rgba(primary, .16)` fillRect over everything).
    public mutating func flashOverlay(_ c: RGBA, alpha: Double) {
        let a = clamp(alpha, 0, 1)
        var i = 0
        while i < buffer.count {
            let dstA = Double(buffer[i + 3]) / 255
            let outA = a + dstA * (1 - a)
            if outA > 0 {
                let sr = Double(c.r), sg = Double(c.g), sb = Double(c.b)
                let dr = Double(buffer[i]), dg = Double(buffer[i + 1]), db = Double(buffer[i + 2])
                buffer[i] = UInt8((sr * a + dr * dstA * (1 - a)) / outA)
                buffer[i + 1] = UInt8((sg * a + dg * dstA * (1 - a)) / outA)
                buffer[i + 2] = UInt8((sb * a + db * dstA * (1 - a)) / outA)
                buffer[i + 3] = UInt8(outA * 255)
            }
            i += 4
        }
    }

    /// Sticker-style outline pass: every transparent pixel that touches an
    /// opaque pixel (8-neighborhood) is painted `color`. Keeps pixel purity
    /// while making the cream cat readable on light desktops — nearly invisible
    /// over dark wallpapers, transformative over light ones.
    public mutating func outline(_ color: RGBA) {
        let w = Self.width, h = Self.height
        // Snapshot which pixels are opaque before we start painting.
        var opaque = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) {
            opaque[i] = buffer[i * 4 + 3] > 0
        }
        for y in 0..<h {
            for x in 0..<w where !opaque[y * w + x] {
                var touches = false
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        let nx = x + dx, ny = y + dy
                        if nx >= 0, nx < w, ny >= 0, ny < h, opaque[ny * w + nx] {
                            touches = true
                        }
                    }
                }
                if touches {
                    let i = (y * w + x) * 4
                    buffer[i] = color.r
                    buffer[i + 1] = color.g
                    buffer[i + 2] = color.b
                    buffer[i + 3] = color.a
                }
            }
        }
    }

    /// Color at (x, y) — for tests.
    public func pixel(_ x: Int, _ y: Int) -> RGBA {
        let i = (y * Self.width + x) * 4
        return RGBA(r: buffer[i], g: buffer[i + 1], b: buffer[i + 2], a: buffer[i + 3])
    }
}
