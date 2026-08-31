import Foundation
import TimiKit

/// UserDefaults-backed settings. The whole Codable struct is stored under one key;
/// every mutation persists immediately.
final class SettingsStore {
    private static let key = "timi.settings.v1"
    private let defaults: UserDefaults

    private(set) var settings: AppSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
