import XCTest
import TimiKit
@testable import Timi

/// App-layer persistence: the sessions.json ledger and the UserDefaults-backed
/// settings store, exercised against scratch locations.
final class PersistenceTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimiTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - SessionStore

    func testSessionLedgerRoundTripsThroughDisk() {
        let file = scratch.appendingPathComponent("sessions.json")
        let store = SessionStore(fileURL: file)
        let index = store.beginSession(durationMs: 1_500_000, character: .timi)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertFalse(store.records[0].completed)
        store.completeSession(at: index)

        let reloaded = SessionStore(fileURL: file)
        XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertTrue(reloaded.records[0].completed)
        XCTAssertEqual(reloaded.records[0].durationMs, 1_500_000)
        XCTAssertEqual(reloaded.records[0].character, "timi")
        XCTAssertEqual(reloaded.lifetimeCompleted, 1)
        XCTAssertEqual(reloaded.heartsToday, 1)
    }

    func testAbandonedSessionStaysIncomplete() {
        let store = SessionStore(fileURL: scratch.appendingPathComponent("s.json"))
        store.beginSession(durationMs: 300_000, character: .timi)
        XCTAssertEqual(store.heartsToday, 0)
        XCTAssertEqual(store.lifetimeCompleted, 0)
    }

    func testCompleteSessionIgnoresStaleIndex() {
        let store = SessionStore(fileURL: scratch.appendingPathComponent("s.json"))
        store.completeSession(at: 7)  // nothing there — must not crash
        XCTAssertTrue(store.records.isEmpty)
    }

    func testResetAllEmptiesLedgerAndNotifies() {
        let file = scratch.appendingPathComponent("s.json")
        let store = SessionStore(fileURL: file)
        let index = store.beginSession(durationMs: 60_000, character: .timi)
        var notified = false
        store.onReset = { notified = true }
        store.resetAll()
        XCTAssertTrue(notified, "the app invalidates its in-flight index on reset")
        XCTAssertTrue(store.records.isEmpty)
        store.completeSession(at: index)  // stale index after reset: ignored
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(SessionStore(fileURL: file).records.isEmpty, "reset persisted")
    }

    func testMissingOrCorruptLedgerStartsEmpty() {
        let file = scratch.appendingPathComponent("s.json")
        XCTAssertTrue(SessionStore(fileURL: file).records.isEmpty)
        try? "not json".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertTrue(SessionStore(fileURL: file).records.isEmpty)
    }

    // MARK: - SettingsStore

    private func scratchDefaults() -> UserDefaults {
        let suite = "TimiTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testSettingsPersistAcrossStoreInstances() {
        let defaults = scratchDefaults()
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, AppSettings(), "fresh defaults")
        store.update {
            $0.muted = true
            $0.volume = 0.4
            $0.interactionMode = .holdOption
            $0.lastDurationMs = 720_000
            $0.highContrastOutline = false
            $0.hasSeenHint = true
            $0.lastPositionPerScreen = ["display-1": [100, 200]]
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.settings.muted)
        XCTAssertEqual(reloaded.settings.volume, 0.4)
        XCTAssertEqual(reloaded.settings.interactionMode, .holdOption)
        XCTAssertEqual(reloaded.settings.lastDurationMs, 720_000)
        XCTAssertFalse(reloaded.settings.outlineOn)
        XCTAssertEqual(reloaded.settings.hasSeenHint, true)
        XCTAssertEqual(reloaded.settings.lastPositionPerScreen?["display-1"], [100, 200])
    }

    func testOlderSettingsWithoutNewerKeysStillDecode() throws {
        // A settings blob from before the optional fields existed.
        let legacy: [String: Any] = [
            "muted": false, "volume": 1.0, "showMenuBarClock": true,
            "interactionMode": "hover", "cabinetFrame": false,
            "notificationsEnabled": true, "launchAtLogin": false,
            "palVisible": true, "lastDurationMs": 300_000,
        ]
        let defaults = scratchDefaults()
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "timi.settings.v1")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.lastDurationMs, 300_000, "legacy values survive")
        XCTAssertTrue(store.settings.outlineOn, "new optional fields fall back to defaults")
        XCTAssertNil(store.settings.hasSeenHint)
    }

    func testUnknownEnumValueFallsBackWithoutWipingOtherSettings() throws {
        // A newer build wrote an interaction mode this build doesn't know.
        let blob: [String: Any] = ["interactionMode": "teleport", "volume": 0.3, "muted": true,
                                   "lastDurationMs": 0]
        let defaults = scratchDefaults()
        defaults.set(try JSONSerialization.data(withJSONObject: blob), forKey: "timi.settings.v1")
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.interactionMode, .hover, "unknown value → default")
        XCTAssertEqual(store.settings.volume, 0.3, "…while every other field survives")
        XCTAssertTrue(store.settings.muted)
        XCTAssertEqual(store.settings.lastDurationMs, 1_500_000, "nonsense duration → default")
    }

    func testCorruptSettingsFallBackToDefaultsInsteadOfCrashing() {
        let defaults = scratchDefaults()
        defaults.set(Data("garbage".utf8), forKey: "timi.settings.v1")
        XCTAssertEqual(SettingsStore(defaults: defaults).settings, AppSettings())
    }
}
