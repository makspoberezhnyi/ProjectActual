import Foundation
import UserNotifications
import SwiftUI

@Observable
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = NotificationManager()
    
    public var isAuthorized: Bool = false
    public var authStatusDescription: String = "Not Determined"
    
    public static let finishActionIdentifier = "TEMPO_FINISH_SESSION_ACTION"
    public static let extend5MinActionIdentifier = "TEMPO_EXTEND_5M_ACTION"
    public static let extend15MinActionIdentifier = "TEMPO_EXTEND_15M_ACTION"
    public static let extend30MinActionIdentifier = "TEMPO_EXTEND_30M_ACTION"
    public static let sessionCategoryIdentifier = "TEMPO_SESSION_CATEGORY"
    
    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategories()
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    private func setupCategories() {
        let finishAction = UNNotificationAction(
            identifier: Self.finishActionIdentifier,
            title: "Done & Log",
            options: [.foreground]
        )
        let extend5Action = UNNotificationAction(
            identifier: Self.extend5MinActionIdentifier,
            title: "+5 min",
            options: []
        )
        let extend15Action = UNNotificationAction(
            identifier: Self.extend15MinActionIdentifier,
            title: "+15 min",
            options: []
        )
        let extend30Action = UNNotificationAction(
            identifier: Self.extend30MinActionIdentifier,
            title: "+30 min",
            options: []
        )
        
        let sessionCategory = UNNotificationCategory(
            identifier: Self.sessionCategoryIdentifier,
            actions: [finishAction, extend5Action, extend15Action, extend30Action],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let alarmCategory = UNNotificationCategory(
            identifier: TempoAlarmScheduler.alarmCategory,
            actions: [
                UNNotificationAction(identifier: TempoAlarmScheduler.snoozeAction, title: "Snooze 9 min", options: []),
                UNNotificationAction(identifier: TempoAlarmScheduler.wakeAction, title: "Wake up", options: [.foreground])
            ],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let timerCategory = UNNotificationCategory(
            identifier: TempoAlarmScheduler.timerCategory,
            actions: [
                UNNotificationAction(identifier: TempoAlarmScheduler.timerDoneAction, title: "Done & log", options: [.foreground]),
                UNNotificationAction(identifier: TempoAlarmScheduler.timerExtendAction, title: "+5 min", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([sessionCategory, alarmCategory, timerCategory])
    }
    
    public func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.isAuthorized = true
                self.authStatusDescription = "Enabled"
            case .denied:
                self.isAuthorized = false
                self.authStatusDescription = "Denied"
            case .notDetermined:
                self.isAuthorized = false
                self.authStatusDescription = "Not Connected"
            @unknown default:
                self.isAuthorized = false
                self.authStatusDescription = "Unknown"
            }
        }
    }
    
    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                self.isAuthorized = granted
                self.authStatusDescription = granted ? "Enabled" : "Denied"
            }
            return granted
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                self.authStatusDescription = "Denied"
            }
            return false
        }
    }
    
    // MARK: - Timer Expiration Notifications
    public func scheduleTimerCompletion(
        title: String,
        durationMinutes: Int,
        sessionId: String
    ) {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "integration_notifications_enabled") as? Bool ?? true
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⏱️ \(title) - Time's Up!"
        content.body = "Your \(durationMinutes)m estimate has finished. Tap to review or finish your session."
        content.sound = .default
        content.categoryIdentifier = Self.sessionCategoryIdentifier
        content.userInfo = [
            "sessionId": sessionId,
            "title": title,
            "durationMinutes": durationMinutes
        ]
        
        let timeInterval = max(5, Double(durationMinutes * 60))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "session_\(sessionId)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule timer notification: \(error)")
            }
        }
    }
    
    public func cancelTimerNotification(sessionId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session_\(sessionId)"])
    }
    
    // MARK: - Routine & Habit Notification
    public func scheduleHabitReminder(
        patternId: String,
        title: String,
        minutes: Int,
        hour: Int,
        minute: Int
    ) {
        let notificationsEnabled = UserDefaults.standard.object(forKey: "integration_notifications_enabled") as? Bool ?? true
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "✨ Routine: \(title)"
        content.body = "Time for your typical \(minutes)m \(title) session."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "routine_\(patternId)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        // Alarms and timers ring inside the app (mascot + chime), so the banner would double up.
        if identifier == TempoAlarmScheduler.timerIdentifier {
            Task { @MainActor in TimeOSStore.shared.timerReachedZero() }
            completionHandler([])
            return
        }
        if identifier.hasPrefix(TempoAlarmScheduler.alarmPrefix) {
            let alarmID = (notification.request.content.userInfo["alarmID"] as? String).flatMap(UUID.init(uuidString:))
            Task { @MainActor in
                if let alarmID { TimeOSStore.shared.ringAlarm(alarmID) }
            }
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier
        let sessionId = userInfo["sessionId"] as? String
        let identifier = response.notification.request.identifier
        
        if identifier == TempoAlarmScheduler.timerIdentifier {
            Task { @MainActor in
                let store = TimeOSStore.shared
                store.selectedMainTab = 0
                switch actionId {
                case TempoAlarmScheduler.timerExtendAction:
                    store.extendTimer(bySeconds: 5 * 60)
                case TempoAlarmScheduler.timerDoneAction:
                    if let context = store.modelContext {
                        store.completeAndCalibrateTimer(context: context)
                    }
                default:
                    break
                }
            }
            completionHandler()
            return
        }
        
        if identifier.hasPrefix(TempoAlarmScheduler.alarmPrefix),
           let alarmID = (userInfo["alarmID"] as? String).flatMap(UUID.init(uuidString:)) {
            Task { @MainActor in
                let store = TimeOSStore.shared
                switch actionId {
                case TempoAlarmScheduler.snoozeAction:
                    store.snoozeAlarm(alarmID)
                case TempoAlarmScheduler.wakeAction:
                    if let alarm = store.alarms.first(where: { $0.id == alarmID }),
                       alarm.chainedTaskTitle != nil,
                       let context = store.modelContext {
                        store.dismissAlarmAndStartRoutine(alarm, context: context)
                    } else {
                        store.stopAlarm(alarmID)
                    }
                case UNNotificationDismissActionIdentifier:
                    store.stopAlarm(alarmID)
                default:
                    // Opened from the banner: show the ringing screen quietly so they can stop or chain.
                    store.selectedMainTab = 1
                    store.ringAlarm(alarmID, playSound: false, force: true)
                }
            }
            completionHandler()
            return
        }
        
        if actionId == Self.finishActionIdentifier {
            var notifUserInfo: [String: Any] = [:]
            if let sessionId { notifUserInfo["sessionId"] = sessionId }
            NotificationCenter.default.post(
                name: .finishSessionFromNotification,
                object: nil,
                userInfo: notifUserInfo.isEmpty ? nil : notifUserInfo
            )
        } else if actionId == Self.extend5MinActionIdentifier {
            var notifUserInfo: [String: Any] = ["minutes": 5]
            if let sessionId { notifUserInfo["sessionId"] = sessionId }
            NotificationCenter.default.post(
                name: .extendSessionFromNotification,
                object: nil,
                userInfo: notifUserInfo
            )
        } else if actionId == Self.extend15MinActionIdentifier {
            var notifUserInfo: [String: Any] = ["minutes": 15]
            if let sessionId { notifUserInfo["sessionId"] = sessionId }
            NotificationCenter.default.post(
                name: .extendSessionFromNotification,
                object: nil,
                userInfo: notifUserInfo
            )
        } else if actionId == Self.extend30MinActionIdentifier {
            var notifUserInfo: [String: Any] = ["minutes": 30]
            if let sessionId { notifUserInfo["sessionId"] = sessionId }
            NotificationCenter.default.post(
                name: .extendSessionFromNotification,
                object: nil,
                userInfo: notifUserInfo
            )
        }
        
        completionHandler()
    }
}

public extension Notification.Name {
    static let finishSessionFromNotification = Notification.Name("TEMPO_FINISH_SESSION_FROM_NOTIFICATION")
    static let extendSessionFromNotification = Notification.Name("TEMPO_EXTEND_SESSION_FROM_NOTIFICATION")
    static let sessionDestinationReached = Notification.Name("TEMPO_SESSION_DESTINATION_REACHED")
}
