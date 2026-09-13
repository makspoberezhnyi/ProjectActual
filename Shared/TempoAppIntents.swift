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
        WidgetDataStore.shared.startSession(title: taskTitle, minutes: minutes)
        
        // Start Live Activity
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let attributes = TempoActivityAttributes(
                taskTitle: taskTitle,
                estimatedMinutes: minutes,
                startDate: Date()
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
        WidgetDataStore.shared.stopActiveSession()
        
        // End all active Live Activities immediately
        for activity in Activity<TempoActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
