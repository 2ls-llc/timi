import XCTest
@testable import TimiKit

final class SessionStatsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 10) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func rec(_ d: Date, completed: Bool = true) -> SessionRecord {
        SessionRecord(startedAt: d, durationMs: 1_500_000, completed: completed, character: "timi")
    }

    func testHeartsTodayCountsOnlyTodaysCompletedSessions() {
        let now = date(2026, 9, 1, hour: 15)
        let records = [
            rec(date(2026, 9, 1, hour: 9)),
            rec(date(2026, 9, 1, hour: 14), completed: false),  // abandoned: no heart
            rec(date(2026, 8, 31)),                             // yesterday
            rec(date(2026, 9, 1, hour: 0)),                     // local midnight counts as today
        ]
        XCTAssertEqual(SessionStats.heartsToday(records, now: now, calendar: cal), 2)
    }

    func testLifetimeCountsAllCompleted() {
        let records = [rec(date(2026, 1, 1)), rec(date(2026, 5, 5)), rec(date(2026, 9, 1), completed: false)]
        XCTAssertEqual(SessionStats.lifetimeCompleted(records), 2)
    }

    func testStreakCountsConsecutiveDays() {
        let records = [rec(date(2026, 8, 30)), rec(date(2026, 8, 31)), rec(date(2026, 9, 1))]
        XCTAssertEqual(SessionStats.streakDays(records, now: date(2026, 9, 1, hour: 20), calendar: cal), 3)
    }

    func testStreakSurvivesAnEmptyTodayThroughYesterday() {
        let records = [rec(date(2026, 8, 30)), rec(date(2026, 8, 31))]
        XCTAssertEqual(SessionStats.streakDays(records, now: date(2026, 9, 1, hour: 8), calendar: cal), 2)
    }

    func testStreakBreaksOnAGap() {
        let records = [rec(date(2026, 8, 28)), rec(date(2026, 8, 29)), rec(date(2026, 8, 31)), rec(date(2026, 9, 1))]
        XCTAssertEqual(SessionStats.streakDays(records, now: date(2026, 9, 1), calendar: cal), 2)
    }

    func testStreakIsZeroWhenNeitherTodayNorYesterdayHasASession() {
        let records = [rec(date(2026, 8, 29))]
        XCTAssertEqual(SessionStats.streakDays(records, now: date(2026, 9, 1), calendar: cal), 0)
        XCTAssertEqual(SessionStats.streakDays([], now: date(2026, 9, 1), calendar: cal), 0)
    }

    func testIncompleteSessionsNeverCount() {
        let records = [rec(date(2026, 9, 1), completed: false), rec(date(2026, 8, 31), completed: false)]
        let now = date(2026, 9, 1, hour: 12)
        XCTAssertEqual(SessionStats.heartsToday(records, now: now, calendar: cal), 0)
        XCTAssertEqual(SessionStats.lifetimeCompleted(records), 0)
        XCTAssertEqual(SessionStats.streakDays(records, now: now, calendar: cal), 0)
    }

    func testSessionCrossingMidnightCreditsTheDayItFinished() {
        // Started 23:50 on the 31st, finished 00:15 on the 1st: the pal awards the
        // heart on the 1st, so the ledger must agree.
        var late = rec(date(2026, 8, 31, hour: 23))
        late.completedAt = date(2026, 9, 1, hour: 0)
        let now = date(2026, 9, 1, hour: 9)
        XCTAssertEqual(SessionStats.heartsToday([late], now: now, calendar: cal), 1)
        XCTAssertEqual(SessionStats.streakDays([late], now: now, calendar: cal), 1)
        // Records from before completedAt existed still credit their start day.
        let legacy = rec(date(2026, 8, 31))
        XCTAssertEqual(SessionStats.heartsToday([legacy], now: now, calendar: cal), 0)
    }

    func testMultipleSessionsOnOneDayCountOnceForStreak() {
        let records = [rec(date(2026, 9, 1, hour: 9)), rec(date(2026, 9, 1, hour: 11)), rec(date(2026, 8, 31))]
        XCTAssertEqual(SessionStats.streakDays(records, now: date(2026, 9, 1, hour: 12), calendar: cal), 2)
        XCTAssertEqual(SessionStats.heartsToday(records, now: date(2026, 9, 1, hour: 12), calendar: cal), 2)
    }
}
