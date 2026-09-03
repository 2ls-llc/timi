import Foundation

// MARK: - Particles

public struct Confetti {
    public var x, y, vx, vy, life: Double
    public var c: RGBA
    public init(x: Double, y: Double, vx: Double, vy: Double, life: Double, c: RGBA) {
        self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.life = life; self.c = c
    }
}
public struct ZParticle {
    public var x, y, life: Double
    public init(x: Double, y: Double, life: Double) {
        self.x = x; self.y = y; self.life = life
    }
}
public struct MiniHeart {
    public var x, y, vy, life: Double
    public init(x: Double, y: Double, vy: Double, life: Double) {
        self.x = x; self.y = y; self.vy = vy; self.life = life
    }
}
public struct FlyHeart {
    public var x, y, t0: Double
    public init(x: Double, y: Double, t0: Double) {
        self.x = x; self.y = y; self.t0 = t0
    }
}

// MARK: - I/O

/// Everything the engine needs for one frame. `tMs` is monotonic milliseconds
/// (CACurrentMediaTime-based — the native `performance.now()`), timer fields come
/// from TimerCore at the same instant, cursor/screen are global AppKit coordinates.
public struct EngineInput {
    public var tMs: Double
    public var dt: Double
    public var mode: TimerMode
    public var durationMs: Double
    public var remainingMs: Double
    public var cursor: Vec2
    public var cursorMoved: Bool
    public var hovered: Bool
    public var reduceMotion: Bool
    public var screen: Rect

    public init(tMs: Double, dt: Double, mode: TimerMode, durationMs: Double,
                remainingMs: Double, cursor: Vec2, cursorMoved: Bool, hovered: Bool,
                reduceMotion: Bool, screen: Rect) {
        self.tMs = tMs; self.dt = dt; self.mode = mode
        self.durationMs = durationMs; self.remainingMs = remainingMs
        self.cursor = cursor; self.cursorMoved = cursorMoved; self.hovered = hovered
        self.reduceMotion = reduceMotion; self.screen = screen
    }
}

public enum EngineEvent: Equatable {
    /// The flying heart reached its slot — the visible count just incremented.
    case heartLanded
}

public struct StepResult {
    public var sounds: [PalSound] = []
    public var events: [EngineEvent] = []
}

/// Per-frame derived values the renderer reads. Computed at the end of `step`.
public struct FrameFlags {
    public var tMs = 0.0
    public var reduceMotion = false
    public var running = false
    public var panic = false       // the hunt: rem ≤ 10 s
    public var wiggle = false      // pre-pounce butt wiggle (rem ≤ 3.5 s)
    public var zoomies = false
    public var bored = false
    public var purring = false     // t − patT < 1500
    public var happy = false       // t < happyUntil && !panic && !sleeping
    public var stretching = false  // TALL stretch window
    public var sleepingNow = false
    public var blinking = false
    public var landing = false
    public var walking = false
    public var airborne = false
    public var worried = false
    public var noticing = false    // ears perk window (600 ms)
    public var squashing = false
    public var loaf = false
    public var crouch = false      // hunt crouch
    public var speed = 0.0
    public var lean = 0
    public var wig = 0             // wiggle px offset
    public var bounce = 0
    public var lift = 0
    public var eox = 0
    public var eoy = 0
    public var sxc = 1.0
    public var syc = 1.0
    public var glowOpacity = 0.5
    public var canvasOpacity = 1.0
    public var labelVisible = false
    public var segs = 20
    public var flyHeartPos: Vec2?
}

public enum PointerUpAction {
    case none, tap, pat, flung, settled
}

// MARK: - Engine

/// The cat prototype's frame-loop state machine `S`, ported field-for-field.
/// Position space: global AppKit screen coordinates (y up). Canvas/hop space:
/// 56×48 logical pixels (y down). Time: monotonic milliseconds.
public final class PalEngine {
    public let config: CharacterConfig
    public var rng: SplitMix64

    // Physics (screen coords, y up)
    public var pos = Vec2()
    public var vel = Vec2()
    public var home = Vec2()
    public var dragging = false
    public var dragPointer = Vec2()
    public var dragOffset = Vec2()
    public var moved = 0.0
    public var freeFlight = false
    public var scale = 1.0
    public var scaleVel = 0.0

    // Animation state
    public var phase = 0.0
    public var blinkT = -1e9
    public var nextBlink = Double.infinity
    public var winking = false
    public var glance = Vec2()
    public var glanceUntil = 0.0
    public var gaze = Vec2()               // canvas px, y down
    public var nextFidget = Double.infinity
    public var settle = 0.0
    public var lastInteract = 0.0
    public var wakeUntil = 0.0
    public var sleeping = false
    public var wakeFlash = -1e9
    public var hearts = 0
    public var conf: [Confetti] = []
    public var zs: [ZParticle] = []
    public var miniHearts: [MiniHeart] = []
    public var lastZ = 0.0
    public var flashT = -1e9
    public var hopY = 0.0
    public var hopV = 0.0
    public var landT = -1e9
    public var doneT = -1e9
    public var prevSegs = -1
    public var segPopT = -1e9
    /// set when the flying heart lands — the ♥ tally glyph flashes for 130 ms
    public var heartPopT = -1e9
    public var segPopI = -1
    public var noticeT = -1e9
    public var prevHovered = false
    public var pressT = 0.0
    public var patT = -1e9
    public var flyHeart: FlyHeart?
    public var happyUntil = -1e9
    public var sadUntil = -1e9

    // Cat-specific
    public var tail: [Double] = [-1.9, -1.9, -1.9, -1.9]
    public var stretchT = -1e9
    public var lastPurr = -1e9

    // Engine-internal one-shot timeline (replaces the prototype's setTimeout)
    var wave2At = Double.infinity
    var finishMewAt = Double.infinity
    var pendingHeartLand = false

    /// High-contrast outline for light desktops (setting; also forced on by the
    /// system's Increase Contrast). Read by the renderer.
    public var outlineEnabled = true

    // Latest inputs (kept for pointerUp, which needs screen bounds)
    public private(set) var screen = Rect(x: 0, y: 0, w: 1440, h: 900)
    public private(set) var mode: TimerMode = .idle
    public private(set) var durationMs = TimerCore.defaultDurationMs
    public private(set) var remainingMs = TimerCore.defaultDurationMs
    public private(set) var hovered = false
    public private(set) var reduceMotion = false

    public private(set) var flags = FrameFlags()

    public init(config: CharacterConfig = .timi, seed: UInt64, tMs: Double,
                home: Vec2, hearts: Int) {
        self.config = config
        self.rng = SplitMix64(seed: seed)
        self.home = home
        self.pos = home
        self.hearts = hearts
        // Mount timings from the prototype
        self.nextFidget = tMs + 6000
        self.nextBlink = tMs + 2400
        self.lastInteract = tMs
    }

    // MARK: - Pointer input

    public func pointerDown(at p: Vec2, tMs: Double) {
        dragging = true
        freeFlight = false
        moved = 0
        pressT = tMs
        lastInteract = tMs
        dragPointer = p
        dragOffset = Vec2(p.x - pos.x, p.y - pos.y)
    }

    public func pointerDragged(to p: Vec2, tMs: Double) {
        guard dragging else { return }
        moved += hypot(p.x - dragPointer.x, p.y - dragPointer.y)
        dragPointer = p
        lastInteract = tMs
    }

    /// Release: tap (< 6 px, < 450 ms), pat (< 6 px, ≥ 450 ms), fling (speed > 650),
    /// or settle home where dropped.
    public func pointerUp(tMs: Double) -> PointerUpAction {
        guard dragging else { return .none }
        dragging = false
        if moved < 6 {
            if tMs - pressT >= 450 {
                patT = tMs
                miniHearts.append(MiniHeart(x: 24 + rng.next() * 8, y: 12, vy: -7, life: 1.1))
                return .pat
            }
            return .tap
        }
        let spd = hypot(vel.x, vel.y)
        if spd > Physics.throwSpeed {
            let cap = Physics.throwSpeedCap / max(spd, 1)
            if cap < 1 { vel.x *= cap; vel.y *= cap }
            freeFlight = true
            return .flung
        }
        home = Physics.clampHome(pos, in: screen)
        return .settled
    }

    /// Any other interaction the pal should notice (hotkey, scroll, menu action).
    public func noteInteraction(tMs: Double) {
        lastInteract = tMs
    }

    // MARK: - Timer-driven visual reactions

    public func onStart(tMs: Double, reduceMotion: Bool) {
        if !reduceMotion {
            scale = 0.8
            hopV = -30
        }
        wakeUntil = tMs + 3000
    }

    public func onMilestone(_ m: Milestone, tMs: Double, reduceMotion: Bool) {
        flashT = tMs
        wakeUntil = tMs + 2600
        if m != .minute && !reduceMotion {
            hopV = -34
        }
    }

    public func onFinish(tMs: Double, reduceMotion: Bool) {
        freeFlight = false
        flyHeart = FlyHeart(x: 28, y: 18, t0: tMs + config.flyHeartDelayMs)
        happyUntil = tMs + config.happyMs
        doneT = tMs
        if !reduceMotion {
            // The pounce: leap toward the screen's center.
            hopV = config.finishHopImpulse
            vel.x += (pos.x < screen.midX ? 1 : -1) * 260
            spawnConfettiWave(28)
            wave2At = tMs + 600
        }
        finishMewAt = tMs + 700
        // Glide to the center of the current screen (20 pt above center).
        home = Vec2(screen.midX, screen.midY + 20)
    }

    public func onAbandon(tMs: Double) {
        sadUntil = tMs + 5000
    }

    private func spawnConfettiWave(_ n: Int) {
        let pal = config.palette
        let colors: [RGBA] = [pal.primary, pal.amber, pal.pink, pal.cyan, .white]
        for i in 0..<n {
            conf.append(Confetti(
                x: 28 + (rng.next() - 0.5) * 10,
                y: 22,
                vx: (rng.next() - 0.5) * 40,
                vy: -30 - rng.next() * 45,
                life: 1.4 + rng.next() * 0.5,
                c: colors[i % 5]))
        }
    }

    // MARK: - The frame step (the prototype's `loop`)

    public func step(_ input: EngineInput) -> StepResult {
        var out = StepResult()
        let t = input.tMs
        let dt = clamp(input.dt, 0, 0.05)
        let rm = input.reduceMotion

        screen = input.screen
        mode = input.mode
        durationMs = input.durationMs
        remainingMs = input.remainingMs
        hovered = input.hovered
        reduceMotion = rm

        if input.cursorMoved {
            let d = hypot(input.cursor.x - pos.x, input.cursor.y - pos.y)
            if d <= 300 { lastInteract = t }
        }

        let p = mode == .idle ? 0 : mode == .done ? 1 : clamp(1 - remainingMs / durationMs, 0, 1)
        let remS = remainingMs / 1000
        let running = mode == .running
        let panic = running && remS <= 10          // the hunt
        let wiggle = running && remS <= 3.5        // pre-pounce butt wiggle
        let zoomies = mode == .done && t - doneT > 900 && t - doneT < 3200 && !rm

        // settle → cat nap
        let settleTarget: Double =
            running && !hovered && !dragging && !freeFlight &&
            t > wakeUntil && t - lastInteract > 10000 && remS > 75 ? 1 : 0
        settle += (settleTarget - settle) * min(1, dt * (settleTarget > settle ? 0.35 : 2.8))
        let sleepingNow = settle > 0.6
        if sleepingNow != sleeping {
            sleeping = sleepingNow
            if sleepingNow {
                out.sounds.append(.sleepy)
            } else {
                wakeFlash = t
                out.sounds.append(.mew)
                stretchT = t
            }
        }
        let bored = mode == .idle && t - lastInteract > 30000

        // purr loop + happy
        let purring = t - patT < 1500
        let happy = t < happyUntil && !panic && !sleepingNow
        if purring && t - lastPurr > 1450 {
            lastPurr = t
            out.sounds.append(.purr)
        }

        // breath
        var period: Double =
            mode == .paused ? 5.5 :
            mode == .idle ? 3.2 :
            mode == .done ? config.breathDonePeriod :
            lerp(3.2, 1.0, p * p)
        if panic { period = config.panicBreathPeriod }
        period *= 1 + 0.8 * settle
        phase += (TAU * dt) / period

        // blink / wink (never while hunting — the eyes stay locked)
        if t > nextBlink && !sleepingNow && !rm && !panic {
            blinkT = t
            winking = rng.next() < 0.25
            if rng.next() < 0.2 {
                nextBlink = t + 300
            } else {
                nextBlink = t + 2800 + rng.next() * 5000
            }
        }
        let blinking = t - blinkT < 140

        // fidgets: stroll, hop, glance, big stretch, ear twitch
        if mode == .idle && !dragging && !rm && !bored && t > nextFidget {
            let r = rng.next()
            if r < 0.3 {
                wanderFidget()
            } else if r < 0.5 {
                hopV = -32
            } else if r < 0.7 {
                glance = Vec2((rng.next() - 0.5) * 8, 0)
                glanceUntil = t + 900
            } else if r < 0.9 {
                stretchT = t   // big stretch
            } else {
                noticeT = t    // ear twitch
            }
            nextFidget = t + 8000 + rng.next() * 9000
        }
        if mode != .idle { nextFidget = t + 7000 }
        let stretching = t - stretchT < 650

        // hop physics (canvas pixels, y down)
        let landedHard = Physics.hopStep(hopY: &hopY, hopV: &hopV, dt: dt)
        if landedHard && !rm {
            landT = t
            out.sounds.append(.thud)
        }
        let landing = t - landT < 100

        // zoomies drive the home target back and forth
        if zoomies {
            let amp = min(80, screen.w * 0.18)
            home.x = screen.midX + sin((t - doneT - 900) / 135) * amp
        }

        // motion
        if freeFlight && !dragging {
            if let imp = Physics.flightStep(pos: &pos, vel: &vel, bounds: screen, dt: dt) {
                scale = min(scale, 1 - 0.18 * imp)
                lastInteract = t
                out.sounds.append(.boing(imp))
                if imp > 0.55 {
                    out.sounds.append(.hiss(imp))
                }
            }
            if hypot(vel.x, vel.y) < Physics.flightExitSpeed {
                freeFlight = false
                home = Physics.clampHome(pos, in: screen)
            }
        } else {
            let target = dragging
                ? Vec2(dragPointer.x - dragOffset.x, dragPointer.y - dragOffset.y)
                : home
            let stiff = dragging ? Physics.dragStiffness : zoomies ? Physics.zoomiesStiffness : Physics.homeStiffness
            let damp = dragging ? Physics.dragDamping : zoomies ? Physics.zoomiesDamping : Physics.homeDamping
            Physics.springStep(pos: &pos, vel: &vel, target: target, stiffness: stiff, damping: damp, dt: dt)
        }

        // scale spring (hover 1.06)
        let targetScale = hovered && mode != .done ? 1.06 : 1.0
        scaleVel += (targetScale - scale) * Physics.scaleStiffness * dt
        scaleVel *= exp(-Physics.scaleDamping * dt)
        scale += scaleVel * dt

        let speed = hypot(vel.x, vel.y)
        let walking = speed > Physics.walkSpeed && !dragging && !freeFlight
        let airborne = dragging || freeFlight

        // gaze (canvas px, y down — flip the vertical from AppKit's y-up)
        var gx = 0.0, gy = 0.0
        var near = false
        if !dragging {
            let dx = input.cursor.x - pos.x
            let dyDown = pos.y - input.cursor.y
            let d = max(hypot(dx, dyDown), 1)
            if d < 300 {
                near = true
                gx = (dx / d) * 4
                gy = (dyDown / d) * 4
            }
        }
        if !near && t < glanceUntil {
            gx = glance.x
            gy = glance.y
        }
        gaze.x += (gx - gaze.x) * min(1, dt * 6)
        gaze.y += (gy - gaze.y) * min(1, dt * 6)

        // tail chain physics
        let tailBase: Double
        if dragging || freeFlight {
            tailBase = 1.35                                  // hangs
        } else if sleepingNow {
            tailBase = -2.6
        } else if panic {
            tailBase = -1.6 + sin(t / 45) * 0.9              // whipping
        } else if purring || happy {
            tailBase = -1.9 + sin(t / 420) * 0.5             // content sway
        } else {
            tailBase = -1.9 + sin(t / 640) * 0.35 + clamp(-vel.x * 0.0016, -0.5, 0.5)
        }
        tail[0] += (tailBase - tail[0]) * min(1, dt * 8)
        for i in 1..<4 {
            tail[i] += (tail[i - 1] - tail[i]) * min(1, dt * (7 - Double(i) * 1.2))
        }

        // hover notice (ears perk)
        if hovered != prevHovered {
            prevHovered = hovered
            if hovered { noticeT = t }
        }

        // particles
        if sleepingNow && t - lastZ > 1700 && !rm {
            lastZ = t
            zs.append(ZParticle(x: 38, y: 14, life: 1.8))
        }
        if t >= wave2At {
            wave2At = .infinity
            if !rm { spawnConfettiWave(16) }
        }
        if t >= finishMewAt {
            finishMewAt = .infinity
            out.sounds.append(.mew)
        }
        for i in conf.indices {
            conf[i].vy += 65 * dt
            conf[i].x += conf[i].vx * dt
            conf[i].y += conf[i].vy * dt
            conf[i].life -= dt
        }
        conf.removeAll { $0.life <= 0 || $0.y >= 47 }
        for i in zs.indices {
            zs[i].y -= 3.5 * dt
            zs[i].life -= dt
        }
        zs.removeAll { $0.life <= 0 }
        for i in miniHearts.indices {
            miniHearts[i].y += miniHearts[i].vy * dt
            miniHearts[i].life -= dt
        }
        miniHearts.removeAll { $0.life <= 0 }

        // flying heart progression. The prototype draws the mini heart at its
        // target on the landing frame and the tally only grows on the NEXT frame
        // (the tally is painted before the flyHeart block increments) —
        // replicated via a deferred increment, so the count ticks as the pop
        // flash starts.
        if pendingHeartLand {
            pendingHeartLand = false
            hearts += 1
        }
        var flyHeartPos: Vec2?
        if let fh = flyHeart, t >= fh.t0 {
            let k = clamp((t - fh.t0) / 900, 0, 1)
            let ex = lerp(fh.x, 4, k)
            let ey = lerp(fh.y, 4, k) - sin(k * .pi) * 7  // the ♥×n tally glyph, top-left
            flyHeartPos = Vec2(ex, ey)
            if k >= 1 {
                flyHeart = nil
                pendingHeartLand = true
                heartPopT = t
                out.sounds.append(.blip)
                out.events.append(.heartLanded)
            }
        }

        // progress segments + pop tracking
        let frac = mode == .idle ? 1 : clamp(remainingMs / durationMs, 0, 1)
        let segs = Int((frac * 20).rounded(.up))
        if segs < prevSegs && running {
            segPopT = t
            segPopI = segs
        }
        prevSegs = segs

        // ---- flags for the renderer ----
        var f = FrameFlags()
        f.tMs = t
        f.reduceMotion = rm
        f.running = running
        f.panic = panic
        f.wiggle = wiggle
        f.zoomies = zoomies
        f.bored = bored
        f.purring = purring
        f.happy = happy
        f.stretching = stretching
        f.sleepingNow = sleepingNow
        f.blinking = blinking
        f.landing = landing
        f.walking = walking
        f.airborne = airborne
        f.worried = freeFlight || (dragging && speed > Physics.worriedSpeed)
        f.noticing = t - noticeT < config.noticeMs
        f.speed = speed
        f.lean = walking ? (vel.x > 0 ? 1 : -1) : 0
        f.squashing = landing || scale < 0.92
        f.loaf = (bored || (mode == .done && t - doneT >= 3200)) && !f.squashing
        f.crouch = panic && !airborne
        // Native adaptation (mission §6): Reduce Motion scales breath amplitude
        // ×0.35 — the prototype doesn't, but the mission doc explicitly asks for
        // it. After integer rounding this stills the ±1 px bob entirely; the glow
        // still breathes. Confirmed as a deliberate deviation in review.
        let breathAmp = (panic ? config.panicBounceAmp : config.normalBounceAmp) * (rm ? 0.35 : 1)
        f.bounce = (sleepingNow || f.loaf) ? 0 : jsRound(sin(phase) * breathAmp)
        f.lift = jsRound(hopY)
        f.wig = wiggle && !rm ? (Int(floor(t / 80)) % 2 == 1 ? 1 : -1) : 0
        f.eox = Int(clamp(Double(jsRound(gaze.x / 2.4)), -1, 1))
        f.eoy = dragging ? 1 : Int(clamp(Double(jsRound(gaze.y / 3)), -1, 1))
        let squashPair = Physics.squash(vel: vel, reduceMotion: rm)
        f.sxc = squashPair.sx
        f.syc = squashPair.sy
        let gb = 0.5 + 0.5 * sin(phase)
        f.glowOpacity = (0.35 + 0.3 * gb) * (sleepingNow ? 0.45 : 1)
        f.canvasOpacity = sleepingNow ? 0.88 : 1
        f.labelVisible = (mode == .idle || mode == .paused || hovered ||
                          (running && remainingMs <= 61000)) && mode != .done
        f.segs = segs
        f.flyHeartPos = flyHeartPos
        flags = f

        return out
    }

    private func wanderFidget() {
        let dir: Double = rng.next() < 0.5 ? -1 : 1
        home.x = clamp(home.x + dir * (50 + rng.next() * 45),
                       screen.minX + Physics.homeSideMargin, screen.maxX - Physics.homeSideMargin)
    }

    /// True while anything demands 60 fps (see the cadence policy in §4 of the
    /// spec). Zs are deliberately excluded — they only exist while sleeping, and
    /// the 12 fps sleep tier takes precedence (they drift fine at 12 fps).
    public var wantsHighCadence: Bool {
        dragging || freeFlight || hopY != 0 || mode == .done || flags.panic ||
        !conf.isEmpty || !miniHearts.isEmpty || flyHeart != nil
    }
}
