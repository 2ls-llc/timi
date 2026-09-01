import Foundation

/// How the floating panel decides to accept mouse input.
public enum InteractionMode: String, Codable, CaseIterable, Sendable {
    /// Default: interactive only while the cursor is over the creature or the strip.
    case hover
    /// Interactive only while ⌥ is held.
    case holdOption
    /// The panel always accepts clicks (margins included — user's explicit choice).
    case always
}

/// Persisted preferences. Decoding is field-tolerant: a missing, malformed, or
/// unknown value falls back to that field's default instead of discarding the
/// whole blob (which would silently wipe every other preference on the next
/// save).
public struct AppSettings: Codable, Equatable, Sendable {
    public var muted: Bool = false
    public var volume: Double = 1.0
    public var showMenuBarClock: Bool = true
    public var interactionMode: InteractionMode = .hover
    public var cabinetFrame: Bool = false
    public var notificationsEnabled: Bool = true
    public var launchAtLogin: Bool = false
    public var palVisible: Bool = true
    public var lastDurationMs: Double = 1_500_000
    /// Last resting position per screen identifier (display UUID) — [x, y] in
    /// global AppKit coordinates.
    public var lastPositionPerScreen: [String: [Double]]? = nil
    /// 1 px dark sticker outline for legibility on light desktops. Read via
    /// `outlineOn` (default true).
    public var highContrastOutline: Bool? = nil
    /// Set once the first-run hint has been shown and dismissed.
    public var hasSeenHint: Bool? = nil
    /// Identifier of the display Timi last rested on, so a relaunch puts her back
    /// on the same monitor (not just the main one).
    public var lastScreenID: String? = nil

    public var outlineOn: Bool { highContrastOutline ?? true }

    public init() {}

    enum CodingKeys: String, CodingKey {
        case muted, volume, showMenuBarClock, interactionMode, cabinetFrame
        case notificationsEnabled, launchAtLogin, palVisible, lastDurationMs
        case lastPositionPerScreen, highContrastOutline, hasSeenHint, lastScreenID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        func field<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? c.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        muted = field(.muted, d.muted)
        volume = min(max(field(.volume, d.volume), 0), 1)
        showMenuBarClock = field(.showMenuBarClock, d.showMenuBarClock)
        interactionMode = InteractionMode(rawValue: field(.interactionMode, "")) ?? d.interactionMode
        cabinetFrame = field(.cabinetFrame, d.cabinetFrame)
        notificationsEnabled = field(.notificationsEnabled, d.notificationsEnabled)
        launchAtLogin = field(.launchAtLogin, d.launchAtLogin)
        palVisible = field(.palVisible, d.palVisible)
        let duration = field(.lastDurationMs, d.lastDurationMs)
        lastDurationMs = duration > 0 ? duration : d.lastDurationMs
        lastPositionPerScreen = field(.lastPositionPerScreen, nil as [String: [Double]]?)
        highContrastOutline = field(.highContrastOutline, nil as Bool?)
        hasSeenHint = field(.hasSeenHint, nil as Bool?)
        lastScreenID = field(.lastScreenID, nil as String?)
    }
}
