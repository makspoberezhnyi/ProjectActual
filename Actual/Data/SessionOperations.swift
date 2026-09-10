import Foundation
import SwiftData

/// The core loop's SwiftData-facing rules, with no SwiftUI dependency.
///
/// `RootView.MainShell` still owns *when* to show a sheet or flip a screen — that is
/// genuinely view state, and the timing around it has already been hard-won (see the
/// comments on `CaptureRequest`). What belongs here instead is the handful of rules
/// that just read or write model objects: which category a typed name resolves to,
/// whether a session counts as a trip, when a stale session gets closed against a
/// ceiling. None of that needs a view to exist, so none of it should only be
/// reachable through one — this is what `SessionOperationsTests` exercises directly,
/// against a real in-memory `ModelContext`, the same way `DataTransferTests` does.
enum SessionOperations {

    /// Categories are the person's own, named in whatever language they typed. A title
    /// that matches one they already have reuses it, so history keeps accumulating
    /// against the same key rather than fragmenting across near-identical names.
    ///
    /// `symbolName` only matters the moment a category is actually created — an
    /// existing match already has whatever icon it was given the first time, and
    /// reusing it here is the whole point of matching by name at all rather than
    /// letting every mention of "Work session" become its own category.
    static func resolveCategory(
        named title: String,
        symbolName: String? = nil,
        categories: [TaskCategory],
        context: ModelContext
    ) -> TaskCategory {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = categories.first(where: {
            $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }) {
            return existing
        }

        let created = TaskCategory(name: trimmed, symbolName: symbolName ?? "circle")
        context.insert(created)
        return created
    }

    static func isTrip(_ session: Session, categoriesByID: [String: TaskCategory]) -> Bool {
        guard let categoryID = session.categoryID else { return false }
        return categoriesByID[categoryID]?.isTrip ?? false
    }

    /// How long a category usually takes, from history alone — never the stored guess
    /// re-multiplied, so a corrected expectation doesn't compound onto an old one.
    static func expectedMinutes(for session: Session, history: [SessionRecord]) -> Int? {
        guard let categoryID = session.categoryID else { return nil }
        return BiasEngine().recalibratedEstimate(
            rawGuessMinutes: nil,
            for: CategoryKey(categoryID: categoryID, contextTag: session.contextTag),
            from: history
        )?.minutes
    }

    /// A trip that never resolves an arrival, or a task started and never stopped, is
    /// closed against a ceiling and flagged rather than left open forever or silently
    /// treated as normal data.
    static func closeAbandoned(_ sessions: [Session], context: ModelContext) {
        let ceiling: TimeInterval = 12 * 3600
        let stale = sessions.filter {
            $0.isRunning && ($0.clockStart.map { Date.now.timeIntervalSince($0) > ceiling } ?? false)
        }
        guard !stale.isEmpty else { return }

        for session in stale {
            session.endedAt = session.clockStart?.addingTimeInterval(ceiling)
            // Visible as an outlier in history, and withheld from the weighted average,
            // rather than deleted or quietly averaged in.
            session.isFlaggedLowConfidence = true
        }
        try? context.save()
    }

    /// A window that closed without the reminder being acted on is marked expired, not
    /// deleted. It stays visible as a plain, undone item: a factual record that this one
    /// did not happen, with no judgement attached.
    static func expireLapsed(_ reminders: [ReceivedReminder], context: ModelContext) {
        let lapsed = reminders.filter { $0.hasExpired() }
        guard !lapsed.isEmpty else { return }
        lapsed.forEach { $0.state = .expired }
        try? context.save()
    }

    /// A ping link, only when this session came from a reminder whose sender asked to
    /// be told, off by default.
    static func pingURL(for session: Session, receivedReminders: [ReceivedReminder]) -> URL? {
        guard let shareID = session.sourceReminderShareID,
              let reminder = receivedReminders.first(where: { $0.shareID == shareID }),
              reminder.sharesCompletion
        else { return nil }
        return PingLink.url(shareID: shareID)
    }

    /// Removes one session: from the day's list, and from the weighted average the
    /// category it belonged to is built from. A session logged in error, or one the
    /// person simply does not want counted, should not have to survive forever just
    /// because there is no delete-all-history-sized way to remove one entry.
    static func deleteSession(_ session: Session, context: ModelContext) {
        context.delete(session)
        try? context.save()
    }
}
