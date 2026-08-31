import XCTest
@testable import TimiKit

final class TimerCoreTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func makeRunning(durationMs: Double, startedAt: Date? = nil) -> TimerCore {
        let core = TimerCore()
        core.setDuration(ms: durationMs)
        core.start(now: startedAt ?? t0)
        return core
    }

    // MARK: - Tick volume curve (§5) at every boundary

    func testTickCurveFirstTwentySecondsLoud() {
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 1490, elapsedSec: 10).volume, 1)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 1481, elapsedSec: 19.5).volume, 1)
    }

    func testTickCurveFadesOutBetween20And45() {
        let atTwenty = TimerCore.tickCurve(remainingSec: 1480, elapsedSec: 20)
        XCTAssertEqual(atTwenty.volume, 1.0, accuracy: 1e-9)
        let mid = TimerCore.tickCurve(remainingSec: 1467.5, elapsedSec: 32.5)
        XCTAssertEqual(mid.volume, 0.5, accuracy: 1e-9)
        let nearEnd = TimerCore.tickCurve(remainingSec: 1455.5, elapsedSec: 44.5)
        XCTAssertEqual(nearEnd.volume, 0.02, accuracy: 1e-9)
    }

    func testTickCurveSilentInFlow() {
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 1455, elapsedSec: 45).volume, 0)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 700, elapsedSec: 800).volume, 0)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 61, elapsedSec: 1439).volume, 0)
    }

    func testTickCurveFadesBackInOverFirstFiveSecondsOfFinalMinute() {
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 60, elapsedSec: 1440).volume, 0, accuracy: 1e-9)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 57.5, elapsedSec: 1442.5).volume, 0.5, accuracy: 1e-9)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 55, elapsedSec: 1445).volume, 1, accuracy: 1e-9)
        XCTAssertEqual(TimerCore.tickCurve(remainingSec: 30, elapsedSec: 1470).volume, 1)
    }

    func testTickCurvePanicPitchRamp() {
        let atTen = TimerCore.tickCurve(remainingSec: 10, elapsedSec: 1490)
        XCTAssertEqual(atTen.volume, 1)
        XCTAssertEqual(atTen.pitch, 1.0, accuracy: 1e-9)
        let atFive = TimerCore.tickCurve(remainingSec: 5, elapsedSec: 1495)
        XCTAssertEqual(atFive.pitch, 1.15, accuracy: 1e-9)
        let atOne = TimerCore.tickCurve(remainingSec: 1, elapsedSec: 1499)
        XCTAssertEqual(atOne.pitch, 1.27, accuracy: 1e-9)
        // 10.5 boundary: just above still uses the final-minute fade-in branch
        let above = TimerCore.tickCurve(remainingSec: 10.6, elapsedSec: 1489.4)
        XCTAssertEqual(above.volume, 1, accuracy: 1e-9)
        XCTAssertEqual(above.pitch, 1)
    }

    // MARK: - Milestones fire exactly once

    func testMilestonesFireExactlyOnce() {
        let core = makeRunning(durationMs: 1_500_000) // 25 min
        var milestones: [Milestone] = []
        // Sweep one advance per second across the session.
        for s in stride(from: 1.0, through: 1500.0, by: 1.0) {
            for e in core.advance(now: t0.addingTimeInterval(s)) {
                if case .milestone(let m) = e { milestones.append(m) }
            }
        }
        XCTAssertEqual(milestones.filter { $0 == .half }.count, 1)
        XCTAssertEqual(milestones.filter { $0 == .quarter }.count, 1)
        XCTAssertEqual(milestones.filter { $0 == .minute }.count, 1)
        // Order: half at 12.5 min, quarter at 18.75 min, minute at 24 min
        XCTAssertEqual(milestones, [.half, .quarter, .minute])
    }

    func testMilestonesSurvivePauseResume() {
        let core = makeRunning(durationMs: 300_000) // 5 min: half only (quarter needs ≥ 4 min → fires too)
        var events: [TimerEvent] = []
        events += core.advance(now: t0.addingTimeInterval(151)) // past half (150 s)
        core.pause(now: t0.addingTimeInterval(160))
        core.resume(now: t0.addingTimeInterval(300))
        // Resumed with 140 s left; sweep to the end.
        let resumeBase = t0.addingTimeInterval(300)
        for s in stride(from: 1.0, through: 140.0, by: 1.0) {
            events += core.advance(now: resumeBase.addingTimeInterval(s))
        }
        let halves = events.filter { if case .milestone(.half) = $0 { return true }; return false }
        XCTAssertEqual(halves.count, 1, "half must not re-fire after pause/resume")
    }

    func testShortDurationMilestoneGates() {
        // 30 s: half fires, quarter (needs ≥ 240 s) and minute (needs > 150 s) never.
        let core = makeRunning(durationMs: 30_000)
        var milestones: [Milestone] = []
        for s in stride(from: 1.0, through: 30.0, by: 1.0) {
            for e in core.advance(now: t0.addingTimeInterval(s)) {
                if case .milestone(let m) = e { milestones.append(m) }
            }
        }
        XCTAssertEqual(milestones, [.half])
    }

    func testMinuteGateAt150Seconds() {
        // Exactly 150 s duration: minute must NOT fire (rule is dms > 150000, strict).
        let core = makeRunning(durationMs: 150_000)
        var sawMinute = false
        for s in stride(from: 1.0, through: 150.0, by: 1.0) {
            for e in core.advance(now: t0.addingTimeInterval(s)) {
                if case .milestone(.minute) = e { sawMinute = true }
            }
        }
        XCTAssertFalse(sawMinute)
    }

    // MARK: - One tick per advance, on second boundaries

    func testOneTickPerSecond() {
        let core = makeRunning(durationMs: 60_000)
        var ticks = 0
        for s in stride(from: 0.5, through: 59.5, by: 0.5) {
            for e in core.advance(now: t0.addingTimeInterval(s)) {
                if case .tick = e { ticks += 1 }
            }
        }
        XCTAssertEqual(ticks, 59)
    }

    func testNoTickBurstAfterGap() {
        let core = makeRunning(durationMs: 1_500_000)
        var events = core.advance(now: t0.addingTimeInterval(300)) // 5 min gap
        let ticks = events.filter { if case .tick = $0 { return true }; return false }
        XCTAssertEqual(ticks.count, 1, "a long gap emits at most one tick, not a burst")
        events = core.advance(now: t0.addingTimeInterval(300.1))
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Abandon rule

    func testAbandonRequiresFifteenElapsedSeconds() {
        let core = makeRunning(durationMs: 300_000)
        _ = core.advance(now: t0.addingTimeInterval(10))
        XCTAssertFalse(core.reset(now: t0.addingTimeInterval(10)), "≤ 15 s elapsed — no guilt")

        let core2 = makeRunning(durationMs: 300_000)
        _ = core2.advance(now: t0.addingTimeInterval(16))
        XCTAssertTrue(core2.reset(now: t0.addingTimeInterval(16)))
    }

    func testAbandonFromPausedUsesPausedRemaining() {
        let core = makeRunning(durationMs: 300_000)
        core.pause(now: t0.addingTimeInterval(20))
        // Long wall-clock delay while paused must not change elapsed.
        XCTAssertTrue(core.reset(now: t0.addingTimeInterval(10_000)))

        let core2 = makeRunning(durationMs: 300_000)
        core2.pause(now: t0.addingTimeInterval(5))
        XCTAssertFalse(core2.reset(now: t0.addingTimeInterval(10_000)))
    }

    func testResetFromDoneIsNeverAbandon() {
        let core = makeRunning(durationMs: 60_000)
        _ = core.advance(now: t0.addingTimeInterval(61))
        XCTAssertEqual(core.mode, .done)
        XCTAssertFalse(core.reset(now: t0.addingTimeInterval(62)))
        XCTAssertEqual(core.mode, .idle)
    }

    // MARK: - Wall-clock correctness across a simulated sleep/clock jump

    func testFinishAcrossClockJumpIsQuietOnWake() {
        let core = makeRunning(durationMs: 120_000)
        _ = core.advance(now: t0.addingTimeInterval(30))
        // Mac sleeps; wakes 10 minutes later, long past the deadline.
        let events = core.advance(now: t0.addingTimeInterval(630), context: .wake)
        XCTAssertEqual(events, [.finished(quiet: true)])
        XCTAssertEqual(core.mode, .done)
        XCTAssertEqual(core.remainingMs(now: t0.addingTimeInterval(630)), 0)
    }

    func testRemainingTracksWallClockNotAdvanceCount() {
        let core = makeRunning(durationMs: 90 * 60_000)
        // 90-minute session: remaining at any instant must be exact regardless of
        // how many advances happened (±50 ms requirement is trivially exact here).
        let checkpoints: [Double] = [1, 59.9, 60.1, 1800, 5399, 5399.96]
        for c in checkpoints {
            _ = core.advance(now: t0.addingTimeInterval(c))
            XCTAssertEqual(core.remainingMs(now: t0.addingTimeInterval(c)),
                           90 * 60_000 - c * 1000, accuracy: 0.1)
        }
        let events = core.advance(now: t0.addingTimeInterval(5400.001))
        XCTAssertEqual(events, [.finished(quiet: false)])
    }

    func testWakeBeforeDeadlineKeepsRunning() {
        let core = makeRunning(durationMs: 1_500_000)
        let events = core.advance(now: t0.addingTimeInterval(600), context: .wake)
        XCTAssertEqual(core.mode, .running)
        XCTAssertFalse(events.contains { if case .finished = $0 { return true }; return false })
    }

    // MARK: - Scheduling deadlines

    func testNextDeadlineIsNextSecondBoundary() {
        let core = makeRunning(durationMs: 60_000)
        let d = core.nextDeadline(now: t0.addingTimeInterval(0.25))
        XCTAssertEqual(d!.timeIntervalSince(t0), 1.0, accuracy: 1e-9)
    }

    func testNextDeadlineIncludesMilestoneInstant() {
        let core = makeRunning(durationMs: 300_000)
        // Just before the half milestone (at t+150): deadline is the milestone,
        // not the next full second... they coincide here; use a fractional start.
        let d = core.nextDeadline(now: t0.addingTimeInterval(149.5))
        XCTAssertEqual(d!.timeIntervalSince(t0), 150.0, accuracy: 1e-9)
    }

    // MARK: - Duration clamps (§5.2 / §3.8)

    func testDurationClamps() {
        let core = TimerCore()
        core.setDuration(ms: 30_000)  // the 30 s preset sits below the scroll floor
        XCTAssertEqual(core.durationMs, 30_000)
        XCTAssertTrue(core.nudgeDuration(byMinutes: 100))
        XCTAssertEqual(core.durationMs, 90 * 60_000, "scroll cap at 90 min")
        XCTAssertFalse(core.nudgeDuration(byMinutes: 1), "already at the cap")
        XCTAssertTrue(core.nudgeDuration(byMinutes: -200))
        XCTAssertEqual(core.durationMs, 60_000, "scroll floor at 1 min")
        XCTAssertFalse(core.nudgeDuration(byMinutes: -1))
        core.setDuration(ms: 200 * 60_000)
        XCTAssertEqual(core.durationMs, 90 * 60_000, "setDuration caps too")
        core.start(now: t0)
        XCTAssertFalse(core.nudgeDuration(byMinutes: 1), "scroll only while idle")
        XCTAssertEqual(core.durationMs, 90 * 60_000)
    }

    func testTapCycle() {
        let core = TimerCore()
        XCTAssertEqual(core.tap(now: t0), .started)
        XCTAssertEqual(core.tap(now: t0.addingTimeInterval(1)), .paused)
        XCTAssertEqual(core.tap(now: t0.addingTimeInterval(2)), .resumed)
        _ = core.advance(now: t0.addingTimeInterval(4000))
        XCTAssertEqual(core.mode, .done)
        XCTAssertEqual(core.tap(now: t0.addingTimeInterval(4001)), .reset)
        XCTAssertEqual(core.mode, .idle)
    }
}
