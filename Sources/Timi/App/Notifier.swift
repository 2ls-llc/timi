import Foundation
import UserNotifications
import TimiKit

/// Completion notifications. UNUserNotificationCenter requires a real bundle,
/// so everything is guarded — a bare `swift run` binary skips notifications.
final class Notifier {
    private var available: Bool { Bundle.main.bundleIdentifier != nil }
    private var requested = false

    /// Called lazily the first time a timer starts.
    func requestPermissionIfNeeded(enabled: Bool) {
        guard available, enabled, !requested else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyCompletion(characterName: String, durationMs: Double, enabled: Bool) {
        guard available, enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(characterName) finished a \(DurationFormat.humanized(ms: durationMs)) session 🎉"
        content.body = "Time for a break."
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

}
