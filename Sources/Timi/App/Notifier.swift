import Foundation
import UserNotifications
import TimiKit

/// Completion notifications. UNUserNotificationCenter requires a real bundle,
/// so everything is guarded — a bare `swift run` binary skips notifications.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var available: Bool { Bundle.main.bundleIdentifier != nil }
    private var requested = false

    override init() {
        super.init()
        if available {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    /// Called lazily the first time a timer starts.
    func requestPermissionIfNeeded(enabled: Bool) {
        guard available, enabled, !requested else { return }
        requested = true
        // Alert only — no notification ever carries a sound (the fanfare is the sound).
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
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

    /// Current authorization, delivered on the main thread (for the Settings pane).
    func authorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        guard available else { completion(.notDetermined); return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    /// Banners are normally suppressed while the posting app is frontmost — which
    /// Timi briefly is whenever Settings is open. Always present.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                    @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
