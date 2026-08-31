import Foundation

/// There is one pal: Timi the cat. The id survives as an enum (and as the
/// `character` field in session records) so a future character slot stays
/// possible without a data migration.
public enum CharacterID: String, Codable, CaseIterable, Sendable {
    case timi
}

/// Sounds the engine and controller can request. Concrete synth recipes live in
/// the app's ChipSynth; the Kit only names them (with their parameters).
/// All transcribed from the cat prototype's `makeAudio()`.
public enum PalSound: Equatable, Sendable {
    case tick(volume: Double, pitch: Double)
    case buzz
    case fanfare(volume: Double)
    case boing(Double)
    case thud
    case blip
    case sleepy
    case meow
    case mew
    case trill
    case mrrp
    case purr
    case hiss(Double)
}

/// Timer-driven moments that map to Timi's voice.
public enum TimerSoundMoment: Sendable {
    case start, half, quarter, minute, pause, resume, abandon
}

/// Timi's constants, lifted verbatim from mochi-timer.jsx (the cat's prototype,
/// written under her working name).
public struct CharacterConfig: Sendable {
    public let id: CharacterID
    public let name: String
    public let palette: Palette
    /// Glow gradient tint — a warmer amber (`rgba(255,210,140,.14)`), not the
    /// cream primary.
    public let glowTint: RGBA
    public let banner: String
    public let breathDonePeriod: Double     // 1.0
    public let panicBreathPeriod: Double    // 0.5
    public let normalBounceAmp: Double      // 1.1
    public let panicBounceAmp: Double       // 0.6
    public let flyHeartDelayMs: Double      // 1100
    public let happyMs: Double              // 10000
    public let autoResetMs: Double          // 6400
    public let finishHopImpulse: Double     // −50
    public let noticeMs: Double             // 600 (ears perk)

    /// Sound(s) for a timer moment — the cat voice.
    public func sounds(for moment: TimerSoundMoment) -> [PalSound] {
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

    public static let timi = CharacterConfig(
        id: .timi, name: "Timi", palette: .timi, glowTint: RGBA(hex: 0xFFD28C),
        banner: "NYA!",
        breathDonePeriod: 1.0, panicBreathPeriod: 0.5,
        normalBounceAmp: 1.1, panicBounceAmp: 0.6,
        flyHeartDelayMs: 1100, happyMs: 10000, autoResetMs: 6400,
        finishHopImpulse: -50, noticeMs: 600)
}
