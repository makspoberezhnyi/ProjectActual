import Foundation

/// Turns raw open/close intervals into the "concrete time trend" the feature exists
/// for: not just how long someone spent in an app, but when in the day it happens.
///
/// Deliberately coarse. Bucketing by which `DayPart` an interval started in, rather than
/// splitting a session across a boundary minute by minute, matches how a person actually
/// reads this pattern back — "mornings" not "07:14 to 07:52".
public enum PassiveUsageAnalyzer {

    public struct AppTrend: Equatable, Sendable, Identifiable {
        public let appID: String
        public var id: String { appID }
        /// Every `DayPart` present, zero-filled rather than sparse, so a caller never
        /// has to handle a missing key.
        public let minutesByPart: [DayPart: Int]
        public let totalMinutes: Int

        public init(appID: String, minutesByPart: [DayPart: Int], totalMinutes: Int) {
            self.appID = appID
            self.minutesByPart = minutesByPart
            self.totalMinutes = totalMinutes
        }

        /// The band this app is mostly used in, when there is a real majority rather
        /// than a fairly even spread across the day. Nil is the honest answer when
        /// nothing dominates — this is what stops the UI from claiming a pattern that
        /// is not actually there.
        public var dominantPart: DayPart? {
            guard totalMinutes > 0,
                  let leading = minutesByPart.max(by: { $0.value < $1.value })
            else { return nil }
            return Double(leading.value) / Double(totalMinutes) >= 0.55 ? leading.key : nil
        }
    }

    /// One row per app, ranked by total time, each carrying its own day-part split.
    public static func trends(
        for intervals: [AppUsageInterval],
        calendar: Calendar = .current
    ) -> [AppTrend] {
        let grouped = Dictionary(grouping: intervals, by: \.appID)

        return grouped.map { appID, group in
            var byPart = Dictionary(uniqueKeysWithValues: DayPart.allCases.map { ($0, 0) })
            for interval in group {
                let hour = calendar.component(.hour, from: interval.start)
                byPart[DayPart.part(forHour: hour), default: 0] += interval.minutes
            }
            return AppTrend(appID: appID, minutesByPart: byPart, totalMinutes: byPart.values.reduce(0, +))
        }
        .sorted { $0.totalMinutes > $1.totalMinutes }
    }

    /// The single running total for one app on one calendar day — the "specific one
    /// timer for each app per day" the tracking is meant to keep.
    public static func dailyTotal(
        appID: String,
        intervals: [AppUsageInterval],
        on day: Date,
        calendar: Calendar = .current
    ) -> Int {
        intervals
            .filter { $0.appID == appID && calendar.isDate($0.start, inSameDayAs: day) }
            .reduce(0) { $0 + $1.minutes }
    }
}
