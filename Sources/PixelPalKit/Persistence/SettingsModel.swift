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
    public var character: CharacterID = .pip
    public var muted: Bool = false
    public var volume: Double = 1.0
    public var showMenuBarClock: Bool = true
    public var interactionMode: InteractionMode = .hover
    public var cabinetFrame: Bool = false
    public var notificationsEnabled: Bool = true
    public var launchAtLogin: Bool = false
    public var palVisible: Bool = true
    public var lastDurationMs: Double = 1_500_000

    public init() {}
}
