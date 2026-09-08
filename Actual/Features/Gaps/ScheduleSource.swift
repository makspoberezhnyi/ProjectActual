import Foundation
import EventKit

/// Reads the person's fixed commitments and outstanding reminders.
///
/// Both are opt in and read only. From reminders, only the name and due date are ever
/// touched — nothing else in someone's notes is read, and nothing is written back.
@MainActor
@Observable
final class ScheduleSource {
    private let store = EKEventStore()

    private(set) var hasCalendarAccess = false
    private(set) var hasReminderAccess = false
    private(set) var busy: [BusyInterval] = []
    private(set) var pending: [PendingItem] = []
    /// The commitment the current free stretch runs up against, which is what makes a
    /// window mean something: "free until four thirty" is vaguer than "before pickup".
    private(set) var nextCommitment: BusyInterval?

    func refresh(for day: Date = .now) async {
        await requestAccessIfNeeded()

        if hasCalendarAccess {
            busy = loadBusyIntervals(on: day)
        }
        if hasReminderAccess {
            pending = await loadPendingReminders()
        }

        let bounds = Self.dayBounds(for: day)
        nextCommitment = busy
            .filter { $0.start > day }
            .min { $0.start < $1.start }
        _ = bounds
    }

    /// The open stretch happening right now, if there is one worth suggesting into.
    func currentGap(at moment: Date = .now, minimumMinutes: Int = 10) -> TimeWindow? {
        GapFinder.currentGap(
            at: moment,
            in: Self.dayBounds(for: moment),
            busy: busy,
            minimumMinutes: minimumMinutes
        )
    }

    // MARK: - Access

    private func requestAccessIfNeeded() async {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            hasCalendarAccess = true
        } else {
            hasCalendarAccess = (try? await store.requestFullAccessToEvents()) ?? false
        }

        if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
            hasReminderAccess = true
        } else {
            hasReminderAccess = (try? await store.requestFullAccessToReminders()) ?? false
        }
    }

    // MARK: - Loading

    private func loadBusyIntervals(on day: Date) -> [BusyInterval] {
        let bounds = Self.dayBounds(for: day)
        let predicate = store.predicateForEvents(
            withStart: bounds.start, end: bounds.end, calendars: nil
        )

        return store.events(matching: predicate)
            // An all-day event is a label on the day, not a block of time inside it.
            .filter { !$0.isAllDay && $0.status != .canceled }
            .map { BusyInterval(start: $0.startDate, end: $0.endDate, title: $0.title ?? "") }
    }

    private func loadPendingReminders() async -> [PendingItem] {
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: nil
        )

        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                let items = (reminders ?? []).compactMap { reminder -> PendingItem? in
                    guard let title = reminder.title, !title.isEmpty else { return nil }
                    return PendingItem(
                        id: reminder.calendarItemIdentifier,
                        title: title,
                        dueDate: reminder.dueDateComponents?.date
                    )
                }
                continuation.resume(returning: items)
            }
        }
    }

    /// The waking part of a day. Suggesting into three in the morning would be noise.
    static func dayBounds(for day: Date) -> TimeWindow {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day) ?? day
        let end = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day) ?? day
        return TimeWindow(start: start, end: end)
    }
}
