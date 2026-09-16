import Foundation
import ActivityKit
import WidgetKit

@MainActor
final public class LiveActivityManager: Sendable {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TempoActivityAttributes>?
    
    private func terminateActivities(ids: Set<String>? = nil, finalState: TempoActivityAttributes.ContentState? = nil) {
        let targetIds = ids ?? Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        guard !targetIds.isEmpty else { return }
        
        let state = finalState ?? TempoActivityAttributes.ContentState(
            estimatedMinutes: 0,
            actualMinutes: 0,
            isRunning: false,
            statusMessage: "Done"
        )
        let finalContent = ActivityContent(state: state, staleDate: nil)
        Task {
            for activity in Activity<TempoActivityAttributes>.activities {
                if targetIds.contains(activity.id) {
                    await activity.end(finalContent, dismissalPolicy: .immediate)
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
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        
        let areEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("[LiveActivityManager] areActivitiesEnabled: \(areEnabled)")
        guard areEnabled else {
            print("[LiveActivityManager] Live Activities are currently disabled in system settings.")
            return
        }
        
        // 2. End any existing activities first (capture IDs synchronously before requesting the new activity)
        let existingIds = Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        if !existingIds.isEmpty {
            Task { @MainActor in
                for activity in Activity<TempoActivityAttributes>.activities where existingIds.contains(activity.id) {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
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
        WidgetDataStore.shared.updateActiveSessionEstimate(to: estimatedMinutes)
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        
        Task { @MainActor in
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
        WidgetDataStore.shared.stopActiveSession(actualMinutes: actualMinutes)
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        
        let completionState = TempoActivityAttributes.ContentState(
            estimatedMinutes: 0,
            actualMinutes: actualMinutes,
            isRunning: false,
            statusMessage: "Done"
        )
        let finalContent = ActivityContent(state: completionState, staleDate: nil)
        
        let targetIds = Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        guard !targetIds.isEmpty else {
            self.currentActivity = nil
            return
        }
        
        Task { @MainActor in
            for activity in Activity<TempoActivityAttributes>.activities where targetIds.contains(activity.id) {
                await activity.end(finalContent, dismissalPolicy: .immediate)
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }
    
    public func cancelAllLiveActivities() {
        WidgetDataStore.shared.stopActiveSession()
        WidgetCenter.shared.reloadAllTimelines()
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
        
        let targetIds = Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        guard !targetIds.isEmpty else {
            self.currentActivity = nil
            return
        }
        
        Task { @MainActor in
            for activity in Activity<TempoActivityAttributes>.activities where targetIds.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }
}
