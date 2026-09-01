import XCTest
@testable import TimiKit

final class DurationFormatTests: XCTestCase {
    func testCompactWholeMinutes() {
        XCTAssertEqual(DurationFormat.compact(ms: 720_000), "12m")
        XCTAssertEqual(DurationFormat.compact(ms: 1_500_000), "25m")
        XCTAssertEqual(DurationFormat.compact(ms: 60_000), "1m")
    }

    func testCompactNonWholeMinutesUseClockStyle() {
        XCTAssertEqual(DurationFormat.compact(ms: 90_000), "1:30")
        XCTAssertEqual(DurationFormat.compact(ms: 65_000), "1:05")
        XCTAssertEqual(DurationFormat.compact(ms: 30_000), "0:30")
    }

    func testHumanizedNotificationAdjective() {
        XCTAssertEqual(DurationFormat.humanized(ms: 1_500_000), "25-minute")
        XCTAssertEqual(DurationFormat.humanized(ms: 60_000), "1-minute")
        XCTAssertEqual(DurationFormat.humanized(ms: 30_000), "30-second")
        XCTAssertEqual(DurationFormat.humanized(ms: 90_000), "90-second")
        XCTAssertEqual(DurationFormat.humanized(ms: 750_000), "12:30",
                       "long non-whole lengths read as a clock, never '750-second'")
    }

    func testPresetsAreTheSingleSourceOfTruth() {
        XCTAssertEqual(DurationPreset.all.map(\.ms), [30_000, 300_000, 900_000, 1_500_000])
        XCTAssertEqual(DurationPreset.all.map(\.chipLabel), ["30s", "5m", "15m", "25m"])
        XCTAssertEqual(TimerCore.presetsMs, DurationPreset.all.map(\.ms))
        XCTAssertEqual(TimerCore.defaultDurationMs, 1_500_000)
        XCTAssertTrue(DurationPreset.isPreset(1_500_000))
        XCTAssertFalse(DurationPreset.isPreset(720_000))
    }

    func testClockFormatCeilsToWholeSeconds() {
        XCTAssertEqual(formatMillis(1_500_000), "25:00")
        XCTAssertEqual(formatMillis(0), "0:00")
        XCTAssertEqual(formatMillis(65_001), "1:06", "ceil, like the prototype's fmt()")
        XCTAssertEqual(formatMillis(59_400), "1:00")
        XCTAssertEqual(formatMillis(-5), "0:00", "never negative")
    }
}
