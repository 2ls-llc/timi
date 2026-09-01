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
    /// global AppKit coordinates. Optional so older stored settings still decode.
    public var lastPositionPerScreen: [String: [Double]]? = nil
    /// 1 px dark sticker outline for legibility on light desktops. Optional so
    /// older stored settings still decode; read via `outlineOn` (default true).
    public var highContrastOutline: Bool? = nil

    public var outlineOn: Bool { highContrastOutline ?? true }
    /// Set once the first-run hint has been shown and dismissed.
    public var hasSeenHint: Bool? = nil

    public init() {}
}
