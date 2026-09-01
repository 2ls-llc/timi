import Foundation

/// A preset session length with its two spellings: the chip ("25m") and the
/// menu ("25 minutes").
public struct DurationPreset: Equatable, Sendable {
    public let ms: Double
    public let chipLabel: String
    public let menuTitle: String

    public init(ms: Double, chipLabel: String, menuTitle: String) {
        self.ms = ms; self.chipLabel = chipLabel; self.menuTitle = menuTitle
    }

    /// The prototype's presets, in strip order.
    public static let all: [DurationPreset] = [
        DurationPreset(ms: 30_000, chipLabel: "30s", menuTitle: "30 seconds"),
        DurationPreset(ms: 300_000, chipLabel: "5m", menuTitle: "5 minutes"),
        DurationPreset(ms: 900_000, chipLabel: "15m", menuTitle: "15 minutes"),
        DurationPreset(ms: 1_500_000, chipLabel: "25m", menuTitle: "25 minutes"),
    ]

    public static func isPreset(_ ms: Double) -> Bool {
        all.contains { $0.ms == ms }
    }
}

/// Human-facing spellings of a duration.
public enum DurationFormat {
    /// Chip label for a custom duration: "12m", or "1:30" when not whole minutes.
    public static func compact(ms: Double) -> String {
        let totalSeconds = Int((ms / 1000).rounded())
        let m = totalSeconds / 60, s = totalSeconds % 60
        return s == 0 ? "\(m)m" : "\(m):" + (s < 10 ? "0" : "") + "\(s)"
    }

    /// Notification adjective: "25-minute", "30-second", "90-second" — and for
    /// longer non-whole lengths, clock style ("12:30", never "750-second").
    public static func humanized(ms: Double) -> String {
        let seconds = Int((ms / 1000).rounded())
        if seconds % 60 == 0 {
            return "\(seconds / 60)-minute"
        }
        if seconds < 120 {
            return "\(seconds)-second"
        }
        return compact(ms: ms)
    }
}
