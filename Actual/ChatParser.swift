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
    var isConversational: Bool = false
    var conversationalReply: String? = nil
    var isTravelQuery: Bool = false
    var destinationQuery: String? = nil
    var isNextMeetingTravel: Bool = false
    var travelTransportMode: TravelTransportMode? = nil
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
    
    // MARK: - Travel & Ride Query Parsing
    static func detectTransportMode(from input: String) -> TravelTransportMode? {
        let lower = input.lowercased()
        
        // 1. City Transport / Transit
        if lower.contains("transit") || lower.contains("public transport") || lower.contains("city transport") ||
           lower.contains("by train") || lower.contains("by bus") || lower.contains("by metro") ||
           lower.contains("by subway") || lower.contains("by tram") || lower.contains("subway") ||
           lower.contains("tram") || lower.contains("train") || lower.contains("bus") {
            return .transit
        }
        
        // 2. Walking / By Feet
        if lower.contains("by feet") || lower.contains("on foot") || lower.contains("by foot") ||
           lower.contains("walking") || lower.contains("walk") || lower.contains("by walking") ||
           lower.contains("pedestrian") {
            return .walking
        }
        
        // 3. Cycling / Bicycle
        if lower.contains("by bike") || lower.contains("by bicycle") || lower.contains("cycling") ||
           lower.contains("bicycle") || lower.contains("bike") {
            return .cycling
        }
        
        // 4. Car / Driving
        if lower.contains("by car") || lower.contains("drive") || lower.contains("driving") ||
           lower.contains("ride") || lower.contains("car") || lower.contains("cab") ||
           lower.contains("taxi") || lower.contains("uber") {
            return .driving
        }
        
        return nil
    }

    static func cleanDestinationString(_ input: String) -> String {
        var text = input.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,:; "))
        
        let transportPhrases = [
            "by city transport", "by public transport", "by public transit", "by transit",
            "by feet", "by foot", "on foot", "by walking",
            "by train", "by bus", "by subway", "by metro", "by tram",
            "by bicycle", "by bike", "by cycling",
            "by car", "by automobile", "by cab", "by taxi", "by uber"
        ]
        
        for phrase in transportPhrases {
            let pattern = "(?i)\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern) {
                text = regex.stringByReplacingMatches(
                    in: text,
                    range: NSRange(text.startIndex..., in: text),
                    withTemplate: ""
                ).trimmingCharacters(in: CharacterSet(charactersIn: "?!.,:; "))
            }
        }
        
        return text.isEmpty ? input : text
    }

    static func parseTravelQueryFull(_ input: String) -> (isTravel: Bool, destination: String?, isNextMeeting: Bool, transportMode: TravelTransportMode?) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let detectedMode = detectTransportMode(from: input)
        
        // Check if query is asking about the next meeting/event
        if lower.contains("next meeting") || lower.contains("next event") || lower.contains("my meeting") || lower.contains("my event") || lower.contains("calendar event") {
            if lower.contains("how long") || lower.contains("travel") || lower.contains("drive") || lower.contains("ride") || lower.contains("walk") || lower.contains("transit") || lower.contains("eta") || lower.contains("directions") || lower.contains("time") || lower.contains("get to") {
                return (true, nil, true, detectedMode)
            }
        }
        
        // Pure generic questions without destination -> check next meeting
        let genericTravelPhrases = [
            "how long the ride can take", "how long is the ride", "how long will the ride take",
            "how long does the ride take", "how long the ride", "how long is the drive",
            "how long does it take to drive", "how long to drive", "how long to get there",
            "what is the travel time", "travel time", "driving time", "commute time",
            "how long by transit", "how long to walk", "how long by feet"
        ]
        for phrase in genericTravelPhrases {
            if lower == phrase || lower == "\(phrase)?" || lower == "\(phrase)!" {
                return (true, nil, true, detectedMode)
            }
        }
        
        // Regex patterns to extract destination from natural phrasing
        let patterns: [String] = [
            // "How long / How much time [any conversational words] to go to / to get to / to drive to / to [Destination]"
            "^how\\s+(?:long|much\\s+time)\\b.*?(?:to\\s+go\\s+to|to\\s+get\\s+to|to\\s+drive\\s+to|to\\s+ride\\s+to|to\\s+walk\\s+to|to\\s+cycle\\s+to|to\\s+reach|to\\s+commute\\s+to|to\\s+travel\\s+to|by\\s+(?:car|transit|train|bus|feet|foot|bike|bicycle)\\s+to|to|for)\\s+(.+)$",
            // "I want to get to / go to / need to get to / wanna get to..."
            "^(?:i\\s+)?(?:want\\s+to|wanna|need\\s+to|'d\\s+like\\s+to|would\\s+like\\s+to)\\s+(?:get\\s+to|go\\s+to|reach|drive\\s+to|travel\\s+to|ride\\s+to|walk\\s+to|head\\s+to)\\s+(.+)$",
            // "How do I get to / How can I get to / How to get to..."
            "^how\\s+(?:do\\s+i|can\\s+i|to)\\s+(?:get\\s+to|go\\s+to|reach|drive\\s+to|walk\\s+to|navigate\\s+to)\\s+(.+)$",
            // "Take me to / Navigate to / Directions to / Route to / Drive to / Ride to / Walk to / Head to..."
            "^(?:take\\s+me\\s+to|navigate\\s+to|directions\\s+to|direction\\s+to|route\\s+to|drive\\s+to|ride\\s+to|walk\\s+to|commute\\s+to|travel\\s+to|head\\s+to)\\s+(.+)$",
            // "How far [is it / from here] to [Destination]"
            "^how\\s+far\\b.*?(?:to\\s+go\\s+to|to\\s+get\\s+to|to|for)\\s+(.+)$",
            // "Travel time to / Drive time to / Driving time to / ETA to / ETA for..."
            "^(?:travel\\s+time|drive\\s+time|driving\\s+time|commute\\s+time|ride\\s+time|walking\\s+time|walk\\s+time|transit\\s+time|eta)\\b.*?(?:to|for)\\s+(.+)$",
            // "Heading to / Going to / Destination: ..."
            "^(?:heading\\s+to|going\\s+to|destination:?)\\s+(.+)$",
            // "Where is / Where's ..."
            "^(?:where\\s+is|where's)\\s+(.+)$"
        ]
        
        let genericTaskWords = ["work", "sleep", "study", "code", "focus", "read", "exercise", "eat", "rest", "break"]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "?!.,:; "))
                
                if !extracted.isEmpty {
                    let cleaned = cleanDestinationString(extracted)
                    let lowerExtracted = cleaned.lowercased()
                    if lowerExtracted.contains("next meeting") || lowerExtracted.contains("next event") {
                        return (true, nil, true, detectedMode)
                    }
                    if !genericTaskWords.contains(lowerExtracted) {
                        return (true, cleaned, false, detectedMode)
                    }
                }
            }
        }
        
        // Substring fallback for travel indicators
        let travelIndicators = [
            "how long the ride", "how long is the ride", "how long will the ride", "how long ride",
            "how long to drive", "how long is the drive", "how long does it take to drive", "how long to get to",
            "how long does it take to get to", "how long will it take to get to", "how long will it take to drive to",
            "how long to walk to", "how long is the walk to", "how long to commute to",
            "travel time to", "driving time to", "drive time to", "time to drive to", "walking time to",
            "transit time to", "eta to", "eta for", "directions to", "how far to", "how long to reach",
            "want to get to", "want to go to", "need to get to", "need to go to", "take me to", "navigate to"
        ]
        
        for indicator in travelIndicators {
            if lower.contains(indicator) {
                if let range = lower.range(of: indicator) {
                    let suffix = String(text[range.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "?!.,:; "))
                    var cleanSuffix = suffix.hasPrefix("to ") ? String(suffix.dropFirst(3)).trimmingCharacters(in: .whitespaces) : suffix
                    cleanSuffix = cleanDestinationString(cleanSuffix)
                    if !cleanSuffix.isEmpty {
                        return (true, cleanSuffix, false, detectedMode)
                    }
                }
                return (true, nil, true, detectedMode)
            }
        }
        
        return (false, nil, false, nil)
    }

    static func parseTravelQuery(_ input: String) -> (isTravel: Bool, destination: String?, isNextMeeting: Bool) {
        let res = parseTravelQueryFull(input)
        return (res.isTravel, res.destination, res.isNextMeeting)
    }
    
    static func parse(_ input: String, sessions: [Session] = []) -> ParsedIntent {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Stop / Done commands
        if text == "stop" || text == "done" || text == "finish" || text == "finished" || text == "end" {
            return ParsedIntent(text: input, estimatedMinutes: nil, isRetroactive: false, isStopCommand: true, isSuggestionRequest: false, isScheduleCheck: false, integrationTarget: nil)
        }
        
        // 2. Travel & Ride ETA questions
        let travelInfo = parseTravelQueryFull(input)
        if travelInfo.isTravel {
            return ParsedIntent(
                text: input,
                estimatedMinutes: nil,
                isRetroactive: false,
                isStopCommand: false,
                isSuggestionRequest: false,
                isScheduleCheck: false,
                integrationTarget: nil,
                isConversational: false,
                isTravelQuery: true,
                destinationQuery: travelInfo.destination,
                isNextMeetingTravel: travelInfo.isNextMeeting,
                travelTransportMode: travelInfo.transportMode
            )
        }
        
        // 3. Calendar & Reminders Schedule Queries
        if isCalendarOrScheduleQuery(input) {
            let target = detectIntegrationTarget(input)
            return ParsedIntent(text: input, estimatedMinutes: nil, isRetroactive: false, isStopCommand: false, isSuggestionRequest: false, isScheduleCheck: true, integrationTarget: target)
        }
        
        // 4. Conversational Small Talk (Greetings, "what's up", "who are you", motivation, stats)
        if let convo = TempoConvoEngine.matchConversationalIntent(input, sessions: sessions) {
            return ParsedIntent(
                text: input,
                estimatedMinutes: nil,
                isRetroactive: false,
                isStopCommand: false,
                isSuggestionRequest: false,
                isScheduleCheck: false,
                integrationTarget: nil,
                isConversational: true,
                conversationalReply: convo.replyText
            )
        }
        
        // 5. Standard Task Entry
        let minutes = extractMinutes(from: text)
        let isRetro = text.contains("did") || text.contains("just") || text.contains("completed")
        return ParsedIntent(
            text: input,
            estimatedMinutes: minutes,
            isRetroactive: isRetro,
            isStopCommand: false,
            isSuggestionRequest: false,
            isScheduleCheck: false,
            integrationTarget: nil
        )
    }
}

