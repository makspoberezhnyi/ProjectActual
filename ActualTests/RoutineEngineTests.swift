import XCTest
@testable import Actual

@MainActor
final class RoutineEngineTests: XCTestCase {
    
    func testDailyHabitMining() {
        let calendar = Calendar.current
        var sessions: [Session] = []
        
        // 5 consecutive days of "Breakfast" / "Eat" at 8:00 AM
        for dayOffset in 1...5 {
            var components = DateComponents()
            components.year = 2026
            components.month = 9
            components.day = 10 + dayOffset
            components.hour = 8
            components.minute = 5
            
            guard let date = calendar.date(from: components) else { continue }
            
            let session = Session(
                rawText: "Eat breakfast (25m)",
                estimatedMinutes: 25,
                startedAt: date,
                createdAt: date
            )
            session.endedAt = date.addingTimeInterval(25 * 60)
            session.actualMinutes = 25
            sessions.append(session)
        }
        
        let patterns = RoutineEngine.shared.minePatterns(from: sessions)
        XCTAssertFalse(patterns.isEmpty, "RoutineEngine should find at least one pattern")
        
        let eatPattern = patterns.first { $0.taskTitle.lowercased().contains("eat") }
        XCTAssertNotNil(eatPattern, "Should recognize Eat as a pattern")
        XCTAssertFalse(eatPattern!.isDayOfWeekSpecific, "Should be recognized as a daily pattern")
        XCTAssertEqual(eatPattern!.typicalHour, 8, "Typical hour should be 8:00 AM")
        XCTAssertEqual(eatPattern!.typicalMinutes, 25)
    }
    
    func testWeeklySaturdayRunningMining() {
        let calendar = Calendar.current
        var sessions: [Session] = []
        
        // 3 consecutive Saturdays of "Run" at 10:00 AM
        // September 2026: Sept 5 (Sat), Sept 12 (Sat), Sept 19 (Sat)
        let saturdayDays = [5, 12, 19]
        for day in saturdayDays {
            var components = DateComponents()
            components.year = 2026
            components.month = 9
            components.day = day
            components.hour = 10
            components.minute = 0
            
            guard let date = calendar.date(from: components) else { continue }
            
            let session = Session(
                rawText: "Morning Run",
                estimatedMinutes: 30,
                startedAt: date,
                createdAt: date
            )
            session.endedAt = date.addingTimeInterval(35 * 60)
            session.actualMinutes = 35
            sessions.append(session)
        }
        
        let patterns = RoutineEngine.shared.minePatterns(from: sessions)
        let runPattern = patterns.first { $0.taskTitle.lowercased().contains("run") }
        
        XCTAssertNotNil(runPattern, "Should recognize Run as a pattern")
        XCTAssertTrue(runPattern!.isDayOfWeekSpecific, "Should be recognized as a day-of-week pattern")
        XCTAssertEqual(runPattern!.targetWeekday, 7, "Target weekday should be Saturday (7)")
        XCTAssertEqual(runPattern!.typicalHour, 10, "Typical hour should be 10:00 AM")
    }
    
    func testActiveSuggestionsInTimeWindow() {
        let calendar = Calendar.current
        var sessions: [Session] = []
        
        // Setup past logs for Daily Eat at 8:00 AM on past days (Sept 1, 2, 3)
        for day in 1...3 {
            var components = DateComponents()
            components.year = 2026
            components.month = 9
            components.day = day
            components.hour = 8
            components.minute = 0
            
            guard let date = calendar.date(from: components) else { continue }
            
            let session = Session(
                rawText: "Eat (20m)",
                estimatedMinutes: 20,
                startedAt: date,
                createdAt: date
            )
            session.endedAt = date.addingTimeInterval(20 * 60)
            session.actualMinutes = 20
            sessions.append(session)
        }
        
        // Test query date on Sept 4 at 8:15 AM (where nothing is logged yet)
        var queryComponents = DateComponents()
        queryComponents.year = 2026
        queryComponents.month = 9
        queryComponents.day = 4
        queryComponents.hour = 8
        queryComponents.minute = 15
        let morningDate = calendar.date(from: queryComponents)!
        
        let suggestions = RoutineEngine.shared.getActiveSuggestions(for: morningDate, sessions: sessions)
        XCTAssertFalse(suggestions.isEmpty, "Should suggest Eat around 8:15 AM")
        XCTAssertEqual(suggestions.first?.pattern.taskTitle, "Eat")
        
        // Test query date at 15:00 PM on Sept 4 (should NOT trigger 8:00 AM suggestion)
        queryComponents.hour = 15
        queryComponents.minute = 0
        let afternoonDate = calendar.date(from: queryComponents)!
        let afternoonSuggestions = RoutineEngine.shared.getActiveSuggestions(for: afternoonDate, sessions: sessions)
        XCTAssertTrue(afternoonSuggestions.isEmpty, "Should not suggest Eat at 3:00 PM")
    }
    
    func testAlreadyCompletedTodayIgnored() {
        let calendar = Calendar.current
        var sessions: [Session] = []
        
        // Past logs on Sept 1, 2, 3
        for day in 1...3 {
            var components = DateComponents()
            components.year = 2026
            components.month = 9
            components.day = day
            components.hour = 8
            components.minute = 0
            
            guard let date = calendar.date(from: components) else { continue }
            let session = Session(rawText: "Breakfast (20m)", estimatedMinutes: 20, startedAt: date, createdAt: date)
            sessions.append(session)
        }
        
        // Add a session already logged on Sept 4
        var sept4Components = DateComponents(year: 2026, month: 9, day: 4, hour: 8, minute: 10)
        let sept4Date = calendar.date(from: sept4Components)!
        let completedToday = Session(rawText: "Breakfast (20m)", estimatedMinutes: 20, startedAt: sept4Date, createdAt: sept4Date)
        completedToday.endedAt = sept4Date.addingTimeInterval(20 * 60)
        sessions.append(completedToday)
        
        let suggestions = RoutineEngine.shared.getActiveSuggestions(for: sept4Date, sessions: sessions)
        XCTAssertTrue(suggestions.isEmpty, "Already completed breakfast on query date should not be prompted again")
    }
}
