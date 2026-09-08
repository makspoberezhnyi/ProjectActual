import Testing
import Foundation
@testable import Actual

struct PassiveUsageTests {

    // A fixed calendar day: 2026-09-08, a Tuesday.
    private let day = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 8))!

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func interval(_ appID: String, from: (Int, Int), minutes: Int) -> AppUsageInterval {
        let start = at(from.0, from.1)
        return AppUsageInterval(appID: appID, start: start, end: start.addingTimeInterval(Double(minutes) * 60))
    }

    // MARK: - Day part boundaries

    @Test(
        "Each hour falls into exactly the band it belongs to",
        arguments: [(4, DayPart.night), (5, .morning), (11, .morning), (12, .afternoon),
                    (16, .afternoon), (17, .evening), (21, .evening), (22, .night), (23, .night), (0, .night)]
    )
    func dayPartBoundaries(hour: Int, expected: DayPart) {
        #expect(DayPart.part(forHour: hour) == expected)
    }

    // MARK: - Trend

    @Test("Morning-heavy use reads as a morning trend")
    func detectsMorningPattern() throws {
        let intervals = [
            interval("tiktok", from: (7, 0), minutes: 20),
            interval("tiktok", from: (8, 30), minutes: 25),
            interval("tiktok", from: (20, 0), minutes: 5)
        ]
        let trend = try #require(PassiveUsageAnalyzer.trends(for: intervals).first)
        #expect(trend.appID == "tiktok")
        #expect(trend.totalMinutes == 50)
        #expect(trend.dominantPart == .morning)
    }

    @Test("Evening-heavy use reads as an evening trend, a distinct pattern from morning")
    func detectsEveningPattern() throws {
        let intervals = [
            interval("instagram", from: (18, 0), minutes: 30),
            interval("instagram", from: (19, 30), minutes: 20),
            interval("instagram", from: (7, 0), minutes: 3)
        ]
        let trend = try #require(PassiveUsageAnalyzer.trends(for: intervals).first)
        #expect(trend.dominantPart == .evening)
    }

    @Test("A fairly even spread across the day claims no dominant part")
    func evenSpreadHasNoDominantPart() throws {
        let intervals = [
            interval("reddit", from: (7, 0), minutes: 15),
            interval("reddit", from: (13, 0), minutes: 15),
            interval("reddit", from: (19, 0), minutes: 15),
            interval("reddit", from: (23, 0), minutes: 15)
        ]
        let trend = try #require(PassiveUsageAnalyzer.trends(for: intervals).first)
        #expect(trend.dominantPart == nil)
    }

    @Test("Multiple apps are kept as separate rows, ranked by total time")
    func ranksAppsByTotal() {
        let intervals = [
            interval("tiktok", from: (7, 0), minutes: 45),
            interval("instagram", from: (7, 0), minutes: 10)
        ]
        let trends = PassiveUsageAnalyzer.trends(for: intervals)
        #expect(trends.map(\.appID) == ["tiktok", "instagram"])
    }

    @Test("Every day part is present in the split even when an app never appears there")
    func zeroFillsAbsentParts() throws {
        let intervals = [interval("tiktok", from: (7, 0), minutes: 10)]
        let trend = try #require(PassiveUsageAnalyzer.trends(for: intervals).first)
        #expect(Set(trend.minutesByPart.keys) == Set(DayPart.allCases))
        #expect(trend.minutesByPart[.evening] == 0)
    }

    // MARK: - Daily total

    @Test("The daily total is one number per app per day, not per session")
    func dailyTotalSumsSessionsForOneApp() {
        let intervals = [
            interval("tiktok", from: (7, 0), minutes: 10),
            interval("tiktok", from: (12, 0), minutes: 15),
            interval("instagram", from: (7, 0), minutes: 100)
        ]
        let total = PassiveUsageAnalyzer.dailyTotal(appID: "tiktok", intervals: intervals, on: day)
        #expect(total == 25)
    }

    @Test("A day with nothing logged for that app totals zero, not missing")
    func dailyTotalZeroWhenAbsent() {
        let total = PassiveUsageAnalyzer.dailyTotal(appID: "tiktok", intervals: [], on: day)
        #expect(total == 0)
    }
}
