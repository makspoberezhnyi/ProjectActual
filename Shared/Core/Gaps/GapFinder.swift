import Foundation

/// A stretch of time with a start and an end.
public struct TimeWindow: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = max(start, end)
    }

    public var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

/// Something already committed: a calendar event, or a session already running.
public struct BusyInterval: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let title: String

    public init(start: Date, end: Date, title: String = "") {
        self.start = start
        self.end = max(start, end)
        self.title = title
    }
}

/// Finds the open stretches between fixed commitments.
///
/// Pure arithmetic over intervals, so it can be tested with literals and reused by both
/// the gap filler and the shared reminder prompt, which needs the same question answered:
/// is there a free stretch big enough for this right now.
public enum GapFinder {

    /// Open windows inside `bounds`, once everything busy is taken out.
    ///
    /// Overlapping commitments are merged first — two meetings that overlap are one busy
    /// block, not two, and treating them separately would invent a gap that is not there.
    public static func gaps(
        in bounds: TimeWindow,
        busy: [BusyInterval],
        minimumMinutes: Int = 10
    ) -> [TimeWindow] {
        guard bounds.minutes >= minimumMinutes else { return [] }

        let clipped = busy
            .map { BusyInterval(start: max($0.start, bounds.start), end: min($0.end, bounds.end), title: $0.title) }
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }

        var merged: [BusyInterval] = []
        for interval in clipped {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = BusyInterval(
                    start: last.start,
                    end: max(last.end, interval.end),
                    title: last.title
                )
            } else {
                merged.append(interval)
            }
        }

        var gaps: [TimeWindow] = []
        var cursor = bounds.start

        for interval in merged {
            if interval.start > cursor {
                gaps.append(TimeWindow(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if cursor < bounds.end {
            gaps.append(TimeWindow(start: cursor, end: bounds.end))
        }

        return gaps.filter { $0.minutes >= minimumMinutes }
    }

    /// The gap happening right now, if there is one worth suggesting into.
    public static func currentGap(
        at moment: Date,
        in bounds: TimeWindow,
        busy: [BusyInterval],
        minimumMinutes: Int = 10
    ) -> TimeWindow? {
        gaps(in: bounds, busy: busy, minimumMinutes: minimumMinutes)
            .first { $0.start <= moment && $0.end > moment }
            .map { TimeWindow(start: moment, end: $0.end) }
            .flatMap { $0.minutes >= minimumMinutes ? $0 : nil }
    }
}
