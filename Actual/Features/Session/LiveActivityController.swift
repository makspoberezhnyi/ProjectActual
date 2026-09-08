import Foundation
import os
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Puts the running session on the lock screen and in the Dynamic Island.
///
/// Often the very first thing someone sees without unlocking their phone at all, which
/// is the point: the product is meant to work without opening the app.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private let log = Logger(subsystem: "app.actual.Actual", category: "liveactivity")

    private init() {}

    #if canImport(ActivityKit)
    private var current: Activity<SessionActivityAttributes>?
    #endif

    func start(sessionID: UUID, title: String, contextTag: String, startedAt: Date, expectedMinutes: Int?) {
        reloadWidgets()

        #if canImport(ActivityKit)
        // Off in Settings, or unsupported: the app carries on exactly as before. A live
        // activity is a convenience on top of the session, never the session itself.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("live activities are disabled for this app")
            return
        }
        endActivity()

        let attributes = SessionActivityAttributes(
            sessionID: sessionID.uuidString, title: title, contextTag: contextTag
        )
        let state = SessionActivityAttributes.ContentState(
            startedAt: startedAt, expectedMinutes: expectedMinutes
        )

        do {
            current = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
            log.notice("started live activity for \(title)")
        } catch {
            log.error("could not start live activity: \(error.localizedDescription)")
        }
        #endif
    }

    /// Used when a trip's real departure is detected, so the lock screen counts driving
    /// time rather than time since the tap.
    func update(startedAt: Date, expectedMinutes: Int?) {
        #if canImport(ActivityKit)
        guard let current else { return }
        Task {
            await current.update(
                ActivityContent(
                    state: .init(startedAt: startedAt, expectedMinutes: expectedMinutes),
                    staleDate: nil
                )
            )
        }
        #endif
    }

    func stop() {
        endActivity()
        reloadWidgets()
    }

    private func endActivity() {
        #if canImport(ActivityKit)
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        #endif
    }

    /// Ends anything left over from a previous launch, so a crash cannot strand a timer
    /// on someone's lock screen forever.
    func endStrandedActivities() {
        #if canImport(ActivityKit)
        Task {
            for activity in Activity<SessionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
