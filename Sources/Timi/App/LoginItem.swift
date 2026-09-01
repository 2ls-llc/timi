import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService — bundle-only, like notifications.
/// The system is the source of truth: read `status` rather than trusting a
/// stored flag, because registration can land in "requires approval".
enum LoginItem {
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool {
        available && SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        available && SMAppService.mainApp.status == .requiresApproval
    }

    static func set(enabled: Bool) {
        guard available else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem: \(error.localizedDescription)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
