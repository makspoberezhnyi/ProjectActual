import Foundation
import WatchConnectivity
import Combine
import WidgetKit

/// Manages bidirectional synchronization between Tempo on iPhone and paired Apple Watch via WatchConnectivity.
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isSupported: Bool = false
    @Published var isPaired: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var isReachable: Bool = false
    @Published var lastSyncedAt: Date? = nil
    
    private var session: WCSession?
    
    override private init() {
        super.init()
        if WCSession.isSupported() {
            self.session = WCSession.default
            self.isSupported = true
            self.session?.delegate = self
            self.session?.activate()
        }
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        if session?.activationState != .activated {
            session?.activate()
        }
        updateStatus()
    }
    
    private func updateStatus() {
        guard let s = session else { return }
        self.isPaired = s.isPaired
        self.isWatchAppInstalled = s.isWatchAppInstalled
        self.isReachable = s.isReachable
    }
    
    // MARK: - Outgoing Sync Methods
    
    /// Syncs an active focus timer state to Apple Watch.
    func syncActiveSession(title: String, estimatedMinutes: Int, startDate: Date) {
        let payload: [String: Any] = [
            "action": "activeSessionUpdate",
            "isRunning": true,
            "taskTitle": title,
            "estimatedMinutes": estimatedMinutes,
            "startDate": startDate.timeIntervalSince1970,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendPayloadToWatch(payload)
    }
    
    /// Syncs session completion state to Apple Watch.
    func syncSessionStopped(actualMinutes: Int) {
        let payload: [String: Any] = [
            "action": "sessionStopped",
            "isRunning": false,
            "actualMinutes": actualMinutes,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendPayloadToWatch(payload)
    }
    
    /// Syncs daily focus metrics and calibration score for Apple Watch complications and Smart Stack.
    func syncDailySnapshot(todayMinutes: Int, completedCount: Int, calibrationScore: Double) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        var payload: [String: Any] = [
            "todayMinutes": todayMinutes,
            "completedCount": completedCount,
            "calibrationScore": calibrationScore,
            "isRunning": snapshot.isRunning,
            "timestamp": Date().timeIntervalSince1970
        ]
        if snapshot.isRunning {
            payload["taskTitle"] = snapshot.activeTaskTitle ?? "Focus Session"
            payload["estimatedMinutes"] = snapshot.activeTaskEstimatedMinutes ?? 25
            if let start = snapshot.activeTaskStartedAt {
                payload["startDate"] = start.timeIntervalSince1970
            }
        }
        sendPayloadToWatch(payload)
    }
    
    private func sendPayloadToWatch(_ payload: [String: Any]) {
        guard let s = session, s.activationState == .activated else { return }
        
        // 1. Always transferUserInfo for guaranteed background delivery
        s.transferUserInfo(payload)
        
        // 2. Direct interactive message if reachable in foreground
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { error in
                print("[WatchConnectivity] sendMessage error: \(error.localizedDescription)")
            }
        }
        
        // 3. Application context for persistent sync
        do {
            try s.updateApplicationContext(payload)
            self.lastSyncedAt = Date()
        } catch {
            print("[WatchConnectivity] updateApplicationContext fallback error: \(error.localizedDescription)")
        }
    }
    private var lastProcessedActionKey: String = ""
    private var lastProcessedActionDate: Date = Date.distantPast
    
    private func shouldProcessAction(action: String, title: String?, timestamp: Double?) -> Bool {
        let tsInt = Int(timestamp ?? Date().timeIntervalSince1970)
        let key = "\(action)_\(title ?? "")_\(tsInt)"
        let now = Date()
        if lastProcessedActionKey == key && now.timeIntervalSince(lastProcessedActionDate) < 2.5 {
            return false
        }
        lastProcessedActionKey = key
        lastProcessedActionDate = now
        return true
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        let reachable = session.isReachable
        Task { @MainActor in
            self.isPaired = paired
            self.isWatchAppInstalled = installed
            self.isReachable = reachable
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for multi-watch switching support
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate session if user switches Apple Watches
        WCSession.default.activate()
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let action = message["action"] as? String
        let title = message["taskTitle"] as? String
        let mins = message["minutes"] as? Int
        let actual = message["actualMinutes"] as? Int
        let additional = message["additionalMinutes"] as? Int
        let startTimestamp = (message["startDate"] as? Double) ?? (message["timestamp"] as? Double)
        
        Task { @MainActor in
            self.handleIncomingAction(
                action: action,
                title: title,
                minutes: mins,
                actualMinutes: actual,
                additionalMinutes: additional,
                startTimestamp: startTimestamp
            )
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let action = userInfo["action"] as? String
        let title = userInfo["taskTitle"] as? String
        let mins = userInfo["minutes"] as? Int
        let actual = userInfo["actualMinutes"] as? Int
        let additional = userInfo["additionalMinutes"] as? Int
        let startTimestamp = (userInfo["startDate"] as? Double) ?? (userInfo["timestamp"] as? Double)
        
        Task { @MainActor in
            self.handleIncomingAction(
                action: action,
                title: title,
                minutes: mins,
                actualMinutes: actual,
                additionalMinutes: additional,
                startTimestamp: startTimestamp
            )
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let action = applicationContext["action"] as? String
        let title = applicationContext["taskTitle"] as? String
        let mins = applicationContext["minutes"] as? Int
        let actual = applicationContext["actualMinutes"] as? Int
        let additional = applicationContext["additionalMinutes"] as? Int
        let startTimestamp = (applicationContext["startDate"] as? Double) ?? (applicationContext["timestamp"] as? Double)
        
        Task { @MainActor in
            self.handleIncomingAction(
                action: action,
                title: title,
                minutes: mins,
                actualMinutes: actual,
                additionalMinutes: additional,
                startTimestamp: startTimestamp
            )
        }
    }
    
    @MainActor
    func handleIncomingAction(
        action: String?,
        title: String?,
        minutes: Int?,
        actualMinutes: Int?,
        additionalMinutes: Int?,
        startTimestamp: Double? = nil
    ) {
        guard let action = action else { return }
        guard shouldProcessAction(action: action, title: title, timestamp: startTimestamp) else { return }
        
        switch action {
        case "startFocus":
            let taskTitle = title ?? "Focus Session"
            let duration = minutes ?? 25
            let startDate = startTimestamp != nil ? Date(timeIntervalSince1970: startTimestamp!) : Date()
            WidgetDataStore.shared.startSession(title: taskTitle, minutes: duration, startDate: startDate)
            LiveActivityManager.shared.startLiveActivity(taskTitle: taskTitle, estimatedMinutes: duration, startDate: startDate)
            WidgetCenter.shared.reloadAllTimelines()
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
            NotificationCenter.default.post(name: .syncWidgetSessionsNotification, object: nil)
            
        case "stopFocus":
            let actual = actualMinutes ?? 25
            WidgetDataStore.shared.stopActiveSession(actualMinutes: actual, taskTitle: title)
            LiveActivityManager.shared.endLiveActivity(actualMinutes: actual)
            WidgetCenter.shared.reloadAllTimelines()
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
            NotificationCenter.default.post(
                name: .finishSessionFromNotification,
                object: nil,
                userInfo: ["actualMinutes": actual, "source": "Apple Watch"]
            )
            NotificationCenter.default.post(name: .syncWidgetSessionsNotification, object: nil)
            
        case "extendFocus":
            let extra = additionalMinutes ?? 5
            WidgetDataStore.shared.extendActiveSession(by: extra)
            let snapshot = WidgetDataStore.shared.loadSnapshot()
            let newEst = (snapshot.activeTaskEstimatedMinutes ?? 25) + extra
            LiveActivityManager.shared.updateLiveActivity(estimatedMinutes: newEst, statusMessage: "+\(extra)m Extended")
            WidgetCenter.shared.reloadAllTimelines()
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoFocusWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "TempoLockScreenWidget")
            NotificationCenter.default.post(
                name: .extendSessionFromNotification,
                object: nil,
                userInfo: ["minutes": extra, "source": "Apple Watch"]
            )
            NotificationCenter.default.post(name: .syncWidgetSessionsNotification, object: nil)
            
        case "requestSync":
            let snapshot = WidgetDataStore.shared.loadSnapshot()
            if snapshot.isRunning {
                self.syncActiveSession(
                    title: snapshot.activeTaskTitle ?? "Focus Session",
                    estimatedMinutes: snapshot.activeTaskEstimatedMinutes ?? 25,
                    startDate: snapshot.activeTaskStartedAt ?? Date()
                )
            } else {
                self.syncSessionStopped(actualMinutes: snapshot.lastCompletedMinutes ?? 0)
            }
            self.syncDailySnapshot(
                todayMinutes: snapshot.todayMinutes,
                completedCount: snapshot.todayCompletedCount,
                calibrationScore: snapshot.calibrationScore
            )
            
        default:
            break
        }
    }
}
