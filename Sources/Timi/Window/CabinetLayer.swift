import AppKit
import TimiKit

/// Optional "Cabinet" look: a small rounded CRT frame behind the canvas with the
/// prototype's dark radial stage colors, plus a scanline overlay above the canvas.
/// Off by default — the desktop is the stage.
enum CabinetImages {
    /// The stage background: rounded rect, radial dark gradient, faint tinted border.
    static func background(size: NSSize) -> CGImage? {
        let scale: CGFloat = 2
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        let rect = CGRect(origin: .zero, size: size)
        let path = CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                          cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(path)
        ctx.clip()

        // The prototype's amber stage: radial-gradient(#1a140c → #16120c → #0d0a06).
        let stops: [(CGFloat, UInt32)] = [(0, 0x1A140C), (0.55, 0x16120C), (1, 0x0D0A06)]
        let colors = stops.map { _, hex -> CGColor in
            CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        } as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                     colors: colors,
                                     locations: stops.map(\.0)) {
            let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.05)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center,
                                   endRadius: max(rect.width, rect.height) * 0.65,
                                   options: [.drawsAfterEndLocation])
        }
        // faint vignette edge
        ctx.resetClip()
        ctx.addPath(path)
        let tint = Palette.timi.primary
        ctx.setStrokeColor(CGColor(srgbRed: CGFloat(tint.r) / 255, green: CGFloat(tint.g) / 255,
                                   blue: CGFloat(tint.b) / 255, alpha: 0.22))
        ctx.setLineWidth(1)
        ctx.strokePath()
        return ctx.makeImage()
    }

    /// Scanlines above the canvas: repeating rgba(0,0,0,.16) 1 px lines every 3 px.
    static func scanlines(size: NSSize) -> CGImage? {
        let scale: CGFloat = 2
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        let path = CGPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1),
                          cornerWidth: 10, cornerHeight: 10, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.16))
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(CGRect(x: 0, y: y, width: size.width, height: 1))
            y += 3
        }
        return ctx.makeImage()
    }
}
