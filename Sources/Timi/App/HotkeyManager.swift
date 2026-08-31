import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Start/Pause toggle — default ⌃⌥Space, user-configurable in Settings.
    static let togglePal = Self("togglePal", default: .init(.space, modifiers: [.control, .option]))
}

final class HotkeyManager {
    init(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePal) {
            onToggle()
        }
    }
}
