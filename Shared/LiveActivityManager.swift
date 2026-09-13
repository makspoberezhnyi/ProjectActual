import Foundation
import ActivityKit
import WidgetKit

public class LiveActivityManager {
    public static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TempoActivityAttributes>?
    
    public func startLiveActivity(taskTitle: String, estimatedMinutes: Int, startDate: Date) {
        // Sync widget snapshot
        WidgetDataStore.shared.startSession(title: taskTitle, minutes: estimatedMinutes)
        WidgetCenter.shared.reloadAllTimelines()
        
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
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
        
        for activity in Activity<TempoActivityAttributes>.activities {
            Task {
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        self.currentActivity = nil
    }
}
