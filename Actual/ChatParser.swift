import Foundation

enum IntegrationTarget: String, Codable {
    case calendar = "calendar"
    case reminders = "reminders"
    case both = "both"
}

struct ParsedIntent {
    var text: String
    var estimatedMinutes: Int?
    var isRetroactive: Bool
    var isStopCommand: Bool
    var isSuggestionRequest: Bool
    var isScheduleCheck: Bool
    var integrationTarget: IntegrationTarget?
}

final class ChatParser {
    static func extractMinutes(from input: String) -> Int? {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Match pure digits like "25", "45", "60", "120"
        if let plainNum = Int(text), plainNum > 0 && plainNum <= 720 {
            return plainNum
        }
        
        // Match duration patterns like "25m", "30 min", "1h", "1.5 hours", "45 mins"
        let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*(m|min|mins|minute|minutes|h|hr|hrs|hour|hours)")
        if let match = regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let numRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text) {
                let num = Double(text[numRange]) ?? 0
                let unit = String(text[unitRange])
                if unit.starts(with: "h") {
                    return Int(num * 60)
                } else {
                    return Int(num)
                }
            }
        }
        return nil
    }
    
    static func isDurationOnly(_ input: String) -> Bool {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if extractMinutes(from: text) != nil {
            let stripped = text
                .replacingOccurrences(of: "minutes", with: "")
                .replacingOccurrences(of: "minute", with: "")
                .replacingOccurrences(of: "mins", with: "")
                .replacingOccurrences(of: "min", with: "")
                .replacingOccurrences(of: "hours", with: "")
                .replacingOccurrences(of: "hour", with: "")
                .replacingOccurrences(of: "hrs", with: "")
                .replacingOccurrences(of: "hr", with: "")
                .replacingOccurrences(of: "h", with: "")
                .replacingOccurrences(of: "m", with: "")
                .replacingOccurrences(of: "for", with: "")
                .replacingOccurrences(of: "about", with: "")
                .replacingOccurrences(of: "around", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .filter { !$0.isNumber && $0 != "." && !$0.isWhitespace }
            return stripped.isEmpty
        }
        return false
    }
    
    static func detectIntegrationTarget(_ input: String) -> IntegrationTarget {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCal = text.contains("cal") || text.contains("event") || text.contains("meeting")
        let hasRem = text.contains("remind") || text.contains("task") || text.contains("todo") || text.contains("to-do")
        
        if hasCal && hasRem {
            return .both
        } else if hasCal {
            return .calendar
        } else if hasRem {
            return .reminders
        } else {
            return .both
        }
    }
    
    static func isCalendarOrScheduleQuery(_ input: String) -> Bool {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = [
            "calendar", "check calendar", "my calendar", "events", "show events", "what's on my calendar",
            "reminders", "check reminders", "my reminders", "tasks", "my tasks", "check tasks", "todo", "to-do",
            "schedule", "check schedule", "what's on my schedule", "what's my schedule", "agenda",
            "what's next", "what next", "what to do", "suggest", "suggestions", "what should i do"
        ]
        if keywords.contains(text) { return true }
        if text.contains("calendar") || text.contains("reminder") || text.contains("schedule") || text.contains("task") || text.contains("event") {
            if text.contains("check") || text.contains("show") || text.contains("what") || text.contains("open") || text.contains("view") || text.contains("get") || text.contains("list") || text.contains("my") || text.contains("please") {
                return true
            }
        }
        return false
    }
    
    static func parse(_ input: String) -> ParsedIntent {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text == "stop" || text == "done" || text == "finish" || text == "finished" || text == "end" {
            return ParsedIntent(text: input, estimatedMinutes: nil, isRetroactive: false, isStopCommand: true, isSuggestionRequest: false, isScheduleCheck: false, integrationTarget: nil)
        }
        
        if isCalendarOrScheduleQuery(input) {
            let target = detectIntegrationTarget(input)
            return ParsedIntent(text: input, estimatedMinutes: nil, isRetroactive: false, isStopCommand: false, isSuggestionRequest: false, isScheduleCheck: true, integrationTarget: target)
        }
        
        let minutes = extractMinutes(from: text)
        let isRetro = text.contains("did") || text.contains("just") || text.contains("completed")
        return ParsedIntent(text: input, estimatedMinutes: minutes, isRetroactive: isRetro, isStopCommand: false, isSuggestionRequest: false, isScheduleCheck: false, integrationTarget: nil)
    }
}
