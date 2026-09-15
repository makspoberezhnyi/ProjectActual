import AppIntents
import Foundation
import WidgetKit
import ActivityKit

public struct StartFocusIntent: LiveActivityIntent, AppIntent {
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
        
        // 1. End any existing activities first with terminal state and immediate dismissal
        let finalState = TempoActivityAttributes.ContentState(
            estimatedMinutes: 0,
            actualMinutes: 0,
            isRunning: false,
            statusMessage: "Done"
        )
        let finalContent = ActivityContent(state: finalState, staleDate: nil)
        for activity in Activity<TempoActivityAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // 2. Persist to AppGroup WidgetDataStore
        WidgetDataStore.shared.startSession(title: taskTitle, minutes: minutes, startDate: now)
        
        // 3. Start Live Activity on Dynamic Island & Lock Screen
        let attributes = TempoActivityAttributes(
            taskTitle: taskTitle,
            startDate: now
        )
        let initialContent = TempoActivityAttributes.ContentState(
            estimatedMinutes: minutes,
            actualMinutes: 0,
            isRunning: true
        )
        do {
            let activity = try Activity<TempoActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContent, staleDate: nil),
                pushType: nil
            )
            print("[StartFocusIntent] Started Live Activity: \(activity.id)")
        } catch {
            print("[StartFocusIntent] Failed to start Live Activity: \(error)")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        return .result()
    }
}

public struct ExtendFocusIntent: LiveActivityIntent, AppIntent {
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

public struct StopFocusIntent: LiveActivityIntent, AppIntent {
    public static let title: LocalizedStringResource = "Stop Focus Session"
    public static let description = IntentDescription("Stops the active focus timer.")
    public static let openAppWhenRun: Bool = false
    
    @Parameter(title: "Activity ID")
    public var activityId: String?
    
    public init() {
        self.activityId = nil
    }
    
    public init(activityId: String?) {
        self.activityId = activityId
    }
    
    public func perform() async throws -> some IntentResult {
        WidgetDataStore.shared.stopActiveSession()
        
        let completionState = TempoActivityAttributes.ContentState(
            estimatedMinutes: 0,
            actualMinutes: 0,
            isRunning: false,
            statusMessage: "Completed ✓"
        )
        let finalContent = ActivityContent(state: completionState, staleDate: nil)
        
        let targetId = activityId
        // 1. First broadcast the completion state to show the bouncy checkmark & confirmation UI
        for activity in Activity<TempoActivityAttributes>.activities {
            if targetId == nil || activity.id == targetId {
                await activity.update(finalContent)
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        
        // 2. Allow 550ms for the visual confirmation animation to celebrate the finished session
        try? await Task.sleep(nanoseconds: 550_000_000)
        
        // 3. Immediately dismiss the Live Activity
        for activity in Activity<TempoActivityAttributes>.activities {
            if targetId == nil || activity.id == targetId {
                await activity.end(finalContent, dismissalPolicy: .immediate)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        for activity in Activity<TempoActivityAttributes>.activities {
            await activity.end(finalContent, dismissalPolicy: .immediate)
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
