import Foundation
import ActivityKit
import WidgetKit

@MainActor
final public class LiveActivityManager: Sendable {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TempoActivityAttributes>?
    
    private func terminateActivities(finalState: TempoActivityAttributes.ContentState? = nil) {
        let state = finalState
        Task {
            for activity in Activity<TempoActivityAttributes>.activities {
                if let state {
                    await activity.end(
                        ActivityContent(state: state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                } else {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
    }
    
    public func startLiveActivity(
        taskTitle: String,
        estimatedMinutes: Int,
        startDate: Date,
        linkedEventIdentifier: String? = nil,
        isLinkedToCalendar: Bool? = nil,
        isLinkedToReminders: Bool? = nil
    ) {
        // 1. Sync widget snapshot & pending session with exact start date & metadata
        WidgetDataStore.shared.startSession(
            title: taskTitle,
            minutes: estimatedMinutes,
            startDate: startDate,
            linkedEventIdentifier: linkedEventIdentifier,
            isLinkedToCalendar: isLinkedToCalendar,
            isLinkedToReminders: isLinkedToReminders
        )
        WidgetCenter.shared.reloadAllTimelines()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // 2. End any existing activities first to prevent duplicates or ghost states
        terminateActivities()
        
        let attributes = TempoActivityAttributes(
            taskTitle: taskTitle,
            estimatedMinutes: estimatedMinutes,
            startDate: startDate
        )
        let initialContentState = TempoActivityAttributes.ContentState(
            actualMinutes: 0,
            isRunning: true
        )
        
        do {
            let activity = try Activity<TempoActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    public func endLiveActivity(actualMinutes: Int) {
        // Sync widget snapshot
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        
        let finalState = TempoActivityAttributes.ContentState(
            actualMinutes: actualMinutes,
            isRunning: false
        )
        
        terminateActivities(finalState: finalState)
        self.currentActivity = nil
    }
    
    public func cancelAllLiveActivities() {
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        
        terminateActivities()
        self.currentActivity = nil
    }
}
