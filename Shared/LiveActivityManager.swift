import Foundation
import ActivityKit
import WidgetKit

@MainActor
final public class LiveActivityManager: Sendable {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TempoActivityAttributes>?
    
    private func terminateActivities(ids: Set<String>? = nil, finalState: TempoActivityAttributes.ContentState? = nil) {
        let state = finalState
        Task {
            for activity in Activity<TempoActivityAttributes>.activities {
                if let ids, !ids.contains(activity.id) {
                    continue
                }
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
        
        let areEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("[LiveActivityManager] areActivitiesEnabled: \(areEnabled)")
        guard areEnabled else {
            print("[LiveActivityManager] Live Activities are currently disabled in system settings.")
            return
        }
        
        // 2. End any existing activities first by capturing existing IDs
        let existingIds = Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        if !existingIds.isEmpty {
            terminateActivities(ids: existingIds)
        }
        
        let attributes = TempoActivityAttributes(
            taskTitle: taskTitle,
            startDate: startDate,
            isLinkedToCalendar: isLinkedToCalendar,
            isLinkedToReminders: isLinkedToReminders
        )
        let initialContentState = TempoActivityAttributes.ContentState(
            estimatedMinutes: estimatedMinutes,
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
            print("[LiveActivityManager] Successfully started Live Activity: \(activity.id)")
        } catch {
            print("[LiveActivityManager] Failed to start Live Activity: \(error)")
        }
    }
    
    public func updateLiveActivity(estimatedMinutes: Int, statusMessage: String? = nil) {
        WidgetDataStore.shared.extendActiveSession(by: estimatedMinutes)
        WidgetCenter.shared.reloadAllTimelines()
        
        Task {
            for activity in Activity<TempoActivityAttributes>.activities {
                let updatedState = TempoActivityAttributes.ContentState(
                    estimatedMinutes: estimatedMinutes,
                    actualMinutes: 0,
                    isRunning: true,
                    statusMessage: statusMessage
                )
                await activity.update(ActivityContent(state: updatedState, staleDate: nil))
            }
        }
    }
    
    public func endLiveActivity(actualMinutes: Int) {
        // Sync widget snapshot
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        
        terminateActivities()
        self.currentActivity = nil
    }
    
    public func cancelAllLiveActivities() {
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        
        terminateActivities()
        self.currentActivity = nil
    }
}
