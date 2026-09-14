import Foundation
import ActivityKit
import WidgetKit

@MainActor
final public class LiveActivityManager: Sendable {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TempoActivityAttributes>?
    
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
        let existingActivities = Activity<TempoActivityAttributes>.activities
        Task { @MainActor in
            for act in existingActivities {
                await act.end(nil, dismissalPolicy: .immediate)
            }
        }
        
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
        
        let activitiesToEnd = Activity<TempoActivityAttributes>.activities
        Task { @MainActor in
            for activity in activitiesToEnd {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        self.currentActivity = nil
    }
    
    public func cancelAllLiveActivities() {
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        
        let activitiesToEnd = Activity<TempoActivityAttributes>.activities
        Task { @MainActor in
            for activity in activitiesToEnd {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }
}
