import AppKit
import TimiKit

/// Pre-rendered radial glow, matching the prototype's
/// `radial-gradient(circle, rgba(tint,.14) 0%, rgba(tint,0) 62%)` on a 260×230 div
/// (circle extent = farthest corner). Opacity is animated per frame by the engine.
enum GlowImage {
    static func make(tint: RGBA, size: NSSize) -> CGImage? {
        let w = Int(size.width * 2), h = Int(size.height * 2)  // 2× for retina
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let center = CGPoint(x: CGFloat(w) / 2, y: CGFloat(h) / 2)
        // farthest-corner radius
        let radius = hypot(center.x, center.y)
        let colors = [
            CGColor(srgbRed: CGFloat(tint.r) / 255, green: CGFloat(tint.g) / 255,
                    blue: CGFloat(tint.b) / 255, alpha: 0.14),
            CGColor(srgbRed: CGFloat(tint.r) / 255, green: CGFloat(tint.g) / 255,
                    blue: CGFloat(tint.b) / 255, alpha: 0),
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                        colors: colors, locations: [0, 0.62]) else { return nil }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: radius,
                               options: [])
        return ctx.makeImage()
    }
}

/// The pal's canvas bitmap → CGImage (non-premultiplied RGBA8, nearest-scaled by CA).
enum CanvasImage {
    static func make(from canvas: PixelCanvas) -> CGImage? {
        let data = Data(canvas.buffer)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: PixelCanvas.width, height: PixelCanvas.height,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: PixelCanvas.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)
    }
}
