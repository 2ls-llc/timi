import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import PixelPalKit

/// Deterministic golden-image tests for every §12 state. On first run a missing
/// golden is recorded (test fails asking for a re-run); afterwards the rendered
/// canvas must match byte-for-byte. Files: Tests/snapshots/golden-<name>.png
/// (56×48) plus a golden-<name>@3x.png for human inspection.
final class RenderSnapshotTests: XCTestCase {
    private static let screen = Rect(x: 0, y: 0, w: 1440, h: 900)

    private static var snapshotsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PixelPalKitTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("snapshots")
    }

    private func makeEngine(_ id: CharacterID) -> PalEngine {
        PalEngine(config: .config(for: id), seed: 12345, tMs: 0,
                  home: Vec2(720, 450), hearts: 2)
    }

    private func input(t: Double, dt: Double = 1.0 / 60, mode: TimerMode,
                       durationMs: Double = 1_500_000, remainingMs: Double,
                       hovered: Bool = false) -> EngineInput {
        EngineInput(tMs: t, dt: dt, mode: mode, durationMs: durationMs,
                    remainingMs: remainingMs, cursor: Vec2(-9999, -9999),
                    cursorMoved: false, hovered: hovered, reduceMotion: false,
                    screen: Self.screen)
    }

    /// Advance the engine over [from, to] in fixed steps (deterministic).
    private func run(_ e: PalEngine, from: Double, to: Double,
                     mode: TimerMode, durationMs: Double = 1_500_000,
                     remaining: @escaping (Double) -> Double,
                     hovered: Bool = false) {
        var t = from
        while t < to {
            t += 1000.0 / 60
            _ = e.step(input(t: t, mode: mode, durationMs: durationMs,
                             remainingMs: remaining(t), hovered: hovered))
        }
    }

    private func render(_ e: PalEngine) -> PixelCanvas {
        var canvas = PixelCanvas()
        Renderer.draw(into: &canvas, engine: e)
        return canvas
    }

    // MARK: - PNG plumbing

    private func cgImage(from canvas: PixelCanvas, scale: Int) -> CGImage? {
        let data = Data(canvas.buffer)
        guard let provider = CGDataProvider(data: data as CFData),
              let base = CGImage(width: PixelCanvas.width, height: PixelCanvas.height,
                                 bitsPerComponent: 8, bitsPerPixel: 32,
                                 bytesPerRow: PixelCanvas.width * 4,
                                 space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                 bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                 provider: provider, decode: nil,
                                 shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        if scale == 1 { return base }
        let w = PixelCanvas.width * scale, h = PixelCanvas.height * scale
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                         UTType.png.identifier as CFString,
                                                         1, nil) else {
            throw NSError(domain: "snapshot", code: 1)
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }

    private func decodePixels(_ url: URL) -> [UInt8]? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = img.width, h = img.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buf
    }

    /// Premultiply the canvas the same way CGContext.draw does, for comparison.
    private func premultiplied(_ canvas: PixelCanvas) -> [UInt8] {
        var out = canvas.buffer
        var i = 0
        while i < out.count {
            let a = Int(out[i + 3])
            out[i] = UInt8((Int(out[i]) * a + 127) / 255)
            out[i + 1] = UInt8((Int(out[i + 1]) * a + 127) / 255)
            out[i + 2] = UInt8((Int(out[i + 2]) * a + 127) / 255)
            i += 4
        }
        return out
    }

    private func assertSnapshot(_ e: PalEngine, named name: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let canvas = render(e)
        let dir = Self.snapshotsDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let goldenURL = dir.appendingPathComponent("golden-\(name).png")
        let bigURL = dir.appendingPathComponent("golden-\(name)@3x.png")

        guard let img = cgImage(from: canvas, scale: 1) else {
            XCTFail("could not encode canvas", file: file, line: line)
            return
        }
        if !FileManager.default.fileExists(atPath: goldenURL.path) {
            try? writePNG(img, to: goldenURL)
            if let big = cgImage(from: canvas, scale: 3) {
                try? writePNG(big, to: bigURL)
            }
            XCTFail("Recorded new golden \(name) — re-run to verify", file: file, line: line)
            return
        }
        guard let goldenPixels = decodePixels(goldenURL) else {
            XCTFail("could not decode golden \(name)", file: file, line: line)
            return
        }
        let current = premultiplied(canvas)
        if goldenPixels != current {
            let diffCount = zip(goldenPixels, current).filter(!=).count / 4
            try? writePNG(img, to: dir.appendingPathComponent("failed-\(name).png"))
            XCTFail("snapshot \(name) differs from golden (~\(diffCount) channel diffs)",
                    file: file, line: line)
        }
    }

    // MARK: - Pip states

    func testPipIdle() {
        let e = makeEngine(.pip)
        run(e, from: 0, to: 1000, mode: .idle, remaining: { _ in 1_500_000 })
        assertSnapshot(e, named: "pip-idle")
    }

    func testPipRunningHiddenClock() {
        let e = makeEngine(.pip)
        run(e, from: 0, to: 500, mode: .running, remaining: { 1_200_000 - $0 })
        XCTAssertFalse(e.flags.labelVisible)
        assertSnapshot(e, named: "pip-running-hidden-clock")
    }

    func testPipPanic() {
        let e = makeEngine(.pip)
        // Enough time for a sweat drop to spawn (every 0.9 s).
        run(e, from: 0, to: 1200, mode: .running, remaining: { 9_000 - ($0 - 0) * 0 })
        XCTAssertTrue(e.flags.panic)
        XCTAssertFalse(e.sweats.isEmpty)
        assertSnapshot(e, named: "pip-panic")
    }

    func testPipDoneBanner() {
        let e = makeEngine(.pip)
        e.onFinish(tMs: 0, reduceMotion: false)
        // t chosen inside the banner window with the AMBER phase (floor(t/180)%2==1).
        run(e, from: 0, to: 190, mode: .done, remaining: { _ in 0 })
        assertSnapshot(e, named: "pip-done-banner")
    }

    func testPipSleeping() {
        let e = makeEngine(.pip)
        e.settle = 1
        e.wakeUntil = -1
        e.lastInteract = -20_000
        e.zs.append(ZParticle(x: 38, y: 12, life: 1.2))
        run(e, from: 0, to: 100, mode: .running, remaining: { 1_200_000 - $0 })
        XCTAssertTrue(e.flags.sleepingNow)
        assertSnapshot(e, named: "pip-sleeping")
    }

    func testPipHeld() {
        let e = makeEngine(.pip)
        _ = e.step(input(t: 16, mode: .idle, remainingMs: 1_500_000))
        e.pointerDown(at: Vec2(720, 450), tMs: 20)
        e.pointerDragged(to: Vec2(724, 458), tMs: 40)  // moved ≥ 6 px: a real drag
        run(e, from: 40, to: 400, mode: .idle, remaining: { _ in 1_500_000 })
        XCTAssertTrue(e.flags.airborne)
        assertSnapshot(e, named: "pip-held")
    }

    func testPipWallImpact() {
        let e = makeEngine(.pip)
        e.pos = Vec2(Physics.bounceHalfSize + 4, 450)
        e.vel = Vec2(-1400, 0)
        e.freeFlight = true
        run(e, from: 0, to: 40, mode: .idle, remaining: { _ in 1_500_000 })
        XCTAssertTrue(e.flags.squashing, "impact squash frame")
        assertSnapshot(e, named: "pip-wall-impact")
    }

    func testPipPat() {
        let e = makeEngine(.pip)
        run(e, from: 0, to: 100, mode: .idle, remaining: { _ in 1_500_000 })
        e.patT = 100
        e.miniHearts.append(MiniHeart(x: 26, y: 12, vy: -7, life: 1.1))
        run(e, from: 100, to: 400, mode: .idle, remaining: { _ in 1_500_000 })
        assertSnapshot(e, named: "pip-pat")
    }

    func testPipSad() {
        let e = makeEngine(.pip)
        e.onAbandon(tMs: 0)
        run(e, from: 0, to: 300, mode: .idle, remaining: { _ in 1_500_000 })
        assertSnapshot(e, named: "pip-sad")
    }

    func testPipBored() {
        let e = makeEngine(.pip)
        e.lastInteract = -40_000
        run(e, from: 0, to: 200, mode: .idle, remaining: { _ in 1_500_000 })
        XCTAssertTrue(e.flags.bored)
        XCTAssertTrue(e.flags.sit)
        assertSnapshot(e, named: "pip-bored")
    }

    // MARK: - Mochi states

    func testMochiNap() {
        let e = makeEngine(.mochi)
        e.settle = 1
        e.wakeUntil = -1
        e.lastInteract = -20_000
        e.zs.append(ZParticle(x: 38, y: 12, life: 1.2))
        run(e, from: 0, to: 100, mode: .running, remaining: { 1_200_000 - $0 })
        XCTAssertTrue(e.flags.sleepingNow)
        assertSnapshot(e, named: "mochi-nap")
    }

    func testMochiHuntCrouch() {
        let e = makeEngine(.mochi)
        run(e, from: 0, to: 600, mode: .running, remaining: { _ in 8_000 })
        XCTAssertTrue(e.flags.crouch)
        assertSnapshot(e, named: "mochi-hunt-crouch")
    }

    func testMochiWiggle() {
        let e = makeEngine(.mochi)
        // End on a frame where floor(t/80) is odd → wig = +1.
        run(e, from: 0, to: 250, mode: .running, remaining: { _ in 3_000 })
        XCTAssertTrue(e.flags.wiggle)
        XCTAssertNotEqual(e.flags.wig, 0)
        assertSnapshot(e, named: "mochi-wiggle")
    }

    func testMochiZoomies() {
        let e = makeEngine(.mochi)
        e.onFinish(tMs: 0, reduceMotion: false)
        run(e, from: 0, to: 1500, mode: .done, remaining: { _ in 0 })
        XCTAssertTrue(e.flags.zoomies)
        assertSnapshot(e, named: "mochi-zoomies")
    }

    func testMochiLoaf() {
        let e = makeEngine(.mochi)
        e.onFinish(tMs: 0, reduceMotion: false)
        run(e, from: 0, to: 3600, mode: .done, remaining: { _ in 0 })
        XCTAssertTrue(e.flags.loaf)
        assertSnapshot(e, named: "mochi-loaf")
    }
}
