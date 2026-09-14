import Foundation
import EventKit

public struct ScheduleItem: Identifiable, Hashable, Codable {
    public var id: String
    public var title: String
    public var timeString: String?
    public var estimatedMinutes: Int
    public var isCalendarEvent: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        timeString: String? = nil,
        estimatedMinutes: Int = 25,
        isCalendarEvent: Bool = false
    ) {
        self.id = id
        self.title = title
        self.timeString = timeString
        self.estimatedMinutes = estimatedMinutes
        self.isCalendarEvent = isCalendarEvent
    }
}

@Observable
class EventKitManager {
    static let shared = EventKitManager()
    private let store = EKEventStore()
    
    var suggestions: [String] = []
    
    init() {}
    
    func requestAccessAndFetch() {
        Task {
            let items = await fetchItems(for: .both)
            let suggestionStrings = items.map { item in
                "\(item.title) (\(item.estimatedMinutes)m)"
            }
            
            await MainActor.run {
                self.suggestions = Array(suggestionStrings.prefix(5))
            }
        }
    }
    
    func fetchItems(for target: IntegrationTarget) async -> [ScheduleItem] {
        var results: [ScheduleItem] = []
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        if target == .calendar || target == .both {
            let calendarAuth = await requestCalendarAccess()
            if calendarAuth {
                let events = fetchTodayEventObjects()
                for event in events {
                    let duration = event.endDate.timeIntervalSince(event.startDate)
                    let mins = max(10, min(180, Int(duration / 60)))
                    let timeStr = timeFormatter.string(from: event.startDate)
                    let item = ScheduleItem(
                        title: event.title ?? "Calendar Event",
                        timeString: timeStr,
                        estimatedMinutes: mins,
                        isCalendarEvent: true
                    )
                    results.append(item)
                }
            }
        }
        
        if target == .reminders || target == .both {
            let remindersAuth = await requestRemindersAccess()
            if remindersAuth {
                let reminders = await fetchIncompleteReminderObjects()
                for reminder in reminders {
                    var timeStr = "Reminder"
                    if let due = reminder.dueDateComponents?.date {
                        timeStr = timeFormatter.string(from: due)
                    }
                    let item = ScheduleItem(
                        title: reminder.title ?? "Task",
                        timeString: timeStr,
                        estimatedMinutes: 25,
                        isCalendarEvent: false
                    )
                    results.append(item)
                }
            }
        }
        
        return results
    }
    
    private func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let status = EKEventStore.authorizationStatus(for: .event)
                if status == .authorized || status == .fullAccess { return true }
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            do {
                return try await store.requestAccess(to: .event)
            } catch {
                return false
            }
        }
    }
    
    private func requestRemindersAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let status = EKEventStore.authorizationStatus(for: .reminder)
                if status == .authorized || status == .fullAccess { return true }
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            do {
                return try await store.requestAccess(to: .reminder)
            } catch {
                return false
            }
        }
    }
    
    private func fetchTodayEventObjects() -> [EKEvent] {
        let calendars = store.calendars(for: .event)
        let now = Date()
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return [] }
        
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: calendars)
        let events = store.events(matching: predicate)
        
        return events
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private func fetchIncompleteReminderObjects() async -> [EKReminder] {
        return await withCheckedContinuation { continuation in
            let calendars = store.calendars(for: .reminder)
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
            
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
