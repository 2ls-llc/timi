#!/usr/bin/env swift
// Generates AppIcon.icns: Pip on a rounded dark stage, nearest-neighbor pixels.
// Usage: swift Packaging/make-icon.swift <output.icns>
import AppKit
import UniformTypeIdentifiers

let body = [
    "...#######...",
    "..#########..",
    ".###########.",
    "#############",
    "#############",
    "#############",
    "#############",
    ".###########.",
]
let feet = "..##.....##.."

func drawIcon(size: Int) -> CGImage? {
    let s = CGFloat(size)
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    ctx.interpolationQuality = .none

    // Rounded dark stage (macOS icon grid: content inset ~10%).
    let inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.2, cornerHeight: s * 0.2,
                      transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(CGColor(srgbRed: 0x10 / 255, green: 0x12 / 255, blue: 0x16 / 255, alpha: 1))
    ctx.fillPath()

    // Pip: 13 wide × 12 tall grid (ahoge + body + feet + shadow gap).
    let cell = (rect.width * 0.72) / 13
    let originX = rect.midX - cell * 6.5
    let originY = rect.midY - cell * 5.2
    func px(_ x: Int, _ y: Int, _ color: CGColor) {
        // y measured downward from the top of the sprite grid
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: originX + CGFloat(x) * cell,
                        y: originY + CGFloat(10 - y) * cell,
                        width: ceil(cell), height: ceil(cell)))
    }
    let mint = CGColor(srgbRed: 0xBA / 255, green: 0xF2 / 255, blue: 0xD0 / 255, alpha: 1)
    let dim = CGColor(srgbRed: 0x5F / 255, green: 0x9D / 255, blue: 0x80 / 255, alpha: 1)
    let eye = CGColor(srgbRed: 0x0D / 255, green: 0x0F / 255, blue: 0x12 / 255, alpha: 1)

    px(6, -1, mint)  // ahoge
    px(6, -2, mint)
    for (r, row) in body.enumerated() {
        for (c, ch) in row.enumerated() where ch == "#" {
            px(c, r, r == body.count - 1 && c >= 1 && c <= 11 ? dim : mint)
        }
    }
    for (c, ch) in feet.enumerated() where ch == "#" {
        px(c, body.count, mint)
    }
    // eyes (1×2 at cols 3 and 9, rows 3-4)
    for col in [3, 9] {
        px(col, 3, eye)
        px(col, 4, eye)
    }
    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                     UTType.png.identifier as CFString, 1, nil)
    else { fatalError("png dest") }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent("PixelPalIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

for (name, size) in [("icon_16x16", 16), ("icon_16x16@2x", 32),
                     ("icon_32x32", 32), ("icon_32x32@2x", 64),
                     ("icon_128x128", 128), ("icon_128x128@2x", 256),
                     ("icon_256x256", 256), ("icon_256x256@2x", 512),
                     ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    guard let img = drawIcon(size: size) else { fatalError("draw \(size)") }
    writePNG(img, to: tmp.appendingPathComponent("\(name).png"))
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", tmp.path, "-o", out]
task.launch()
task.waitUntilExit()
try? FileManager.default.removeItem(at: tmp)
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
print("wrote \(out)")
