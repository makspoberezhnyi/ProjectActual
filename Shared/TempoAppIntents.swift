import AppIntents
import Foundation
import WidgetKit
import ActivityKit

public struct StartFocusIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start Focus Session"
    public static var description = IntentDescription("Starts a focus session with a specified task and duration.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Task Title", default: "Deep Work")
    public var taskTitle: String
    
    @Parameter(title: "Minutes", default: 25)
    public var minutes: Int
    
    public init() {}
    
    public init(taskTitle: String, minutes: Int) {
        self.taskTitle = taskTitle
        self.minutes = minutes
    }
    
    public func perform() async throws -> some IntentResult {
        let now = Date()
        
        // End any existing activities first
        for activity in Activity<TempoActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        WidgetDataStore.shared.startSession(title: taskTitle, minutes: minutes, startDate: now)
        
        // Start Live Activity
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = TempoActivityAttributes(
                taskTitle: taskTitle,
                estimatedMinutes: minutes,
                startDate: now
            )
            let initialContent = TempoActivityAttributes.ContentState(
                actualMinutes: 0,
                isRunning: true
            )
            _ = try? Activity<TempoActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContent, staleDate: nil),
                pushType: nil
            )
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

public struct StopFocusIntent: AppIntent {
    public static var title: LocalizedStringResource = "Stop Focus Session"
    public static var description = IntentDescription("Stops the active focus timer.")
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        let currentSnapshot = WidgetDataStore.shared.loadSnapshot()
        var elapsed = 0
        if let start = currentSnapshot.activeTaskStartedAt {
            elapsed = max(1, Int(Date().timeIntervalSince(start) / 60))
        }
        
        WidgetDataStore.shared.stopActiveSession()
        
        let finalState = TempoActivityAttributes.ContentState(
            actualMinutes: elapsed,
            isRunning: false
        )
        
        // End all active Live Activities immediately
        for activity in Activity<TempoActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - SIRI & APPLE INTELLIGENCE SHORTCUTS PROVIDER
public struct TempoShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Start focus session in \(.applicationName)",
                "Start timer in \(.applicationName)",
                "Begin focus in \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: StopFocusIntent(),
            phrases: [
                "Stop focus in \(.applicationName)",
                "Finish focus in \(.applicationName)",
                "Stop timer in \(.applicationName)",
                "End session in \(.applicationName)"
            ],
            shortTitle: "Stop Focus",
            systemImageName: "stop.circle.fill"
        )
    }
    
    public static var shortcutTileColor: ShortcutTileColor = .teal
}
