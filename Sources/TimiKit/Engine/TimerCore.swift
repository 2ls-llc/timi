import Foundation

public enum TimerMode: String, Sendable {
    case idle, running, paused, done
}

public enum Milestone: String, CaseIterable, Sendable {
    case half, quarter, minute
}

public enum TimerEvent: Equatable, Sendable {
    case tick(volume: Double, pitch: Double)
    case milestone(Milestone)
    case finished(quiet: Bool)
}

public enum AdvanceContext: Sendable {
    case normal
    /// Advancing after system sleep — a deadline that passed during sleep
    /// finishes quietly (fanfare at 50%).
    case wake
}

/// Deterministic timer. All methods take an explicit wall-clock `now` — no internal
/// clocks, no frame-loop dependency. `endAt` is absolute so sleep/wake and clock
/// jumps are handled by construction.
public final class TimerCore {
    public static let minDurationMs: Double = 60_000
    public static let maxDurationMs: Double = 90 * 60_000
    public static var presetsMs: [Double] { DurationPreset.all.map(\.ms) }
    public static let defaultDurationMs: Double = 1_500_000

    public private(set) var mode: TimerMode = .idle
    public private(set) var durationMs: Double = TimerCore.defaultDurationMs
    public private(set) var endAt: Date?
    /// Authoritative while paused; mirrors duration while idle; 0 when done.
    private var pausedRemainingMs: Double = TimerCore.defaultDurationMs
    private var fired: Set<Milestone> = []
    private var lastSec: Int?

    public init() {}

    // MARK: - Queries

    /// Continuous remaining ms (clamped ≥ 0 for display; running mode derives from endAt).
    public func remainingMs(now: Date) -> Double {
        switch mode {
        case .idle: return durationMs
        case .paused: return pausedRemainingMs
        case .done: return 0
        case .running:
            guard let endAt else { return 0 }
            return max(0, endAt.timeIntervalSince(now) * 1000)
        }
    }

    public func elapsedMs(now: Date) -> Double {
        durationMs - remainingMs(now: now)
    }

    // MARK: - Transitions

    /// Idle only. Used by the preset chips — the 30 s preset is allowed below the
    /// scroll wheel's 1-minute floor, so only the upper bound applies here.
    public func setDuration(ms: Double) {
        guard mode == .idle, ms > 0 else { return }
        durationMs = min(ms, Self.maxDurationMs)
        pausedRemainingMs = durationMs
    }

    /// Scroll wheel: ±1 minute per notch, clamped 1–90 min. Returns true if changed.
    public func nudgeDuration(byMinutes delta: Int) -> Bool {
        guard mode == .idle else { return false }
        let next = clamp(durationMs + Double(delta) * 60_000, Self.minDurationMs, Self.maxDurationMs)
        guard next != durationMs else { return false }
        durationMs = next
        pausedRemainingMs = next
        return true
    }

    public func start(now: Date) {
        guard mode == .idle else { return }
        endAt = now.addingTimeInterval(durationMs / 1000)
        fired = []
        lastSec = Int((durationMs / 1000).rounded(.up))
        mode = .running
    }

    public func pause(now: Date) {
        guard mode == .running, let endAt else { return }
        pausedRemainingMs = max(0, endAt.timeIntervalSince(now) * 1000)
        mode = .paused
    }

    public func resume(now: Date) {
        guard mode == .paused else { return }
        endAt = now.addingTimeInterval(pausedRemainingMs / 1000)
        mode = .running
    }

    /// Returns true when this reset abandons a session in progress
    /// (> 15 s elapsed while running or paused — the guilt-trip rule).
    @discardableResult
    public func reset(now: Date) -> Bool {
        var abandoned = false
        if mode == .running || mode == .paused {
            let rem = remainingMs(now: now)
            abandoned = durationMs - rem > 15_000
        }
        pausedRemainingMs = durationMs
        fired = []
        lastSec = nil
        endAt = nil
        mode = .idle
        return abandoned
    }

    /// Tap semantics: idle→start, running→pause, paused→resume, done→reset.
    /// Returns what happened so the caller can play the right sound.
    public enum TapAction { case started, paused, resumed, reset }
    public func tap(now: Date) -> TapAction {
        switch mode {
        case .idle: start(now: now); return .started
        case .running: pause(now: now); return .paused
        case .paused: resume(now: now); return .resumed
        case .done: reset(now: now); return .reset
        }
    }

    // MARK: - Advancing

    /// Catch up to `now`, emitting at most one tick, any newly crossed milestones,
    /// and finish. Idempotent — safe to call from both the second-boundary timer and
    /// the frame loop.
    public func advance(now: Date, context: AdvanceContext = .normal) -> [TimerEvent] {
        guard mode == .running, let endAt else { return [] }
        let rem = endAt.timeIntervalSince(now) * 1000
        if rem <= 0 {
            mode = .done
            pausedRemainingMs = 0
            return [.finished(quiet: context == .wake)]
        }
        var events: [TimerEvent] = []
        let sec = Int((rem / 1000).rounded(.up))
        if sec != lastSec {
            lastSec = sec
            let curve = Self.tickCurve(remainingSec: rem / 1000, elapsedSec: (durationMs - rem) / 1000)
            events.append(.tick(volume: curve.volume, pitch: curve.pitch))
        }
        if durationMs >= 30_000 && rem <= durationMs * 0.5 && !fired.contains(.half) {
            fired.insert(.half)
            events.append(.milestone(.half))
        }
        if durationMs >= 240_000 && rem <= durationMs * 0.25 && !fired.contains(.quarter) {
            fired.insert(.quarter)
            events.append(.milestone(.quarter))
        }
        if durationMs > 150_000 && rem <= 60_000 && !fired.contains(.minute) {
            fired.insert(.minute)
            events.append(.milestone(.minute))
        }
        return events
    }

    /// The tick volume/pitch curve (§5): loud for the first 20 s, fades out by 45 s,
    /// silent through flow, fades back in over the first 5 s of the final minute,
    /// full volume with rising pitch in the last 10 s.
    public static func tickCurve(remainingSec rem: Double, elapsedSec el: Double) -> (volume: Double, pitch: Double) {
        var vol = 0.0, pitch = 1.0
        if rem <= 10.5 {
            vol = 1
            pitch = 1 + (10 - rem) * 0.03
        } else if rem <= 60 {
            vol = clamp((60 - rem) / 5, 0, 1)
        } else if el < 20 {
            vol = 1
        } else if el < 45 {
            vol = 1 - (el - 20) / 25
        }
        return (vol, pitch)
    }

    /// Testing/debug hook: shift the running deadline (a negative delta pulls the
    /// finish closer — simulates the wall clock jumping forward during sleep).
    public func shiftEndAt(byMs delta: Double) {
        guard let endAt else { return }
        self.endAt = endAt.addingTimeInterval(delta / 1000)
    }

    /// The next wall-clock instant `advance` would emit something (tick, milestone,
    /// or finish), for scheduling a DispatchSourceTimer. Nil unless running.
    public func nextDeadline(now: Date) -> Date? {
        guard mode == .running, let endAt else { return nil }
        let rem = endAt.timeIntervalSince(now) * 1000
        guard rem > 0 else { return now }
        // Thresholds expressed as "remaining ms at fire time"; soonest = largest below rem.
        var thresholds: [Double] = [max(0, ((rem / 1000).rounded(.up) - 1) * 1000)]
        if durationMs >= 30_000 && !fired.contains(.half) { thresholds.append(durationMs * 0.5) }
        if durationMs >= 240_000 && !fired.contains(.quarter) { thresholds.append(durationMs * 0.25) }
        if durationMs > 150_000 && !fired.contains(.minute) { thresholds.append(60_000) }
        let target = thresholds.filter { $0 < rem }.max() ?? 0
        return endAt.addingTimeInterval(-target / 1000)
    }
}
