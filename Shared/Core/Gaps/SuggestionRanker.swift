import Foundation

/// An outstanding item from a planning tool the person already uses.
///
/// Only the name and the due date ever cross over. Nothing else in someone's notes is
/// read, and nothing is written back.
public struct PendingItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let dueDate: Date?

    public init(id: String, title: String, dueDate: Date?) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
    }
}

/// Something that would fit the open window.
public struct Suggestion: Equatable, Sendable, Identifiable {
    public enum Source: Equatable, Sendable {
        /// A habit the person's own history shows they actually do.
        case history(categoryID: String)
        /// Something already planned elsewhere but not done.
        case planning(dueDate: Date?)
    }

    public let id: String
    public let title: String
    /// What this usually takes them. Absent for a planning item never logged through
    /// the app, which is fine: recalibration starts on its next occurrence.
    public let typicalMinutes: Int?
    public let source: Source
    public let subtitle: String
    /// The category's own glyph, so a suggestion looks like the thing it is.
    public let symbolName: String
}

/// Builds the short, ranked list of things that fit an open window.
///
/// It never ranks downtime against productive time, and it never says a choice was
/// wrong. It offers options into a gap and logs whatever actually happens the same
/// neutral way as everything else.
public struct SuggestionRanker: Sendable {
    /// Never more than a handful. An uncapped list into a short window defeats the point.
    public var limit: Int
    /// How much longer than the window an activity may usually run and still be offered.
    public var tolerance: Double

    public init(limit: Int = 3, tolerance: Double = 1.0) {
        self.limit = limit
        self.tolerance = tolerance
    }

    public func suggestions(
        for window: TimeWindow,
        history: [SessionRecord],
        categoryNames: [String: String],
        categorySymbols: [String: String] = [:],
        excluding excluded: Set<String> = [],
        pending: [PendingItem] = [],
        now: Date = .now
    ) -> [Suggestion] {
        let fromHistory = historyCandidates(
            window: window,
            history: history,
            categoryNames: categoryNames,
            categorySymbols: categorySymbols,
            excluded: excluded
        )
        let fromPlanning = planningCandidates(pending: pending, now: now)

        return (fromHistory + fromPlanning)
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.suggestion)
    }

    // MARK: - Candidates

    private struct Scored {
        let suggestion: Suggestion
        let score: Double
    }

    /// Activities the person actually does, that fit, ranked by how habitual they are.
    private func historyCandidates(
        window: TimeWindow,
        history: [SessionRecord],
        categoryNames: [String: String],
        categorySymbols: [String: String],
        excluded: Set<String>
    ) -> [Scored] {
        let usable = history.filter { $0.contributesToDuration && !excluded.contains($0.categoryID) }
        let byCategory = Dictionary(grouping: usable, by: \.categoryID)

        return byCategory.compactMap { categoryID, records -> Scored? in
            let durations = records.compactMap(\.actualMinutes)
            guard !durations.isEmpty else { return nil }

            let typical = Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())
            guard typical > 0, Double(typical) <= Double(window.minutes) * tolerance else { return nil }

            let name = categoryNames[categoryID] ?? categoryID

            return Scored(
                suggestion: Suggestion(
                    id: "history-\(categoryID)",
                    title: name,
                    typicalMinutes: typical,
                    source: .history(categoryID: categoryID),
                    subtitle: "usually about \(DurationFormatting.compact(minutes: typical))",
                    symbolName: categorySymbols[categoryID] ?? "clock"
                ),
                // Twenty occurrences is treated as thoroughly habitual; past that the
                // extra count says nothing new about whether to offer it.
                score: min(Double(records.count), 20) / 20
            )
        }
    }

    /// Items already planned elsewhere, weighted up as their due date approaches.
    private func planningCandidates(pending: [PendingItem], now: Date) -> [Scored] {
        pending.map { item in
            var score = 0.5
            var subtitle = "from your reminders"

            if let due = item.dueDate {
                let hours = due.timeIntervalSince(now) / 3600
                if hours < 0 {
                    score += 0.4
                    subtitle = "from your reminders, overdue"
                } else if hours <= 24 {
                    score += 0.35
                    subtitle = "from your reminders, due \(hours <= 12 ? "today" : "tomorrow")"
                } else if hours <= 72 {
                    score += 0.2
                    subtitle = "from your reminders, due soon"
                }
            }

            return Scored(
                suggestion: Suggestion(
                    id: "planning-\(item.id)",
                    title: item.title,
                    typicalMinutes: nil,
                    source: .planning(dueDate: item.dueDate),
                    subtitle: subtitle,
                    symbolName: "checkmark.square"
                ),
                score: min(score, 0.95)
            )
        }
    }
}
