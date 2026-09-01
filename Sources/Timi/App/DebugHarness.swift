import AppKit
import TimiKit

/// Development-only scripting console, active only when TIMI_DEBUG_DIR is set.
/// Polls `$TIMI_DEBUG_DIR/cmd` for one command per line, truncating after read:
///
///   snapshot <name>   render the panel's layer tree to <dir>/<name>.png (2×)
///   tap | reset | pat
///   start | pause | resume
///   duration <ms>
///   shift <ms>        pull endAt closer by ms (simulates sleep/clock jump)
///   wake              deliver a system-wake advance
///   hearts <n>
///   moveto <x> <y>    global AppKit coords
///   fling <vx> <vy>
///   quit
///
/// Used by the milestone verification scripts; never active in normal runs.
final class DebugHarness {
    private let dir: URL
    private let controller: PalController
    private var timer: Timer?

    init?(controller: PalController) {
        guard let path = ProcessInfo.processInfo.environment["TIMI_DEBUG_DIR"] else {
            return nil
        }
        self.dir = URL(fileURLWithPath: path)
        self.controller = controller
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func poll() {
        let cmdFile = dir.appendingPathComponent("cmd")
        guard let text = try? String(contentsOf: cmdFile, encoding: .utf8), !text.isEmpty else {
            return
        }
        try? "".write(to: cmdFile, atomically: true, encoding: .utf8)
        for line in text.split(separator: "\n") {
            run(command: line.split(separator: " ").map(String.init))
        }
    }

    private func run(command parts: [String]) {
        guard let cmd = parts.first else { return }
        let nowMs = CACurrentMediaTime() * 1000
        switch cmd {
        case "snapshot":
            snapshot(name: parts.count > 1 ? parts[1] : "snapshot")
        case "dump":
            dumpCanvas(name: parts.count > 1 ? parts[1] : "canvas")
        case "tap":
            controller.tapAction()
        case "reset":
            controller.resetAction()
        case "pat":
            controller.engine.patT = nowMs
            controller.engine.miniHearts.append(MiniHeart(x: 26, y: 12, vy: -7, life: 1.1))
        case "start":
            if controller.timer.mode == .idle { controller.tapAction() }
        case "pause":
            if controller.timer.mode == .running { controller.tapAction() }
        case "resume":
            if controller.timer.mode == .paused { controller.tapAction() }
        case "duration":
            if parts.count > 1, let ms = Double(parts[1]) { controller.pickDuration(ms: ms) }
        case "shift":
            if parts.count > 1, let ms = Double(parts[1]) { controller.timer.shiftEndAt(byMs: -ms) }
        case "wake":
            controller.systemDidWake()
        case "hearts":
            if parts.count > 1, let n = Int(parts[1]) { controller.setHearts(n) }
        case "moveto":
            if parts.count > 2, let x = Double(parts[1]), let y = Double(parts[2]) {
                controller.engine.home = Vec2(x, y)
                controller.engine.pos = Vec2(x, y)
            }
        case "fling":
            if parts.count > 2, let vx = Double(parts[1]), let vy = Double(parts[2]) {
                controller.engine.vel = Vec2(vx, vy)
                controller.engine.freeFlight = true
            }
        case "pdown":
            if parts.count > 2, let x = Double(parts[1]), let y = Double(parts[2]) {
                controller.engine.pointerDown(at: Vec2(x, y), tMs: nowMs)
            }
        case "pdrag":
            if parts.count > 2, let x = Double(parts[1]), let y = Double(parts[2]) {
                controller.engine.pointerDragged(to: Vec2(x, y), tMs: nowMs)
            }
        case "pup":
            controller.palViewMouseUp()
        case "hover":
            controller.debugHoverOverride = parts.count > 1 ? (parts[1] == "on") : nil
        case "scroll":
            if parts.count > 1, let dy = Double(parts[1]) {
                controller.palViewScrolled(deltaY: dy, precise: false, gestureBegan: true)
            }
        case "cabinet":
            controller.setCabinet(parts.count > 1 && parts[1] == "on")
        case "settings":
            (NSApp.delegate as? AppDelegate)?.showSettingsForDebug()
        case "hint":
            controller.showFirstRunHint()
        case "state":
            let e = controller.engine
            let info = "mode=\(controller.timer.mode.rawValue) pos=\(Int(e.pos.x)),\(Int(e.pos.y)) " +
                "settle=\(String(format: "%.2f", e.settle)) sleeping=\(e.flags.sleepingNow) " +
                "hearts=\(e.hearts)"
            try? info.write(to: dir.appendingPathComponent("state.txt"),
                            atomically: true, encoding: .utf8)
        case "quit":
            NSApp.terminate(nil)
        default:
            break
        }
    }

    /// ASCII rendering of the logical canvas: '.' empty, letters keyed by color.
    private func dumpCanvas(name: String) {
        var canvas = PixelCanvas()
        Renderer.draw(into: &canvas, engine: controller.engine)
        let pal = controller.engine.config.palette
        let legend: [(RGBA, Character)] = [
            (pal.primary, "P"), (pal.dim, "d"), (pal.eye, "E"), (pal.shadow, "s"),
            (pal.txt, "t"), (pal.slot, "o"), (pal.amber, "A"), (pal.red, "R"),
            (pal.pink, "p"), (pal.cyan, "c"), (.white, "W"),
        ]
        var out = ""
        for y in 0..<PixelCanvas.height {
            for x in 0..<PixelCanvas.width {
                let c = canvas.pixel(x, y)
                if c.a == 0 {
                    out.append(".")
                } else if let match = legend.first(where: { $0.0 == c }) {
                    out.append(match.1)
                } else {
                    out.append("?")
                }
            }
            out.append("\n")
        }
        try? out.write(to: dir.appendingPathComponent("\(name).txt"),
                       atomically: true, encoding: .utf8)
    }

    private func snapshot(name: String) {
        guard let view = controller.panel.contentView, let layer = view.layer else { return }
        let scale: CGFloat = 2
        let size = view.bounds.size
        guard let ctx = CGContext(
            data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.interpolationQuality = .none
        ctx.scaleBy(x: scale, y: scale)
        // macOS layers are y-up, matching the CG bitmap context — no flip needed.
        layer.render(in: ctx)
        guard let image = ctx.makeImage() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}
