#!/usr/bin/env swift
// Generates AppIcon.icns: Timi the cat on a rounded dark stage, nearest-neighbor
// pixels. Usage: swift Packaging/make-icon.swift <output.icns>
import AppKit
import UniformTypeIdentifiers

let body = [
    ".###########.",
    "#############",
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

    // Rounded dark stage (the prototype's amber CRT), content inset ~10%.
    let inset = s * 0.09
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = CGPath(roundedRect: rect, cornerWidth: s * 0.2, cornerHeight: s * 0.2,
                      transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(CGColor(srgbRed: 0x16 / 255, green: 0x12 / 255, blue: 0x0C / 255, alpha: 1))
    ctx.fillPath()

    // Timi: 13 wide grid (ears + body + feet).
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
    let cream = CGColor(srgbRed: 0xFF / 255, green: 0xE2 / 255, blue: 0xB0 / 255, alpha: 1)
    let dim = CGColor(srgbRed: 0x8A / 255, green: 0x70 / 255, blue: 0x48 / 255, alpha: 1)
    let eye = CGColor(srgbRed: 0x12 / 255, green: 0x0E / 255, blue: 0x08 / 255, alpha: 1)
    let pink = CGColor(srgbRed: 0xFF / 255, green: 0x8B / 255, blue: 0xA4 / 255, alpha: 1)

    // ears (with pink inners)
    px(1, -1, cream); px(1, -2, cream); px(2, -1, cream)
    px(11, -1, cream); px(11, -2, cream); px(10, -1, cream)
    px(1, -1, pink); px(11, -1, pink)
    for (r, row) in body.enumerated() {
        for (c, ch) in row.enumerated() where ch == "#" {
            px(c, r, r == body.count - 1 && c >= 1 && c <= 11 ? dim : cream)
        }
    }
    for (c, ch) in feet.enumerated() where ch == "#" {
        px(c, body.count, cream)
    }
    // eyes (1×2 at cols 3 and 9) and nose
    for col in [3, 9] {
        px(col, 3, eye)
        px(col, 4, eye)
    }
    px(6, 5, pink)
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
    .appendingPathComponent("TimiIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
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
