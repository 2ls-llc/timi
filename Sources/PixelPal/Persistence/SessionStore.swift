import Foundation
import PixelPalKit

/// JSON session ledger at ~/Library/Application Support/PixelPal/sessions.json
/// (inside the sandbox container when sandboxed). A session is appended at start
/// and its `completed` flag flipped at finish, so app termination mid-session
/// naturally records an incomplete run.
final class SessionStore {
    private(set) var records: [SessionRecord] = []
    private let fileURL: URL
    /// Fired by resetAll — lets the app invalidate any held record indices.
    var onReset: (() -> Void)?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first!
            let dir = base.appendingPathComponent("PixelPal", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("sessions.json")
        }
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Records the start of a session; returns its index for later completion.
    @discardableResult
    func beginSession(durationMs: Double, character: CharacterID, now: Date = Date()) -> Int {
        records.append(SessionRecord(startedAt: now, durationMs: durationMs,
                                     completed: false, character: character.rawValue))
        save()
        return records.count - 1
    }

    func completeSession(at index: Int) {
        guard records.indices.contains(index) else { return }
        records[index].completed = true
        save()
    }

    var heartsToday: Int { SessionStats.heartsToday(records) }
    var lifetimeCompleted: Int { SessionStats.lifetimeCompleted(records) }
    var streakDays: Int { SessionStats.streakDays(records) }

    /// Settings "Reset hearts": clears the ledger.
    func resetAll() {
        records = []
        save()
        onReset?()
    }
}
