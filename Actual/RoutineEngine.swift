import Foundation
import SwiftData
import SwiftUI
import UserNotifications

struct RoutinePattern: Identifiable, Hashable, Codable {
    var id: String
    var taskTitle: String
    var typicalMinutes: Int
    var typicalHour: Int // 0...23
    var typicalMinute: Int // 0...59
    var isDayOfWeekSpecific: Bool
    var targetWeekday: Int? // 1 (Sunday) ... 7 (Saturday)
    var confidence: Double // 0.0 ... 1.0
    var occurrencesCount: Int
    
    init(
        id: String = UUID().uuidString,
        taskTitle: String,
        typicalMinutes: Int,
        typicalHour: Int,
        typicalMinute: Int,
        isDayOfWeekSpecific: Bool,
        targetWeekday: Int? = nil,
        confidence: Double,
        occurrencesCount: Int
    ) {
        self.id = id
        self.taskTitle = taskTitle
        self.typicalMinutes = typicalMinutes
        self.typicalHour = typicalHour
        self.typicalMinute = typicalMinute
        self.isDayOfWeekSpecific = isDayOfWeekSpecific
        self.targetWeekday = targetWeekday
        self.confidence = confidence
        self.occurrencesCount = occurrencesCount
    }
    
    var recurrenceDescription: String {
        var components = DateComponents()
        components.hour = typicalHour
        components.minute = typicalMinute
        let timeStr = Calendar.current.date(from: components).map {
            DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short)
        } ?? String(format: "%02d:%02d", typicalHour, typicalMinute)
        
        if isDayOfWeekSpecific, let weekday = targetWeekday {
            let weekdaySymbols = Calendar.current.weekdaySymbols
            let dayName = weekdaySymbols[(weekday - 1) % weekdaySymbols.count]
            return "Every \(dayName) around \(timeStr)"
        } else {
            return "Daily around \(timeStr)"
        }
    }
}

struct RoutineSuggestion: Identifiable, Hashable {
    var id: String { pattern.id }
    var pattern: RoutinePattern
    var headline: String
    var promptMessage: String
    var recommendedMinutes: Int
    var timeDescription: String
}

@Observable
final class RoutineEngine {
    static let shared = RoutineEngine()
    
    var dismissedRoutineIds: Set<String> = []
    
    init() {}
    
    // MARK: - Normalization
    static func normalizeTaskTitle(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove parenthesized minutes like (25m), (30 mins), [45m]
        clean = clean.replacingOccurrences(of: #"\s*[\(\[][0-9]+\s*(m|min|mins|minutes|h|hr|hours)?[\)\]]"#, with: "", options: .regularExpression)
        
        // Remove trailing or leading duration words
        clean = clean.replacingOccurrences(of: #"(?i)\bfor\s+[0-9]+\s*(m|min|mins|minutes|h|hr|hours)?\b"#, with: "", options: .regularExpression)
        
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return raw }
        
        // Capitalize words nicely
        return clean.prefix(1).uppercased() + clean.dropFirst()
    }
    
    // MARK: - Mining Routine Patterns from Sessions
    func minePatterns(from sessions: [Session]) -> [RoutinePattern] {
        // Exclude schedule queries and incomplete entries
        let validSessions = sessions.filter {
            !($0.isScheduleQuery ?? false) &&
            ($0.startedAt != nil || $0.createdAt != nil)
        }
        
        guard !validSessions.isEmpty else { return [] }
        
        let calendar = Calendar.current
        
        // Group by normalized title
        var groups: [String: [Session]] = [:]
        for session in validSessions {
            let title = Self.normalizeTaskTitle(session.rawText)
            groups[title, default: []].append(session)
        }
        
        var patterns: [RoutinePattern] = []
        
        for (taskTitle, taskSessions) in groups {
            guard taskSessions.count >= 2 else { continue }
            
            // Check day-of-week distribution
            var weekdayMap: [Int: [Session]] = [:]
            for s in taskSessions {
                let wd = calendar.component(.weekday, from: s.timestamp)
                weekdayMap[wd, default: []].append(s)
            }
            
            // Check if there's a dominant weekday (e.g. Running on Saturdays)
            var foundWeeklyPattern = false
            for (weekday, wdSessions) in weekdayMap {
                let ratio = Double(wdSessions.count) / Double(taskSessions.count)
                // If at least 2 sessions on this specific weekday and >= 50% of total occurrences
                if wdSessions.count >= 2 && ratio >= 0.5 {
                    let (avgHour, avgMin) = computeAverageTime(of: wdSessions, calendar: calendar)
                    let avgDuration = computeAverageDuration(of: wdSessions)
                    let confidence = min(1.0, Double(wdSessions.count) / 3.0)
                    
                    let pattern = RoutinePattern(
                        id: "\(taskTitle)_weekday_\(weekday)",
                        taskTitle: taskTitle,
                        typicalMinutes: avgDuration,
                        typicalHour: avgHour,
                        typicalMinute: avgMin,
                        isDayOfWeekSpecific: true,
                        targetWeekday: weekday,
                        confidence: confidence,
                        occurrencesCount: wdSessions.count
                    )
                    patterns.append(pattern)
                    foundWeeklyPattern = true
                }
            }
            
            // If not dominated by a single weekday, check for Daily Pattern
            if !foundWeeklyPattern && taskSessions.count >= 2 {
                let (avgHour, avgMin) = computeAverageTime(of: taskSessions, calendar: calendar)
                let avgDuration = computeAverageDuration(of: taskSessions)
                
                // Check hour variance / consistency (within ~3 hours)
                let hours = taskSessions.map { calendar.component(.hour, from: $0.timestamp) }
                let minHour = hours.min() ?? avgHour
                let maxHour = hours.max() ?? avgHour
                
                if (maxHour - minHour) <= 3 || (24 - maxHour + minHour) <= 3 {
                    let confidence = min(1.0, Double(taskSessions.count) / 3.0)
                    let pattern = RoutinePattern(
                        id: "\(taskTitle)_daily_\(avgHour)",
                        taskTitle: taskTitle,
                        typicalMinutes: avgDuration,
                        typicalHour: avgHour,
                        typicalMinute: avgMin,
                        isDayOfWeekSpecific: false,
                        targetWeekday: nil,
                        confidence: confidence,
                        occurrencesCount: taskSessions.count
                    )
                    patterns.append(pattern)
                }
            }
        }
        
        return patterns.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Finding Active Suggestions
    func getActiveSuggestions(
        for date: Date = Date(),
        sessions: [Session]
    ) -> [RoutineSuggestion] {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentWeekday = calendar.component(.weekday, from: date)
        let currentTotalMinutes = currentHour * 60 + currentMinute
        
        let patterns = minePatterns(from: sessions)
        
        // Check which sessions have already been logged on the query date
        let dateSessions = sessions.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
        let loggedTitles = Set(dateSessions.map { Self.normalizeTaskTitle($0.rawText).lowercased() })
        
        var suggestions: [RoutineSuggestion] = []
        
        for pattern in patterns {
            if dismissedRoutineIds.contains(pattern.id) { continue }
            
            // If already completed on this date, don't nag
            if loggedTitles.contains(pattern.taskTitle.lowercased()) {
                continue
            }
            
            // Check day-of-week match
            if pattern.isDayOfWeekSpecific {
                guard let targetWeekday = pattern.targetWeekday, targetWeekday == currentWeekday else {
                    continue
                }
            }
            
            // Check time-of-day window (+/- 90 minutes from typical time)
            let patternTotalMinutes = pattern.typicalHour * 60 + pattern.typicalMinute
            let diff = abs(currentTotalMinutes - patternTotalMinutes)
            
            // Within 90 minutes
            if diff <= 90 || (diff <= 120 && pattern.confidence >= 0.8) {
                var comp = DateComponents()
                comp.hour = pattern.typicalHour
                comp.minute = pattern.typicalMinute
                let formattedTime = calendar.date(from: comp).map {
                    DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short)
                } ?? String(format: "%02d:%02d", pattern.typicalHour, pattern.typicalMinute)
                
                let headline: String
                let prompt: String
                
                if pattern.isDayOfWeekSpecific {
                    let dayName = calendar.weekdaySymbols[(currentWeekday - 1) % calendar.weekdaySymbols.count]
                    headline = "\(dayName.uppercased()) ROUTINE (\(formattedTime))"
                    prompt = "You usually \(pattern.taskTitle.lowercased()) on \(dayName)s around \(formattedTime). Ready to begin?"
                } else {
                    headline = "DAILY ROUTINE (\(formattedTime))"
                    prompt = "You usually log \(pattern.taskTitle.lowercased()) around \(formattedTime). Ready to start your \(pattern.typicalMinutes)m session?"
                }
                
                suggestions.append(RoutineSuggestion(
                    pattern: pattern,
                    headline: headline,
                    promptMessage: prompt,
                    recommendedMinutes: pattern.typicalMinutes,
                    timeDescription: formattedTime
                ))
            }
        }
        
        return suggestions
    }
    
    func dismiss(suggestionId: String) {
        dismissedRoutineIds.insert(suggestionId)
    }
    
    // MARK: - Notifications
    func requestNotificationAccessAndSync(sessions: [Session]) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            self.scheduleRoutineNotifications(sessions: sessions)
        }
    }
    
    func scheduleRoutineNotifications(sessions: [Session]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        let patterns = minePatterns(from: sessions)
        for pattern in patterns.prefix(5) {
            let content = UNMutableNotificationContent()
            content.title = "Tempo Routine"
            content.body = "Ready for your \(pattern.taskTitle) (\(pattern.typicalMinutes)m)?"
            content.sound = .default
            
            var dateComponents = DateComponents()
            dateComponents.hour = pattern.typicalHour
            dateComponents.minute = pattern.typicalMinute
            if pattern.isDayOfWeekSpecific, let wd = pattern.targetWeekday {
                dateComponents.weekday = wd
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "routine_\(pattern.id)",
                content: content,
                trigger: trigger
            )
            
            center.add(request)
        }
    }
    
    // MARK: - Helpers
    private func computeAverageTime(of sessions: [Session], calendar: Calendar) -> (hour: Int, minute: Int) {
        guard !sessions.isEmpty else { return (8, 0) }
        let totalMinutes = sessions.reduce(0) { sum, s in
            let h = calendar.component(.hour, from: s.timestamp)
            let m = calendar.component(.minute, from: s.timestamp)
            return sum + (h * 60 + m)
        }
        let avgMinutes = totalMinutes / sessions.count
        return (avgMinutes / 60, avgMinutes % 60)
    }
    
    private func computeAverageDuration(of sessions: [Session]) -> Int {
        let validMins = sessions.compactMap { $0.actualMinutes ?? $0.estimatedMinutes }.filter { $0 > 0 }
        guard !validMins.isEmpty else { return 25 }
        let avg = validMins.reduce(0, +) / validMins.count
        // Round to nearest 5m
        return max(5, ((avg + 2) / 5) * 5)
    }
}
