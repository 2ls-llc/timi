import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Start/Pause toggle — default ⌃⌥T, user-configurable in Settings.
    /// (⌃⌥Space is macOS's own "select next input source" shortcut, so it was
    /// swallowed for anyone with two keyboard layouts enabled.)
    static let togglePal = Self("togglePal", default: .init(.t, modifiers: [.control, .option]))
}

final class HotkeyManager {
    init(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePal) {
            onToggle()
        }
    }
}
