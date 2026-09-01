import Foundation
import Combine
import TimiKit

/// UserDefaults-backed settings. The whole Codable struct is stored under one key;
/// every mutation persists immediately and publishes to SwiftUI observers.
final class SettingsStore: ObservableObject {
    private static let key = "timi.settings.v1"
    private let defaults: UserDefaults

    @Published private(set) var settings: AppSettings

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
