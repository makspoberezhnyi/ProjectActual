import Foundation
import WatchConnectivity
import WatchKit
import SwiftUI

// MARK: - What the phone shares with the watch pages

struct WatchQuickTask: Hashable, Sendable {
    var title: String
    var minutes: Int
}

struct WatchAlarm: Identifiable, Hashable, Sendable {
    var id: String
    var label: String
    var hour: Int
    var minute: Int
    var time: String
    var repeatText: String
    var enabled: Bool
    var bedtime: Bool
}

struct WatchCity: Identifiable, Hashable, Sendable {
    var name: String
    var tz: String
    var id: String { name + tz }
    var timeZone: TimeZone { TimeZone(identifier: tz) ?? .current }

    func hour(at date: Date) -> Int {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal.component(.hour, from: date)
    }
}

struct WatchLibrary: Sendable {
    var quickTasks: [WatchQuickTask]?
    var alarms: [WatchAlarm]?
    var cities: [WatchCity]?
    /// Set when the payload carried the alarm list, so a missing next alarm means "none".
    var hasAlarmInfo = false
    var nextAlarmLabel: String?
    var nextAlarmDate: Date?
    var nextAlarmBedtime = false
}

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
    
    // Shared from the phone
    var quickTasks: [WatchQuickTask] = [
        WatchQuickTask(title: "Deep work", minutes: 45),
        WatchQuickTask(title: "Email", minutes: 15),
        WatchQuickTask(title: "Quick focus", minutes: 25)
    ]
    var alarms: [WatchAlarm] = []
    var cities: [WatchCity] = []
    var nextAlarmLabel: String?
    var nextAlarmDate: Date?
    var nextAlarmBedtime = false
    
    // Stopwatch, local to the watch
    var chronoRunning = false
    var chronoStartedAt: Date?
    var chronoAccumulated: TimeInterval = 0
    var chronoLaps: [TimeInterval] = []
    
    var timerEnd: Date? {
        guard isRunning, let startDate else { return nil }
        return startDate.addingTimeInterval(TimeInterval(max(1, estimatedMinutes) * 60))
    }
    
    func chronoElapsed(at now: Date = Date()) -> TimeInterval {
        if chronoRunning, let chronoStartedAt { return chronoAccumulated + now.timeIntervalSince(chronoStartedAt) }
        return chronoAccumulated
    }
    
    /// Orange pusher: start or stop.
    func toggleChrono() {
        let now = Date()
        if chronoRunning {
            chronoAccumulated = chronoElapsed(at: now)
            chronoStartedAt = nil
            chronoRunning = false
            WKInterfaceDevice.current().play(.stop)
        } else {
            chronoStartedAt = now
            chronoRunning = true
            WKInterfaceDevice.current().play(.start)
        }
    }
    
    /// Black pusher: lap while running, reset while stopped.
    func lapOrResetChrono() {
        if chronoRunning {
            chronoLaps.insert(chronoElapsed(), at: 0)
            WKInterfaceDevice.current().play(.click)
        } else {
            chronoAccumulated = 0
            chronoLaps.removeAll()
            WKInterfaceDevice.current().play(.directionDown)
        }
    }
    
    // MARK: Alarm edits and saved runs (the phone does the real scheduling and logging)
    
    static func formattedTime(hour: Int, minute: Int) -> String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%02d:%02d %@", h12, minute, hour < 12 ? "AM" : "PM")
    }
    
    func setAlarmEnabled(_ alarm: WatchAlarm, _ enabled: Bool) {
        if let i = alarms.firstIndex(where: { $0.id == alarm.id }) { alarms[i].enabled = enabled }
        WKInterfaceDevice.current().play(.click)
        sendCommand(["action": "alarmSetEnabled", "alarmID": alarm.id, "enabled": enabled])
    }
    
    /// `id` nil makes a new alarm. The list updates right away; the phone's confirmation follows.
    func saveAlarm(id: String?, hour: Int, minute: Int, label: String) {
        let clean = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = Self.formattedTime(hour: hour, minute: minute)
        if let id, let i = alarms.firstIndex(where: { $0.id == id }) {
            alarms[i].hour = hour
            alarms[i].minute = minute
            alarms[i].time = time
            alarms[i].enabled = true
            if !clean.isEmpty { alarms[i].label = clean }
        } else {
            alarms.append(WatchAlarm(
                id: UUID().uuidString, label: clean.isEmpty ? "Alarm" : clean,
                hour: hour, minute: minute, time: time, repeatText: "Every day", enabled: true, bedtime: false
            ))
        }
        WKInterfaceDevice.current().play(.success)
        var payload: [String: Any] = ["action": "alarmSave", "hour": hour, "minute": minute, "label": clean]
        if let id { payload["alarmID"] = id }
        sendCommand(payload)
    }
    
    func deleteAlarm(id: String) {
        alarms.removeAll { $0.id == id }
        WKInterfaceDevice.current().play(.directionDown)
        sendCommand(["action": "alarmDelete", "alarmID": id])
    }
    
    /// Sends the paused stopwatch run to the phone's logbook, then clears the stopwatch.
    func saveStopwatchRun(title: String) {
        let seconds = chronoElapsed()
        guard seconds >= 1 else { return }
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        sendCommand([
            "action": "logStopwatch",
            "taskTitle": clean.isEmpty ? "Stopwatch run" : clean,
            "seconds": seconds,
            "endDate": Date().timeIntervalSince1970
        ])
        if chronoRunning { toggleChrono() }
        chronoAccumulated = 0
        chronoLaps.removeAll()
        todayMinutes += max(1, Int((seconds / 60).rounded()))
        WKInterfaceDevice.current().play(.success)
    }
    
    private func sendCommand(_ base: [String: Any]) {
        var payload = base
        payload["commandID"] = UUID().uuidString
        payload["timestamp"] = Date().timeIntervalSince1970
        sendToPhone(payload)
    }
    
    func applyLibrary(_ library: WatchLibrary?) {
        guard let library else { return }
        if let tasks = library.quickTasks, !tasks.isEmpty { quickTasks = tasks }
        if let alarms = library.alarms { self.alarms = alarms }
        if let cities = library.cities { self.cities = cities }
        if library.hasAlarmInfo {
            nextAlarmLabel = library.nextAlarmLabel
            nextAlarmDate = library.nextAlarmDate
            nextAlarmBedtime = library.nextAlarmBedtime
        }
    }
    
    nonisolated static func library(from dict: [String: Any]) -> WatchLibrary? {
        let tasks = (dict["quickTasks"] as? [[String: Any]])?.compactMap { item -> WatchQuickTask? in
            guard let title = item["title"] as? String, let minutes = item["minutes"] as? Int else { return nil }
            return WatchQuickTask(title: title, minutes: minutes)
        }
        let alarms = (dict["alarms"] as? [[String: Any]])?.compactMap { item -> WatchAlarm? in
            guard let id = item["id"] as? String, let label = item["label"] as? String, let time = item["time"] as? String else { return nil }
            return WatchAlarm(
                id: id,
                label: label,
                hour: item["hour"] as? Int ?? 7,
                minute: item["minute"] as? Int ?? 0,
                time: time,
                repeatText: item["repeat"] as? String ?? "",
                enabled: item["enabled"] as? Bool ?? true,
                bedtime: item["bedtime"] as? Bool ?? false
            )
        }
        let cities = (dict["cities"] as? [[String: Any]])?.compactMap { item -> WatchCity? in
            guard let name = item["name"] as? String, let tz = item["tz"] as? String else { return nil }
            return WatchCity(name: name, tz: tz)
        }
        guard tasks != nil || alarms != nil || cities != nil else { return nil }
        var library = WatchLibrary(quickTasks: tasks, alarms: alarms, cities: cities)
        library.hasAlarmInfo = alarms != nil
        library.nextAlarmLabel = dict["nextAlarmLabel"] as? String
        library.nextAlarmDate = (dict["nextAlarmDate"] as? Double).map { Date(timeIntervalSince1970: $0) }
        library.nextAlarmBedtime = dict["nextAlarmBedtime"] as? Bool ?? false
        return library
    }
    
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
            applyLibrary(Self.library(from: s.receivedApplicationContext))
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
        let library = Self.library(from: session.receivedApplicationContext)
        Task { @MainActor in
            self.isPhoneReachable = reachable
            self.applyLibrary(library)
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
        let library = Self.library(from: message)
        Task { @MainActor in
            self.applyLibrary(library)
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
        let library = Self.library(from: userInfo)
        Task { @MainActor in
            self.applyLibrary(library)
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
        let library = Self.library(from: applicationContext)
        Task { @MainActor in
            self.applyLibrary(library)
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
