import Foundation

/// One timer session, recorded at start and marked completed at finish.
public struct SessionRecord: Codable, Equatable, Sendable {
    public var startedAt: Date
    public var durationMs: Double
    public var completed: Bool
    public var character: String
    /// When the session finished. Hearts and streaks key on this (a session
    /// started at 23:50 and finished at 00:15 belongs to the new day, matching
    /// the heart the pal awards on screen). Optional for records written before
    /// it existed — those fall back to `startedAt`.
    public var completedAt: Date?

    public init(startedAt: Date, durationMs: Double, completed: Bool, character: String,
                completedAt: Date? = nil) {
        self.startedAt = startedAt
        self.durationMs = durationMs
        self.completed = completed
        self.character = character
        self.completedAt = completedAt
    }

    /// The day this session counts toward.
    public var creditDate: Date { completedAt ?? startedAt }
}

/// Pure stats over session records — hearts today, lifetime, streak.
public enum SessionStats {
    /// Completed sessions since local midnight (the hearts row).
    public static func heartsToday(_ records: [SessionRecord], now: Date = Date(),
                                   calendar: Calendar = .current) -> Int {
        records.lazy.filter { $0.completed && calendar.isDate($0.creditDate, inSameDayAs: now) }.count
    }

    public static func lifetimeCompleted(_ records: [SessionRecord]) -> Int {
        records.lazy.filter(\.completed).count
    }

    /// Consecutive days with ≥ 1 completed session, counting back from today
    /// (today itself may still be empty without breaking the streak).
    public static func streakDays(_ records: [SessionRecord], now: Date = Date(),
                                  calendar: Calendar = .current) -> Int {
        let days = Set(records.lazy.filter(\.completed)
            .map { calendar.startOfDay(for: $0.creditDate) })
        guard !days.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: now)
        var streak = 0
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
