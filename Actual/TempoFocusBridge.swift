import Foundation
import ActivityKit
import WidgetKit

/// Mirrors the Focus timer (TimeOSStore) out to the widgets, the Live Activity and the Apple Watch.
///
/// The Focus timer is the single source of truth for "what am I doing right now".
/// Widgets, Siri, the Live Activity buttons and the watch only leave notes in the shared
/// WidgetDataStore; TimeOSStore.reconcileExternalSessions reads those notes back in.
@MainActor
enum TempoFocusBridge {

    /// Publishes the running timer. `effectiveStart` is when the timer would have started
    /// had it never been paused, so every surface can count down from the same anchor.
    static func publishRunning(title: String, targetMinutes: Int, effectiveStart: Date) {
        var snapshot = WidgetDataStore.shared.loadSnapshot()
        snapshot.isRunning = true
        snapshot.activeTaskTitle = title
        snapshot.activeTaskEstimatedMinutes = targetMinutes
        snapshot.activeTaskStartedAt = effectiveStart
        snapshot.lastCompletedAt = nil
        snapshot.lastCompletedMinutes = nil
        snapshot.lastCompletedTitle = nil
        WidgetDataStore.shared.saveSnapshot(snapshot)
        reloadWidgets()

        upsertLiveActivity(title: title, targetMinutes: targetMinutes, effectiveStart: effectiveStart)

        if watchSyncEnabled {
            WatchConnectivityManager.shared.syncActiveSession(
                title: title,
                estimatedMinutes: targetMinutes,
                startDate: effectiveStart
            )
        }
    }

    /// Publishes "nothing running" (paused, reset, or finished). `completedMinutes` is set only
    /// when a block was actually logged, so the widget can show its little "done" state.
    static func publishStopped(completedTitle: String? = nil, completedMinutes: Int? = nil) {
        var snapshot = WidgetDataStore.shared.loadSnapshot()
        snapshot.isRunning = false
        snapshot.activeTaskTitle = nil
        snapshot.activeTaskEstimatedMinutes = nil
        snapshot.activeTaskStartedAt = nil
        if let completedMinutes {
            snapshot.lastCompletedAt = Date()
            snapshot.lastCompletedMinutes = completedMinutes
            snapshot.lastCompletedTitle = completedTitle
        }
        WidgetDataStore.shared.saveSnapshot(snapshot)
        reloadWidgets()

        endLiveActivities()

        if watchSyncEnabled {
            WatchConnectivityManager.shared.syncSessionStopped(actualMinutes: completedMinutes ?? 0)
        }
    }

    // MARK: - Live Activity

    private static func upsertLiveActivity(title: String, targetMinutes: Int, effectiveStart: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TempoActivityAttributes.ContentState(
            estimatedMinutes: targetMinutes,
            actualMinutes: 0,
            isRunning: true
        )
        let activities = Activity<TempoActivityAttributes>.activities
        let matching = activities.filter {
            $0.attributes.taskTitle == title
                && abs($0.attributes.startDate.timeIntervalSince(effectiveStart)) < 3
        }

        if !matching.isEmpty {
            // Same block: only the target moved (+5 min), so update in place.
            let ids = Set(matching.map(\.id))
            Task {
                for activity in Activity<TempoActivityAttributes>.activities where ids.contains(activity.id) {
                    await activity.update(ActivityContent(state: state, staleDate: nil))
                }
            }
            return
        }

        // A different block (new task, or resumed after a pause): replace the activity.
        let staleIDs = Set(activities.map(\.id))
        Task {
            for activity in Activity<TempoActivityAttributes>.activities where staleIDs.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        let attributes = TempoActivityAttributes(taskTitle: title, startDate: effectiveStart)
        _ = try? Activity<TempoActivityAttributes>.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    private static func endLiveActivities() {
        let ids = Set(Activity<TempoActivityAttributes>.activities.map(\.id))
        guard !ids.isEmpty else { return }
        Task {
            for activity in Activity<TempoActivityAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Helpers

    static var watchSyncEnabled: Bool {
        UserDefaults.standard.object(forKey: "integration_watch_enabled") as? Bool ?? true
    }

    private static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
