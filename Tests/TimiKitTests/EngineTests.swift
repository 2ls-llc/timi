import XCTest
@testable import TimiKit

/// Behavior tests for the PalEngine state machine: settle→nap timing, the hunt,
/// finish choreography, bored, moods. Frames are driven manually at fixed dt.
final class EngineTests: XCTestCase {
    private let screen = Rect(x: 0, y: 0, w: 1440, h: 900)

    private func makeEngine(tMs: Double = 0) -> PalEngine {
        PalEngine(config: .timi, seed: 7, tMs: tMs, home: Vec2(720, 450), hearts: 0)
    }

    private func input(t: Double, dt: Double = 1.0 / 30, mode: TimerMode = .idle,
                       durationMs: Double = 1_500_000, remainingMs: Double? = nil,
                       hovered: Bool = false, cursor: Vec2 = Vec2(-2000, -2000),
                       rm: Bool = false) -> EngineInput {
        EngineInput(tMs: t, dt: dt, mode: mode, durationMs: durationMs,
                    remainingMs: remainingMs ?? (mode == .idle ? durationMs : durationMs / 2),
                    cursor: cursor, cursorMoved: false, hovered: hovered,
                    reduceMotion: rm, screen: screen)
    }

    // MARK: - Settle → nap (§5.8)

    /// Rising rate 0.35/s ⇒ settle crosses 0.6 ≈ 2.6 s after the gate opens;
    /// the gate needs 10 s since lastInteract ⇒ the nap begins ≈ 12.6 s in.
    func testSettleTimingIntoNap() {
        let e = makeEngine()
        var sleepAt: Double?
        var sounds: [PalSound] = []
        var t = 0.0
        while t < 20000 {
            t += 1000.0 / 30
            let r = e.step(input(t: t, mode: .running, remainingMs: 1_200_000))
            sounds += r.sounds
            if e.flags.sleepingNow && sleepAt == nil { sleepAt = t }
        }
        XCTAssertNotNil(sleepAt)
        XCTAssertEqual(sleepAt!, 12_620, accuracy: 700)
        XCTAssertTrue(sounds.contains { $0 == .sleepy })
    }

    func testHoverWakesQuicklyWithMewFlashAndStretch() {
        let e = makeEngine()
        var t = 0.0
        while t < 14000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 1_200_000))
        }
        XCTAssertTrue(e.flags.sleepingNow)
        // Hover: falling rate 2.8/s ⇒ 0.6 crossed from 1.0 in ~0.18 s.
        var wakeSounds: [PalSound] = []
        var wakeAt: Double?
        let sleepEnd = t
        while t < sleepEnd + 2000 {
            t += 1000.0 / 30
            let r = e.step(input(t: t, mode: .running, remainingMs: 1_200_000, hovered: true))
            wakeSounds += r.sounds
            if !e.flags.sleepingNow && wakeAt == nil { wakeAt = t }
        }
        XCTAssertNotNil(wakeAt)
        XCTAssertLessThan(wakeAt! - sleepEnd, 500)
        XCTAssertTrue(wakeSounds.contains { $0 == .mew }, "Timi wakes with a mew")
        XCTAssertEqual(e.wakeFlash, wakeAt!, accuracy: 40, "the \"!\" flash starts at wake")
        XCTAssertEqual(e.stretchT, e.wakeFlash, "and she stretches")
    }

    func testNoSettleInFinalSeventyFiveSeconds() {
        let e = makeEngine()
        var t = 0.0
        while t < 30000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 74_000))
        }
        XCTAssertFalse(e.flags.sleepingNow, "rem ≤ 75 s must keep her awake")
        XCTAssertEqual(e.settle, 0, accuracy: 0.01)
    }

    func testWakeUntilBlocksSettle() {
        let e = makeEngine()
        e.onMilestone(.half, tMs: 11_000, reduceMotion: false)  // wakeUntil = 13.6 s
        var t = 11_000.0
        while t < 13_500 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 1_200_000))
        }
        XCTAssertLessThan(e.settle, 0.05)
    }

    func testZsSpawnEverySeventeenHundredMsWhileNapping() {
        let e = makeEngine()
        var t = 0.0
        while t < 14_000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 1_200_000))
        }
        XCTAssertTrue(e.flags.sleepingNow)
        // Life (1.8 s) barely exceeds spacing (1.7 s), so count spawns, not alive.
        var spawns = 0
        var lastCount = e.zs.count
        let start = t
        while t < start + 3500 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 1_200_000))
            if e.zs.count > lastCount { spawns += e.zs.count - lastCount }
            lastCount = e.zs.count
        }
        XCTAssertEqual(spawns, 2, "one Z per 1.7 s")
    }

    // MARK: - The hunt (§5.7)

    func testHuntCrouchWiggleNoBlink() {
        let e = makeEngine()
        var t = 0.0
        while t < 2000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 3000))
        }
        XCTAssertTrue(e.flags.panic)
        XCTAssertTrue(e.flags.wiggle, "rem ≤ 3.5 s wiggles")
        XCTAssertTrue(e.flags.crouch)
        XCTAssertNotEqual(e.flags.wig, 0, "±1 px wiggle offset")
        XCTAssertEqual(e.nextFidget, t + 7000, accuracy: 40, "no fidgets while running")
    }

    func testNoBlinkSchedulingDuringHunt() {
        let e = makeEngine()
        e.nextBlink = 0  // a blink is due immediately
        var t = 0.0
        while t < 3000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, mode: .running, remainingMs: 8000))
        }
        XCTAssertEqual(e.blinkT, -1e9, "locked wide eyes — no blinks in the hunt")
    }

    // MARK: - Finish choreography (§5.11)

    func testFinishConfettiWavesAndFlyHeart() {
        let e = makeEngine()
        e.onFinish(tMs: 1000, reduceMotion: false)
        XCTAssertEqual(e.conf.count, 28, "first wave immediately")
        XCTAssertEqual(e.hopV, -50)
        XCTAssertEqual(e.home.x, screen.midX)
        XCTAssertEqual(e.home.y, screen.midY + 20)

        var t = 1000.0
        var events: [EngineEvent] = []
        var heartLandT: Double?
        var maxConf = e.conf.count
        while t < 4500 {
            t += 1000.0 / 60
            let r = e.step(input(t: t, dt: 1.0 / 60, mode: .done, remainingMs: 0))
            maxConf = max(maxConf, e.conf.count)
            events += r.events
            if heartLandT == nil, events.contains(.heartLanded) { heartLandT = t }
        }
        XCTAssertGreaterThan(maxConf, 28, "second wave (+16) lands at +600 ms")
        XCTAssertEqual(heartLandT!, 1000 + 1100 + 900, accuracy: 50,
                       "flyHeart starts at +1100 ms and flies for 900 ms")
        XCTAssertEqual(e.hearts, 1)
    }

    func testPounceZoomiesLoafAndFinishMew() {
        let e = makeEngine()
        e.pos = Vec2(500, 450)  // left of center → pounce right
        e.onFinish(tMs: 0, reduceMotion: false)
        XCTAssertEqual(e.hopV, -50)
        XCTAssertGreaterThan(e.vel.x, 250, "pounce impulse toward screen center")

        var t = 0.0
        var sawZoomies = false
        var mewAt: Double?
        while t < 4000 {
            t += 1000.0 / 60
            let r = e.step(input(t: t, dt: 1.0 / 60, mode: .done, remainingMs: 0))
            if e.flags.zoomies { sawZoomies = true }
            if mewAt == nil, r.sounds.contains(.mew) { mewAt = t }
        }
        XCTAssertTrue(sawZoomies)
        XCTAssertEqual(mewAt!, 700, accuracy: 40, "finish mew at +700 ms")
        XCTAssertTrue(e.flags.loaf, "loafs from +3.2 s")
        XCTAssertTrue(e.flags.happy)
    }

    func testReduceMotionFinishSkipsConfettiAndPounce() {
        let e = makeEngine()
        e.onFinish(tMs: 0, reduceMotion: true)
        XCTAssertTrue(e.conf.isEmpty)
        XCTAssertEqual(e.hopV, 0)
        XCTAssertEqual(e.vel.x, 0, "no pounce under Reduce Motion")
        var t = 0.0
        while t < 1500 {
            t += 1000.0 / 60
            _ = e.step(input(t: t, dt: 1.0 / 60, mode: .done, remainingMs: 0, rm: true))
        }
        XCTAssertTrue(e.conf.isEmpty, "wave 2 also suppressed")
    }

    // MARK: - Bored & fidgets (§5.10, §6.8)

    func testBoredAfterThirtySecondsIdleLoafsAndStopsFidgeting() {
        let e = makeEngine()
        var t = 0.0
        while t < 31_000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t))
        }
        XCTAssertTrue(e.flags.bored)
        XCTAssertTrue(e.flags.loaf, "Timi loafs when bored")
        let fidgetHome = e.home
        while t < 50_000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t))
        }
        XCTAssertEqual(e.home.x, fidgetHome.x, "no fidgets while bored")
    }

    func testFidgetsHappenWhenIdleAndNotBored() {
        let e = makeEngine()
        var t = 0.0
        var changed = false
        // Keep interaction fresh so bored never triggers; fidgets start at 6 s.
        while t < 26_000 {
            t += 1000.0 / 30
            e.noteInteraction(tMs: t - 5000)
            _ = e.step(input(t: t))
            if e.home.x != 720 || e.hopY != 0 || t < e.glanceUntil ||
                abs(e.vel.x) > 20 || e.stretchT > -1e9 || e.noticeT > -1e9 {
                changed = true
            }
        }
        XCTAssertTrue(changed, "at least one fidget fires in 26 s (8–17 s cadence)")
    }

    func testNoFidgetsUnderReduceMotion() {
        let e = makeEngine()
        var t = 0.0
        while t < 40_000 {
            t += 1000.0 / 30
            e.noteInteraction(tMs: t - 5000)
            _ = e.step(input(t: t, rm: true))
        }
        XCTAssertEqual(e.home.x, 720)
        XCTAssertEqual(e.glanceUntil, 0)
    }

    // MARK: - Moods (§7.5)

    func testAbandonSadWindow() {
        let e = makeEngine()
        e.onAbandon(tMs: 1000)
        XCTAssertEqual(e.sadUntil, 6000)
    }

    func testHappyExcludesHuntAndSleep() {
        let e = makeEngine()
        e.happyUntil = 100_000
        _ = e.step(input(t: 1000, mode: .running, remainingMs: 9000))
        XCTAssertFalse(e.flags.happy, "the hunt overrides happy")
        _ = e.step(input(t: 1033, mode: .running, remainingMs: 200_000))
        XCTAssertTrue(e.flags.happy)
    }

    func testPatStartsPurring() {
        let e = makeEngine()
        _ = e.step(input(t: 100))
        e.pointerDown(at: Vec2(720, 450), tMs: 200)
        XCTAssertEqual(e.pointerUp(tMs: 700), .pat)
        var sounds: [PalSound] = []
        var t = 700.0
        while t < 1500 {
            t += 1000.0 / 30
            sounds += e.step(input(t: t)).sounds
        }
        XCTAssertTrue(sounds.contains(.purr), "purr loop starts from patT")
    }

    // MARK: - Gaze (§7.2)

    func testGazeTracksCursorWithin300pt() {
        let e = makeEngine()
        var t = 0.0
        // Cursor to the right and *below* the pal (AppKit y-up: below = smaller y).
        while t < 2000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, cursor: Vec2(900, 300)))
        }
        XCTAssertEqual(e.flags.eox, 1, "looking right")
        XCTAssertEqual(e.flags.eoy, 1, "looking down (canvas y grows downward)")

        // Far cursor: gaze eases back to center.
        while t < 4000 {
            t += 1000.0 / 30
            _ = e.step(input(t: t, cursor: Vec2(-2000, -2000)))
        }
        XCTAssertEqual(e.flags.eox, 0)
        XCTAssertEqual(e.flags.eoy, 0)
    }
}
