import Foundation
import EventKit

public struct ScheduleItem: Identifiable, Hashable, Codable {
    public var id: String
    public var title: String
    public var timeString: String?
    public var estimatedMinutes: Int
    public var isCalendarEvent: Bool
    public var location: String?
    public var latitude: Double?
    public var longitude: Double?
    public var travelEtaMinutes: Int?
    public var travelDistanceString: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        timeString: String? = nil,
        estimatedMinutes: Int = 25,
        isCalendarEvent: Bool = false,
        location: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        travelEtaMinutes: Int? = nil,
        travelDistanceString: String? = nil
    ) {
        self.id = id
        self.title = title
        self.timeString = timeString
        self.estimatedMinutes = estimatedMinutes
        self.isCalendarEvent = isCalendarEvent
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.travelEtaMinutes = travelEtaMinutes
        self.travelDistanceString = travelDistanceString
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
        
        let calendarEnabled = UserDefaults.standard.object(forKey: "integration_calendar_enabled") as? Bool ?? true
        let remindersEnabled = UserDefaults.standard.object(forKey: "integration_reminders_enabled") as? Bool ?? true
        
        if (target == .calendar || target == .both) && calendarEnabled {
            let calendarAuth = await requestCalendarAccess()
            if calendarAuth {
                let events = fetchTodayEventObjects()
                for event in events {
                    let duration = event.endDate.timeIntervalSince(event.startDate)
                    let mins = max(10, min(180, Int(duration / 60)))
                    let timeStr = timeFormatter.string(from: event.startDate)
                    
                    let locString = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let validLocation = (locString != nil && !locString!.isEmpty) ? locString : nil
                    var lat: Double? = nil
                    var lon: Double? = nil
                    var etaMins: Int? = nil
                    var distStr: String? = nil
                    
                    if let geo = event.structuredLocation?.geoLocation {
                        lat = geo.coordinate.latitude
                        lon = geo.coordinate.longitude
                    }
                    
                    if let validLocation {
                        if let travel = await LocationTravelManager.shared.calculateTravel(to: validLocation) {
                            etaMins = travel.travelDurationMinutes
                            distStr = travel.distanceString
                            if lat == nil {
                                lat = travel.latitude
                                lon = travel.longitude
                            }
                        }
                    }
                    
                    let item = ScheduleItem(
                        id: event.eventIdentifier,
                        title: event.title ?? "Calendar Event",
                        timeString: timeStr,
                        estimatedMinutes: mins,
                        isCalendarEvent: true,
                        location: validLocation,
                        latitude: lat,
                        longitude: lon,
                        travelEtaMinutes: etaMins,
                        travelDistanceString: distStr
                    )
                    results.append(item)
                }
            }
        }
        
        if (target == .reminders || target == .both) && remindersEnabled {
            let remindersAuth = await requestRemindersAccess()
            if remindersAuth {
                let reminders = await fetchIncompleteReminderObjects()
                for reminder in reminders {
                    var timeStr = "Reminder"
                    if let due = reminder.dueDateComponents?.date {
                        timeStr = timeFormatter.string(from: due)
                    }
                    
                    let locString = reminder.location?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let validLocation = (locString != nil && !locString!.isEmpty) ? locString : nil
                    var lat: Double? = nil
                    var lon: Double? = nil
                    var etaMins: Int? = nil
                    var distStr: String? = nil
                    
                    if let validLocation {
                        if let travel = await LocationTravelManager.shared.calculateTravel(to: validLocation) {
                            etaMins = travel.travelDurationMinutes
                            distStr = travel.distanceString
                            lat = travel.latitude
                            lon = travel.longitude
                        }
                    }
                    
                    let item = ScheduleItem(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Task",
                        timeString: timeStr,
                        estimatedMinutes: 25,
                        isCalendarEvent: false,
                        location: validLocation,
                        latitude: lat,
                        longitude: lon,
                        travelEtaMinutes: etaMins,
                        travelDistanceString: distStr
                    )
                    results.append(item)
                }
            }
        }
        
        return results
    }
    
    func nextUpcomingItemWithLocation(mode: TravelTransportMode = .driving) async -> (ScheduleItem, TravelAssessmentResult)? {
        let items = await fetchItems(for: .both)
        for item in items {
            if let loc = item.location, !loc.isEmpty {
                if let travel = await LocationTravelManager.shared.calculateTravel(to: loc, mode: mode) {
                    return (item, travel)
                }
            }
        }
        // Fallback: If no event has an explicit location, check the first upcoming event
        if let first = items.first {
            if let travel = await LocationTravelManager.shared.calculateTravel(to: first.title, mode: mode) {
                return (first, travel)
            }
        }
        return nil
    }

    
    // MARK: - Bidirectional Write / Update / Delete Methods
    func updateCalendarEvent(identifier: String, start: Date, end: Date, actualMinutes: Int) async -> Bool {
        guard await requestCalendarAccess() else { return false }
        guard let event = store.event(withIdentifier: identifier) else { return false }
        
        event.startDate = start
        event.endDate = end
        let tempoNote = "⏱ Tracked with Tempo (\(actualMinutes)m)"
        if let existing = event.notes, !existing.isEmpty {
            if !existing.contains("Tracked with Tempo") {
                event.notes = "\(existing)\n\n\(tempoNote)"
            }
        } else {
            event.notes = tempoNote
        }
        
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            print("Failed to update calendar event: \(error)")
            return false
        }
    }
    
    func completeReminder(identifier: String) async -> Bool {
        guard await requestRemindersAccess() else { return false }
        guard let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return false }
        
        item.isCompleted = true
        item.completionDate = Date()
        
        do {
            try store.save(item, commit: true)
            return true
        } catch {
            print("Failed to complete reminder: \(error)")
            return false
        }
    }
    
    func uncompleteReminder(identifier: String) async -> Bool {
        guard await requestRemindersAccess() else { return false }
        guard let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return false }
        
        item.isCompleted = false
        item.completionDate = nil
        
        do {
            try store.save(item, commit: true)
            return true
        } catch {
            print("Failed to uncomplete reminder: \(error)")
            return false
        }
    }
    
    func revertCalendarEvent(identifier: String) async -> Bool {
        guard await requestCalendarAccess() else { return false }
        guard let event = store.event(withIdentifier: identifier) else { return false }
        
        if let notes = event.notes {
            let cleaned = notes
                .replacingOccurrences(of: "\n\n⏱ Tracked with Tempo.*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "⏱ Tracked with Tempo.*", with: "", options: .regularExpression)
            event.notes = cleaned.isEmpty ? nil : cleaned
        }
        
        do {
            try store.save(event, span: .thisEvent, commit: true)
            return true
        } catch {
            print("Failed to revert calendar event: \(error)")
            return false
        }
    }
    
    func deleteItem(identifier: String, isCalendarEvent: Bool) async -> Bool {
        if isCalendarEvent {
            guard await requestCalendarAccess() else { return false }
            guard let event = store.event(withIdentifier: identifier) else { return false }
            do {
                try store.remove(event, span: .thisEvent, commit: true)
                return true
            } catch {
                print("Failed to delete event: \(error)")
                return false
            }
        } else {
            guard await requestRemindersAccess() else { return false }
            guard let reminder = store.calendarItem(withIdentifier: identifier) as? EKReminder else { return false }
            do {
                try store.remove(reminder, commit: true)
                return true
            } catch {
                print("Failed to delete reminder: \(error)")
                return false
            }
        }
    }
    
    private func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let status = EKEventStore.authorizationStatus(for: .event)
                if status == .fullAccess { return true }
                return try await store.requestFullAccessToEvents()
            } catch {
                return false
            }
        } else {
            do {
                let status = EKEventStore.authorizationStatus(for: .event)
                if status == .authorized { return true }
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
                if status == .fullAccess { return true }
                return try await store.requestFullAccessToReminders()
            } catch {
                return false
            }
        } else {
            do {
                let status = EKEventStore.authorizationStatus(for: .reminder)
                if status == .authorized { return true }
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
