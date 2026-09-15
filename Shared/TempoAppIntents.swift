import AppIntents
import Foundation
import WidgetKit
import ActivityKit

public struct StartFocusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Focus Session"
    public static let description = IntentDescription("Starts a focus session with a specified task and duration.")
    public static let openAppWhenRun: Bool = false
    
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
                startDate: now
            )
            let initialContent = TempoActivityAttributes.ContentState(
                estimatedMinutes: minutes,
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

public struct ExtendFocusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Extend Focus Session"
    public static let description = IntentDescription("Extends the active focus session by a number of minutes.")
    public static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Minutes to Add", default: 5)
    public var minutesToAdd: Int
    
    public init() {}
    
    public init(minutesToAdd: Int) {
        self.minutesToAdd = minutesToAdd
    }
    
    public func perform() async throws -> some IntentResult {
        WidgetDataStore.shared.extendActiveSession(by: minutesToAdd)
        let updatedSnapshot = WidgetDataStore.shared.loadSnapshot()
        let newEstimate = updatedSnapshot.activeTaskEstimatedMinutes ?? 30
        
        for activity in Activity<TempoActivityAttributes>.activities {
            let updatedState = TempoActivityAttributes.ContentState(
                estimatedMinutes: newEstimate,
                actualMinutes: 0,
                isRunning: true,
                statusMessage: "+\(minutesToAdd)m"
            )
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        return .result()
    }
}

public struct StopFocusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Stop Focus Session"
    public static let description = IntentDescription("Stops the active focus timer.")
    public static let openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        WidgetDataStore.shared.stopActiveSession()
        
        // End all active Live Activities immediately with nil so they dismiss from screen instantly
        for activity in Activity<TempoActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
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
    
    public static let shortcutTileColor: ShortcutTileColor = .teal
}
