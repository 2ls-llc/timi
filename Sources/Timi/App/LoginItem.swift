import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService — bundle-only, like notifications.
enum LoginItem {
    static func set(enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else { return }
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
}
