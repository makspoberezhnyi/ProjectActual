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
            title: "Finish & Log",
            options: [.foreground]
        )
        let extendAction = UNNotificationAction(
            identifier: Self.extend5MinActionIdentifier,
            title: "+5 min",
            options: []
        )
        
        let sessionCategory = UNNotificationCategory(
            identifier: Self.sessionCategoryIdentifier,
            actions: [finishAction, extendAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([sessionCategory])
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
        completionHandler([.banner, .sound, .badge])
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier
        
        if actionId == Self.finishActionIdentifier {
            if let sessionId = userInfo["sessionId"] as? String {
                NotificationCenter.default.post(
                    name: .finishSessionFromNotification,
                    object: nil,
                    userInfo: ["sessionId": sessionId]
                )
            }
        }
        
        completionHandler()
    }
}

public extension Notification.Name {
    static let finishSessionFromNotification = Notification.Name("TEMPO_FINISH_SESSION_FROM_NOTIFICATION")
}
