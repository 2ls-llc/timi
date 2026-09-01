import XCTest
@testable import TimiKit

final class PhysicsTests: XCTestCase {
    private let bounds = Rect(x: 0, y: 0, w: 1440, h: 900)

    // MARK: - Position spring

    func testHomeSpringConvergesAndSettles() {
        var pos = Vec2(100, 100), vel = Vec2.zero
        let target = Vec2(700, 500)
        for _ in 0..<600 { // 10 s at 60 fps
            Physics.springStep(pos: &pos, vel: &vel, target: target,
                               stiffness: Physics.homeStiffness,
                               damping: Physics.homeDamping, dt: 1.0 / 60)
        }
        XCTAssertEqual(pos.x, target.x, accuracy: 1)
        XCTAssertEqual(pos.y, target.y, accuracy: 1)
        XCTAssertLessThan(hypot(vel.x, vel.y), 5)
    }

    func testDragSpringIsStifferThanHome() {
        func distanceAfterHalfSecond(stiffness: Double, damping: Double) -> Double {
            var pos = Vec2(0, 0), vel = Vec2.zero
            for _ in 0..<30 {
                Physics.springStep(pos: &pos, vel: &vel, target: Vec2(300, 0),
                                   stiffness: stiffness, damping: damping, dt: 1.0 / 60)
            }
            return abs(300 - pos.x)
        }
        let homeGap = distanceAfterHalfSecond(stiffness: 90, damping: 11)
        let dragGap = distanceAfterHalfSecond(stiffness: 380, damping: 26)
        XCTAssertLessThan(dragGap, homeGap, "drag spring must track the cursor tighter")
        XCTAssertLessThan(dragGap, 30)
    }

    // MARK: - Free flight

    func testFlightDragSlowsExponentially() {
        var pos = Vec2(720, 450), vel = Vec2(1000, 0)
        for _ in 0..<60 {
            _ = Physics.flightStep(pos: &pos, vel: &vel, bounds: bounds, dt: 1.0 / 60)
        }
        // exp(-1.5·1s) ≈ 0.223 — a mid-screen fling never even reaches the wall.
        XCTAssertEqual(vel.x, 1000 * exp(-1.5), accuracy: 2)
        XCTAssertEqual(pos.x, 720 + 1000 * (1 - exp(-1.5)) / 1.5, accuracy: 10)
    }

    func testBounceReflectsWithRestitution() {
        // Aim straight at the left wall from just inside it.
        var pos = Vec2(Physics.bounceHalfSize + 1, 450), vel = Vec2(-1000, 0)
        let imp = Physics.flightStep(pos: &pos, vel: &vel, bounds: bounds, dt: 1.0 / 60)
        XCTAssertNotNil(imp)
        XCTAssertEqual(pos.x, Physics.bounceHalfSize, accuracy: 1e-9)
        XCTAssertGreaterThan(vel.x, 0, "must reflect off the wall")
        // one step of drag then ×0.72
        let expectedSpeed = 1000 * exp(-1.5 / 60) * 0.72
        XCTAssertEqual(vel.x, expectedSpeed, accuracy: 1)
        // impact strength = clamp(speed/1400, 0.2, 1)
        XCTAssertEqual(imp!, clamp(expectedSpeed / 1400, 0.2, 1), accuracy: 1e-9)
    }

    func testImpactStrengthClamps() {
        var pos = Vec2(Physics.bounceHalfSize - 50, 450), vel = Vec2(-100, 0)
        let softImp = Physics.flightStep(pos: &pos, vel: &vel, bounds: bounds, dt: 1.0 / 60)
        XCTAssertEqual(softImp, 0.2, "slow impacts clamp up to 0.2")

        var pos2 = Vec2(Physics.bounceHalfSize + 1, 450), vel2 = Vec2(-2600, 0)
        let hardImp = Physics.flightStep(pos: &pos2, vel: &vel2, bounds: bounds, dt: 1.0 / 60)
        XCTAssertNotNil(hardImp)
        XCTAssertEqual(hardImp!, 1.0, accuracy: 1e-9, "2600·0.72 / 1400 > 1 clamps to 1")
    }

    func testCornerHitReflectsBothAxes() {
        var pos = Vec2(Physics.bounceHalfSize + 1, Physics.bounceHalfSize + 1)
        var vel = Vec2(-800, -800)
        let imp = Physics.flightStep(pos: &pos, vel: &vel, bounds: bounds, dt: 1.0 / 60)
        XCTAssertNotNil(imp)
        XCTAssertGreaterThan(vel.x, 0)
        XCTAssertGreaterThan(vel.y, 0)
    }

    // MARK: - Hop

    func testStartHopRisesAndReturnsToGround() {
        var hopY = 0.0, hopV = -30.0
        var minY = 0.0
        var frames = 0
        while frames < 120 {
            frames += 1
            _ = Physics.hopStep(hopY: &hopY, hopV: &hopV, dt: 1.0 / 60)
            minY = min(minY, hopY)
            if hopY == 0 && hopV == 0 { break }
        }
        // v²/2g = 900/520 ≈ 1.73 px apex; airtime ≈ 2·30/260 ≈ 0.23 s ≈ 14 frames
        XCTAssertLessThan(minY, -1.2)
        XCTAssertEqual(frames, 14, accuracy: 3)
        XCTAssertEqual(hopY, 0)
        XCTAssertEqual(hopV, 0)
    }

    /// Prototype subtlety: the thud needs prevHopY < −0.6 on the landing frame.
    /// At 60 fps a −30 hop descends ~0.5 px/frame, so small hops land silently;
    /// the −46/−50 finish hops (~0.8 px/frame) are what actually thud.
    func testSmallHopLandsQuietlyAt60fps() {
        var hopY = 0.0, hopV = -30.0
        var landedHard = false
        for _ in 0..<120 {
            if Physics.hopStep(hopY: &hopY, hopV: &hopV, dt: 1.0 / 60) {
                landedHard = true
            }
            if hopY == 0 && hopV == 0 { break }
        }
        XCTAssertFalse(landedHard)
    }

    func testFinishHopCanLandHard() {
        // -46 at 30 fps: ~1.5 px/frame descent → prev < −0.6 on the landing frame.
        var hopY = 0.0, hopV = -46.0
        var landedHard = false
        for _ in 0..<120 {
            if Physics.hopStep(hopY: &hopY, hopV: &hopV, dt: 1.0 / 30) {
                landedHard = true
            }
            if hopY == 0 && hopV == 0 { break }
        }
        XCTAssertTrue(landedHard)
    }

    // MARK: - Squash

    func testSquashDominantAxis() {
        let horizontal = Physics.squash(vel: Vec2(300, 10), reduceMotion: false)
        XCTAssertEqual(horizontal.sx, 1 + 300.0 * 0.0004 * 1.0006, accuracy: 0.01)
        XCTAssertGreaterThan(horizontal.sx, 1)
        XCTAssertLessThan(horizontal.sy, 1)
        XCTAssertEqual(horizontal.sy, 1 - (horizontal.sx - 1) * 0.6, accuracy: 1e-6)

        let vertical = Physics.squash(vel: Vec2(10, -300), reduceMotion: false)
        XCTAssertGreaterThan(vertical.sy, 1)
        XCTAssertLessThan(vertical.sx, 1)
    }

    func testSquashCapsAtSixteenPercent() {
        let fast = Physics.squash(vel: Vec2(5000, 0), reduceMotion: false)
        XCTAssertEqual(fast.sx, 1.16, accuracy: 1e-9)
        XCTAssertEqual(fast.sy, 1 - 0.16 * 0.6, accuracy: 1e-9)
    }

    func testSquashReduceMotionScales() {
        let rm = Physics.squash(vel: Vec2(5000, 0), reduceMotion: true)
        XCTAssertEqual(rm.sx, 1 + 0.16 * 0.3, accuracy: 1e-9)
    }

    func testClampHomeMargins() {
        let clamped = Physics.clampHome(Vec2(-50, 2000), in: bounds)
        XCTAssertEqual(clamped.x, 125, "sides keep the chip row on-screen")
        XCTAssertEqual(clamped.y, 810, "top keeps the prototype's 90 pt")
        let low = Physics.clampHome(Vec2(700, -10), in: bounds)
        XCTAssertEqual(low.y, 120, "bottom keeps the strip above the Dock")
    }

    // MARK: - Engine pointer semantics (tap / pat / fling thresholds)

    private func makeEngine() -> PalEngine {
        let e = PalEngine(config: .timi, seed: 42, tMs: 0, home: Vec2(720, 450), hearts: 0)
        // Prime `screen` via one step.
        _ = e.step(EngineInput(
            tMs: 0, dt: 0, mode: .idle, durationMs: 1_500_000, remainingMs: 1_500_000,
            cursor: Vec2(0, 0), cursorMoved: false, hovered: false,
            reduceMotion: false, screen: bounds))
        return e
    }

    func testQuickStillReleaseIsTap() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        e.pointerDragged(to: Vec2(722, 451), tMs: 1100) // < 6 px accumulated
        XCTAssertEqual(e.pointerUp(tMs: 1200), .tap)
        XCTAssertFalse(e.dragging)
    }

    func testLongStillHoldIsPat() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        XCTAssertEqual(e.pointerUp(tMs: 1450), .pat)
        XCTAssertEqual(e.miniHearts.count, 1, "pat spawns a floating mini heart")
        XCTAssertEqual(e.patT, 1450)
    }

    func testHoldBoundaryIs450ms() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        XCTAssertEqual(e.pointerUp(tMs: 1449.9), .tap)
        let e2 = makeEngine()
        e2.pointerDown(at: Vec2(720, 450), tMs: 1000)
        XCTAssertEqual(e2.pointerUp(tMs: 1450.0), .pat)
    }

    func testMovedReleaseBelowThrowSpeedSettlesHome() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        e.pointerDragged(to: Vec2(760, 450), tMs: 1100)
        e.pos = Vec2(30, 450) // dropped near the left edge
        e.vel = Vec2(100, 0)
        XCTAssertEqual(e.pointerUp(tMs: 1200), .settled)
        XCTAssertEqual(e.home.x, Physics.homeSideMargin, "home clamps inside the screen")
        XCTAssertFalse(e.freeFlight)
    }

    func testFastReleaseFlings() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        e.pointerDragged(to: Vec2(760, 450), tMs: 1050)
        e.vel = Vec2(700, 0)
        XCTAssertEqual(e.pointerUp(tMs: 1100), .flung)
        XCTAssertTrue(e.freeFlight)
        XCTAssertEqual(e.vel.x, 700, "under the cap, velocity is unchanged")
    }

    func testThrowSpeedCapAt2600() {
        let e = makeEngine()
        e.pointerDown(at: Vec2(720, 450), tMs: 1000)
        e.pointerDragged(to: Vec2(760, 450), tMs: 1050)
        e.vel = Vec2(4000, 3000) // speed 5000
        XCTAssertEqual(e.pointerUp(tMs: 1100), .flung)
        XCTAssertEqual(hypot(e.vel.x, e.vel.y), 2600, accuracy: 1e-6)
    }

    func testTapDuringHopStillCounts() {
        let e = makeEngine()
        e.hopV = -30
        var input = EngineInput(
            tMs: 100, dt: 1.0 / 60, mode: .idle, durationMs: 1_500_000,
            remainingMs: 1_500_000, cursor: Vec2(0, 0), cursorMoved: false,
            hovered: false, reduceMotion: false, screen: bounds)
        _ = e.step(input)
        input.tMs = 116
        _ = e.step(input)
        XCTAssertLessThan(e.hopY, 0, "airborne mid-hop")
        e.pointerDown(at: Vec2(720, 450), tMs: 120)
        XCTAssertEqual(e.pointerUp(tMs: 200), .tap)
    }

    func testFlightEndsBelowExitSpeedAndClampsHome() {
        let e = makeEngine()
        e.pos = Vec2(100, 100)
        e.vel = Vec2(139, 0)
        e.freeFlight = true
        _ = e.step(EngineInput(
            tMs: 10, dt: 1.0 / 60, mode: .idle, durationMs: 1_500_000,
            remainingMs: 1_500_000, cursor: Vec2(0, 0), cursorMoved: false,
            hovered: false, reduceMotion: false, screen: bounds))
        XCTAssertFalse(e.freeFlight)
        XCTAssertEqual(e.home.x, Physics.homeSideMargin, accuracy: 3, "clamped in from x≈102")
        XCTAssertEqual(e.home.y, Physics.homeBottomMargin, accuracy: 3, "clamped up from y=100")
    }

    func testWallImpactEmitsBoingAndSquash() {
        let e = makeEngine()
        e.pos = Vec2(Physics.bounceHalfSize + 1, 450)
        e.vel = Vec2(-1400, 0)
        e.freeFlight = true
        let result = e.step(EngineInput(
            tMs: 10, dt: 1.0 / 60, mode: .idle, durationMs: 1_500_000,
            remainingMs: 1_500_000, cursor: Vec2(0, 0), cursorMoved: false,
            hovered: false, reduceMotion: false, screen: bounds))
        let boings = result.sounds.filter { if case .boing = $0 { return true }; return false }
        XCTAssertEqual(boings.count, 1)
        XCTAssertLessThan(e.scale, 0.92, "impact squash brings scale down")
        XCTAssertEqual(e.lastInteract, 10, "wall impacts count as interaction")
    }

    func testHissOnHardImpactOnly() {
        func impact(vel: Double) -> [PalSound] {
            let e = PalEngine(config: .timi, seed: 1, tMs: 0, home: Vec2(720, 450), hearts: 0)
            e.pos = Vec2(Physics.bounceHalfSize + 1, 450)
            e.vel = Vec2(-vel, 0)
            e.freeFlight = true
            return e.step(EngineInput(
                tMs: 10, dt: 1.0 / 60, mode: .idle, durationMs: 1_500_000,
                remainingMs: 1_500_000, cursor: Vec2(0, 0), cursorMoved: false,
                hovered: false, reduceMotion: false, screen: bounds)).sounds
        }
        let hard = impact(vel: 1400) // imp ≈ 0.72 > 0.55
        XCTAssertTrue(hard.contains { if case .hiss = $0 { return true }; return false })
        let soft = impact(vel: 600) // imp ≈ 0.31 < 0.55
        XCTAssertFalse(soft.contains { if case .hiss = $0 { return true }; return false })
    }
}
