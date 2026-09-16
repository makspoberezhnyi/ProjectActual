import Foundation
import WatchConnectivity
import WatchKit
import SwiftUI

/// Observable store managing watchOS session state, live timer countdown, and bidirectional iPhone sync.
@MainActor
@Observable
final class WatchSessionStore: NSObject {
    static let shared = WatchSessionStore()
    
    var isRunning: Bool = false
    var taskTitle: String = "Focus Session"
    var estimatedMinutes: Int = 25
    var startDate: Date? = nil
    
    var todayMinutes: Int = 0
    var completedCount: Int = 0
    var calibrationScore: Double = 0.85
    
    var isPhoneReachable: Bool = false
    
    private var wcSession: WCSession?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            self.wcSession = WCSession.default
            self.wcSession?.delegate = self
            self.wcSession?.activate()
        }
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        if wcSession?.activationState != .activated {
            wcSession?.activate()
        } else if let s = wcSession {
            let payload = Self.extract(from: s.receivedApplicationContext)
            self.apply(
                isRunning: payload.isRunning,
                title: payload.title,
                mins: payload.mins,
                start: payload.start,
                action: payload.action,
                today: payload.today,
                completed: payload.completed,
                score: payload.score
            )
        }
        requestLatestStateFromPhone()
    }
    
    func requestLatestStateFromPhone() {
        guard let s = wcSession, s.activationState == .activated else { return }
        let payload: [String: Any] = [
            "action": "requestSync",
            "timestamp": Date().timeIntervalSince1970
        ]
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                s.transferUserInfo(payload)
            }
        } else {
            s.transferUserInfo(payload)
        }
    }
    
    // MARK: - Actions
    
    func startSession(title: String, minutes: Int) {
        let now = Date()
        self.taskTitle = title
        self.estimatedMinutes = minutes
        self.startDate = now
        self.isRunning = true
        
        WKInterfaceDevice.current().play(.start)
        
        let payload: [String: Any] = [
            "action": "startFocus",
            "taskTitle": title,
            "minutes": minutes,
            "startDate": now.timeIntervalSince1970,
            "timestamp": now.timeIntervalSince1970
        ]
        sendToPhone(payload)
    }
    
    func stopSession() {
        let elapsed = Int(Date().timeIntervalSince(startDate ?? Date()) / 60.0)
        let actual = max(1, elapsed)
        let title = self.taskTitle
        
        self.isRunning = false
        self.startDate = nil
        self.todayMinutes += actual
        self.completedCount += 1
        
        WKInterfaceDevice.current().play(.success)
        
        let payload: [String: Any] = [
            "action": "stopFocus",
            "taskTitle": title,
            "actualMinutes": actual,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendToPhone(payload)
    }
    
    func extendSession(by extraMinutes: Int) {
        self.estimatedMinutes += extraMinutes
        WKInterfaceDevice.current().play(.click)
        
        let payload: [String: Any] = [
            "action": "extendFocus",
            "taskTitle": self.taskTitle,
            "additionalMinutes": extraMinutes,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendToPhone(payload)
    }
    
    private func sendToPhone(_ payload: [String: Any]) {
        guard let s = wcSession, s.activationState == .activated else { return }
        
        // Always transferUserInfo for guaranteed background delivery
        s.transferUserInfo(payload)
        
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { error in
                print("[WatchStore] sendMessage error: \(error.localizedDescription)")
            }
        }
        
        do {
            try s.updateApplicationContext(payload)
        } catch {
            print("[WatchStore] updateApplicationContext error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Process Incoming Payload
    
    func apply(
        isRunning: Bool?,
        title: String?,
        mins: Int?,
        start: Double?,
        action: String?,
        today: Int?,
        completed: Int?,
        score: Double?
    ) {
        if let action = action {
            if action == "sessionStopped" {
                self.isRunning = false
                self.startDate = nil
                WKInterfaceDevice.current().play(.success)
            } else if action == "activeSessionUpdate" {
                self.isRunning = true
                if let title = title { self.taskTitle = title }
                if let mins = mins { self.estimatedMinutes = mins }
                if let time = start { self.startDate = Date(timeIntervalSince1970: time) }
                else if self.startDate == nil { self.startDate = Date() }
                WKInterfaceDevice.current().play(.start)
            }
        }
        
        if let isRunning = isRunning {
            self.isRunning = isRunning
            if isRunning {
                if let title = title { self.taskTitle = title }
                if let mins = mins { self.estimatedMinutes = mins }
                if let time = start { self.startDate = Date(timeIntervalSince1970: time) }
                else if self.startDate == nil { self.startDate = Date() }
            } else {
                self.startDate = nil
            }
        }
        
        if let todayMins = today { self.todayMinutes = todayMins }
        if let count = completed { self.completedCount = count }
        if let scoreVal = score { self.calibrationScore = scoreVal }
    }
    
    nonisolated static func extract(from dict: [String: Any]) -> (
        isRunning: Bool?,
        title: String?,
        mins: Int?,
        start: Double?,
        action: String?,
        today: Int?,
        completed: Int?,
        score: Double?
    ) {
        let isRunning = dict["isRunning"] as? Bool
        let title = dict["taskTitle"] as? String
        let mins = (dict["estimatedMinutes"] as? Int) ?? (dict["minutes"] as? Int)
        let start = (dict["startDate"] as? Double) ?? (dict["timestamp"] as? Double)
        let action = dict["action"] as? String
        let today = dict["todayMinutes"] as? Int
        let completed = dict["completedCount"] as? Int
        let score = dict["calibrationScore"] as? Double
        return (isRunning, title, mins, start, action, today, completed, score)
    }
}

// MARK: - WCSessionDelegate
extension WatchSessionStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let reachable = session.isReachable
        let payload = Self.extract(from: session.receivedApplicationContext)
        Task { @MainActor in
            self.isPhoneReachable = reachable
            self.apply(
                isRunning: payload.isRunning,
                title: payload.title,
                mins: payload.mins,
                start: payload.start,
                action: payload.action,
                today: payload.today,
                completed: payload.completed,
                score: payload.score
            )
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = reachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let payload = Self.extract(from: message)
        Task { @MainActor in
            self.apply(
                isRunning: payload.isRunning,
                title: payload.title,
                mins: payload.mins,
                start: payload.start,
                action: payload.action,
                today: payload.today,
                completed: payload.completed,
                score: payload.score
            )
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        let payload = Self.extract(from: userInfo)
        Task { @MainActor in
            self.apply(
                isRunning: payload.isRunning,
                title: payload.title,
                mins: payload.mins,
                start: payload.start,
                action: payload.action,
                today: payload.today,
                completed: payload.completed,
                score: payload.score
            )
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        let payload = Self.extract(from: applicationContext)
        Task { @MainActor in
            self.apply(
                isRunning: payload.isRunning,
                title: payload.title,
                mins: payload.mins,
                start: payload.start,
                action: payload.action,
                today: payload.today,
                completed: payload.completed,
                score: payload.score
            )
        }
    }
}
