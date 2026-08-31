import Foundation

public enum CharacterID: String, Codable, CaseIterable, Sendable {
    case pip, mochi
}

/// Sounds the engine and controller can request. Concrete synth recipes live in the
/// app's ChipSynth; the Kit only names them (with their parameters).
public enum PalSound: Equatable, Sendable {
    case tick(volume: Double, pitch: Double)
    case bleep2(Double, Double)
    case buzz
    case fanfare(volume: Double, pipTopNote: Bool)
    case boing(Double)
    case thud
    case blip
    case sleepy
    case wake
    case pat
    case meow
    case mew
    case trill
    case mrrp
    case purr
    case hiss(Double)
}

/// Timer-driven moments that map to character-specific sounds.
public enum TimerSoundMoment: Sendable {
    case start, half, quarter, minute, pause, resume, abandon
}

/// Per-character constants. Everything here is lifted verbatim from the two files;
/// behavior code branches on `id` for the bespoke parts (ahoge vs. tail, shake vs.
/// wiggle, celebrate hops vs. pounce/zoomies/loaf).
public struct CharacterConfig: Sendable {
    public let id: CharacterID
    public let name: String
    public let palette: Palette
    /// Glow gradient tint: Pip uses its primary mint; Mochi a warmer amber
    /// (`rgba(255,210,140,.14)`), not its cream primary.
    public let glowTint: RGBA
    public let banner: String
    public let breathDonePeriod: Double     // 0.9 pip / 1.0 mochi
    public let panicBreathPeriod: Double    // 0.45 / 0.5
    public let normalBounceAmp: Double      // 1.2 / 1.1
    public let panicBounceAmp: Double       // 1.0 / 0.6
    public let flyHeartDelayMs: Double      // 900 / 1100
    public let happyMs: Double              // 9000 / 10000
    public let autoResetMs: Double          // 6000 / 6400
    public let finishHopImpulse: Double     // −46 / −50
    public let noticeMs: Double             // 250 / 600
    /// Pip's file schedules blinks even in panic; Mochi's excludes panic.
    public let schedulesBlinkInPanic: Bool
    /// Pip celebrates with a hop loop; Mochi pounces → zoomies → loaf instead.
    public let celebrateHopLoop: Bool

    /// Sound(s) for a timer moment. (Pip: chip bleeps; Mochi: cat voice.)
    public func sounds(for moment: TimerSoundMoment) -> [PalSound] {
        switch id {
        case .pip:
            switch moment {
            case .start: return [.bleep2(659.25, 987.77)]
            case .half: return [.bleep2(659.25, 783.99)]
            case .quarter: return [.bleep2(783.99, 987.77)]
            case .minute: return [.buzz]
            case .pause: return [.sleepy]
            case .resume: return [.wake]
            case .abandon: return []
            }
        case .mochi:
            switch moment {
            case .start: return [.meow]
            case .half: return [.trill]
            case .quarter: return [.trill]
            case .minute: return [.buzz]
            case .pause: return [.sleepy]
            case .resume: return [.mew]
            case .abandon: return [.mrrp]
            }
        }
    }

    /// Sound played on releasing a pat. Pip chirps; Mochi stays silent here — its
    /// purr loop starts from `patT` inside the engine.
    public var patSound: PalSound? {
        id == .pip ? .pat : nil
    }

    public static let pip = CharacterConfig(
        id: .pip, name: "Pip", palette: .pip, glowTint: RGBA(hex: 0xBAF2D0), banner: "YAY",
        breathDonePeriod: 0.9, panicBreathPeriod: 0.45,
        normalBounceAmp: 1.2, panicBounceAmp: 1.0,
        flyHeartDelayMs: 900, happyMs: 9000, autoResetMs: 6000,
        finishHopImpulse: -46, noticeMs: 250,
        schedulesBlinkInPanic: true, celebrateHopLoop: true)

    public static let mochi = CharacterConfig(
        id: .mochi, name: "Mochi", palette: .mochi, glowTint: RGBA(hex: 0xFFD28C), banner: "NYA!",
        breathDonePeriod: 1.0, panicBreathPeriod: 0.5,
        normalBounceAmp: 1.1, panicBounceAmp: 0.6,
        flyHeartDelayMs: 1100, happyMs: 10000, autoResetMs: 6400,
        finishHopImpulse: -50, noticeMs: 600,
        schedulesBlinkInPanic: false, celebrateHopLoop: false)

    public static func config(for id: CharacterID) -> CharacterConfig {
        id == .pip ? .pip : .mochi
    }
}
