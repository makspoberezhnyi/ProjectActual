import Foundation
import SwiftUI
import SwiftData
import UserNotifications

// MARK: - 1. Alarms & Sleep Models

public struct TempoAlarm: Identifiable, Codable, Equatable {
    public var id: UUID
    public var hour: Int
    public var minute: Int
    public var label: String
    public var isEnabled: Bool
    public var isBedtimeWindDown: Bool
    public var isCommuteAutoCalibrated: Bool
    /// Connected Time Chain: optional routine task block that can be started immediately upon dismissing the alarm
    public var chainedTaskTitle: String?
    public var chainedTaskMinutes: Int?
    public var snoozedUntil: Date?
    
    public init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        label: String,
        isEnabled: Bool = true,
        isBedtimeWindDown: Bool = false,
        isCommuteAutoCalibrated: Bool = false,
        chainedTaskTitle: String? = nil,
        chainedTaskMinutes: Int? = nil,
        snoozedUntil: Date? = nil
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.label = label
        self.isEnabled = isEnabled
        self.isBedtimeWindDown = isBedtimeWindDown
        self.isCommuteAutoCalibrated = isCommuteAutoCalibrated
        self.chainedTaskTitle = chainedTaskTitle
        self.chainedTaskMinutes = chainedTaskMinutes
        self.snoozedUntil = snoozedUntil
    }
    
    public var formattedTime: String {
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return String(format: "%02d:%02d %@", h12, minute, ampm)
    }
    
    public var hourAngle: Double {
        Double(hour % 12) * 30.0 + Double(minute) * 0.5
    }
    
    public var minuteAngle: Double {
        Double(minute) * 6.0
    }
}

// MARK: - 2. Chronograph Stopwatch Models

public struct ChronoLap: Identifiable, Codable, Equatable {
    public var id: UUID
    public var lapNumber: Int
    public var splitSeconds: TimeInterval
    public var totalSeconds: TimeInterval
    public var label: String
    public var claimedAsSession: Bool
    
    public init(
        id: UUID = UUID(),
        lapNumber: Int,
        splitSeconds: TimeInterval,
        totalSeconds: TimeInterval,
        label: String = "",
        claimedAsSession: Bool = false
    ) {
        self.id = id
        self.lapNumber = lapNumber
        self.splitSeconds = splitSeconds
        self.totalSeconds = totalSeconds
        self.label = label.isEmpty ? "Lap \(String(format: "%02d", lapNumber))" : label
        self.claimedAsSession = claimedAsSession
    }
}

// MARK: - 3. Bezel Timer & Interval Presets

public struct TempoTimerPreset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var durationSeconds: Int
    public var icon: String
    public var isRestInterval: Bool
    public var isKitchenUtility: Bool
    
    public init(
        id: UUID = UUID(),
        title: String,
        durationSeconds: Int,
        icon: String = "timer",
        isRestInterval: Bool = false,
        isKitchenUtility: Bool = false
    ) {
        self.id = id
        self.title = title
        self.durationSeconds = durationSeconds
        self.icon = icon
        self.isRestInterval = isRestInterval
        self.isKitchenUtility = isKitchenUtility
    }
}

// MARK: - 4. World Clock & Dual-Time GMT Models

public struct TempoWorldCity: Identifiable, Codable, Equatable {
    public var id: UUID
    public var cityName: String
    public var timeZoneIdentifier: String
    public var teamNote: String
    
    public init(
        id: UUID = UUID(),
        cityName: String,
        timeZoneIdentifier: String,
        teamNote: String = ""
    ) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.teamNote = teamNote
    }
    
    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
    
    public func localComponents(at date: Date = Date()) -> DateComponents {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal.dateComponents([.hour, .minute, .second], from: date)
    }
    
    public func formattedLocalTime(at date: Date = Date()) -> String {
        let c = localComponents(at: date)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        let h12 = h % 12 == 0 ? 12 : h % 12
        let ampm = h < 12 ? "AM" : "PM"
        return String(format: "%02d:%02d %@", h12, m, ampm)
    }
    
    public func hoursOffsetString(from reference: TimeZone = .current, at date: Date = Date()) -> String {
        let diff = (timeZone.secondsFromGMT(for: date) - reference.secondsFromGMT(for: date)) / 3600
        if diff == 0 { return "0h" }
        return diff > 0 ? "+\(diff)h" : "\(diff)h"
    }
    
    /// Automatically assigns Daytime Sun Dial (#F6F4F0), Moody Dusk Blue (#283862), or Moody Midnight Blue (#1E2B4F)
    public func mascotRegime(at date: Date = Date()) -> TempoMascotRegime {
        let h = localComponents(at: date).hour ?? 12
        if h >= 22 || h < 6 {
            return .worldRemoteNight     // Moody Midnight Blue (#1E2B4F)
        } else if h >= 18 && h < 22 {
            return .alarmSnoozing        // Moody Dusk Blue (#283862)
        } else if timeZoneIdentifier == TimeZone.current.identifier {
            return .worldLocalDay
        } else {
            return .worldDualGMT
        }
    }
    
    public func isMoodyNight(at date: Date = Date()) -> Bool {
        let h = localComponents(at: date).hour ?? 12
        return h >= 22 || h < 6
    }
    
    public func isMoodyDusk(at date: Date = Date()) -> Bool {
        let h = localComponents(at: date).hour ?? 12
        return h >= 18 && h < 22
    }
}

// MARK: - Unified Time OS Central Store

@MainActor
@Observable
public final class TimeOSStore {
    public static let shared = TimeOSStore()
    
    // Active Time OS Sub-Regime inside the Time Hub
    public enum ActiveService: String, CaseIterable, Identifiable {
        case alarms = "Alarms"
        case chrono = "Chrono"
        case timers = "Timers"
        case world = "World"
        case mascotStudio = "24 Mascots"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .alarms: return "bell.badge.fill"
            case .chrono: return "stopwatch.fill"
            case .timers: return "timer"
            case .world: return "globe"
            case .mascotStudio: return "sparkles"
            }
        }
    }
    
    public var activeService: ActiveService = .timers
    /// Top-level Tab Bar index: 0 = Focus, 1 = Alarms, 2 = Stopwatch, 3 = World, 4 = Logbook
    public var selectedMainTab: Int = 0
    /// Single-line Mascot Voice Pill replacing the legacy scrolling chat log
    public var mascotVoiceMessage: String = "Type a task like \"Design review 30m\" or dial the bezel to calibrate."
    
    // --- 1. ALARMS STATE ---
    public var alarms: [TempoAlarm] = []
    public var activeRingingAlarmID: UUID? = nil
    
    // --- 2. CHRONOGRAPH STOPWATCH STATE ---
    public var chronoIsRunning: Bool = false
    public var chronoStartedAt: Date? = nil
    public var chronoAccumulatedSeconds: TimeInterval = 0
    public var chronoLapStartedAt: Date? = nil
    public var chronoLapAccumulatedSeconds: TimeInterval = 0
    public var chronoLaps: [ChronoLap] = []
    public var lastLapSparkAt: Date? = nil
    
    // --- 3. BEZEL TIMER & INTERVALS STATE ---
    public var timerTargetSeconds: Int = 25 * 60
    public var timerLinkedTaskTitle: String = "Deep Focus"
    public var timerIsRunning: Bool = false
    public var timerStartedAt: Date? = nil
    public var timerAccumulatedSeconds: TimeInterval = 0
    public var timerIsRestMode: Bool = false
    public var timerIsKitchenUtility: Bool = false
    public var timerPresets: [TempoTimerPreset] = [
        TempoTimerPreset(title: "Focus", durationSeconds: 25 * 60, icon: "flame.fill"),
        TempoTimerPreset(title: "Coffee", durationSeconds: 4 * 60, icon: "cup.and.saucer.fill", isKitchenUtility: true),
        TempoTimerPreset(title: "Break", durationSeconds: 10 * 60, icon: "wind", isRestInterval: true),
        TempoTimerPreset(title: "HIIT", durationSeconds: 90, icon: "bolt.fill", isRestInterval: true),
        TempoTimerPreset(title: "Deep Work", durationSeconds: 45 * 60, icon: "cpu.fill")
    ]
    
    // --- 4. WORLD CLOCK & GMT STATE ---
    public var worldCities: [TempoWorldCity] = []
    
    // --- 5. MASCOT STUDIO STATE ---
    public var selectedStudioRegime: TempoMascotRegime = .alarmRinging
    
    private let defaults = UserDefaults.standard
    private let alarmsKey = "tempo.timeos.alarms.v2"
    private let citiesKey = "tempo.timeos.cities.v2"
    
    private init() {
        loadPersistedState()
    }
    
    // MARK: - Persistence
    
    public func loadPersistedState() {
        if let data = defaults.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([TempoAlarm].self, from: data),
           !decoded.isEmpty {
            alarms = decoded
        } else {
            alarms = [
                TempoAlarm(
                    hour: 7,
                    minute: 0,
                    label: "Wake Up",
                    isEnabled: true,
                    chainedTaskTitle: "Morning Routine",
                    chainedTaskMinutes: 20
                ),
                TempoAlarm(
                    hour: 8,
                    minute: 25,
                    label: "Commute",
                    isEnabled: true,
                    isCommuteAutoCalibrated: true,
                    chainedTaskTitle: "Commute",
                    chainedTaskMinutes: 30
                ),
                TempoAlarm(
                    hour: 23,
                    minute: 0,
                    label: "Sleep",
                    isEnabled: true,
                    isBedtimeWindDown: true
                )
            ]
        }
        
        if let cData = defaults.data(forKey: citiesKey),
           let cDecoded = try? JSONDecoder().decode([TempoWorldCity].self, from: cData),
           !cDecoded.isEmpty {
            worldCities = cDecoded
        } else {
            worldCities = [
                TempoWorldCity(cityName: "San Francisco", timeZoneIdentifier: "America/Los_Angeles", teamNote: "Design & iOS Core · Peak Focus"),
                TempoWorldCity(cityName: "London", timeZoneIdentifier: "Europe/London", teamNote: "Product Sync · Evening Wind-Down"),
                TempoWorldCity(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", teamNote: "Hardware Lab · Moody Night Standby"),
                TempoWorldCity(cityName: "New York", timeZoneIdentifier: "America/New_York", teamNote: "East Coast Ops · Afternoon Pace")
            ]
        }
    }
    
    public func saveAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            defaults.set(data, forKey: alarmsKey)
        }
        scheduleAlarmNotifications()
    }
    
    public func saveCities() {
        if let data = try? JSONEncoder().encode(worldCities) {
            defaults.set(data, forKey: citiesKey)
        }
    }
    
    // MARK: - 1. Alarms & Sleep Logic
    
    public func toggleAlarm(_ id: UUID) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].isEnabled.toggle()
        if !alarms[idx].isEnabled {
            alarms[idx].snoozedUntil = nil
            if activeRingingAlarmID == id { activeRingingAlarmID = nil }
        }
        TactileFeedback.light()
        saveAlarms()
    }
    
    public func triggerAlarmPreview(_ id: UUID) {
        if activeRingingAlarmID == id {
            activeRingingAlarmID = nil
        } else {
            activeRingingAlarmID = id
            TactileFeedback.heavy()
        }
    }
    
    public func snoozeAlarm(_ id: UUID, minutes: Int = 9) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        if activeRingingAlarmID == id { activeRingingAlarmID = nil }
        TactileFeedback.medium()
        saveAlarms()
    }
    
    /// Connected Time Chain: Dismissing an alarm can immediately launch its chained routine timer & SwiftData Session!
    public func dismissAlarmAndStartRoutine(_ alarm: TempoAlarm, context: ModelContext) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx].snoozedUntil = nil
        }
        if activeRingingAlarmID == alarm.id {
            activeRingingAlarmID = nil
        }
        saveAlarms()
        
        let taskTitle = alarm.chainedTaskTitle ?? alarm.label
        let estMins = alarm.chainedTaskMinutes ?? 20
        
        // Start linked bezel timer
        startTimer(title: taskTitle, seconds: estMins * 60, isRest: false, isKitchen: false)
        activeService = .timers
        selectedMainTab = 0
        mascotVoiceMessage = "Woke up & chained \(estMins)m bezel timer for \"\(taskTitle)\"."
        
        // Also log an active Session in SwiftData so Task Calibration tracks it automatically
        let session = Session(
            rawText: taskTitle,
            estimatedMinutes: estMins,
            startedAt: Date(),
            tempoResponse: "Chained from \(alarm.formattedTime) Twin-Bell Alarm — calibrating \(estMins)m block."
        )
        context.insert(session)
        try? context.save()
        TactileFeedback.success()
    }
    
    public func addAlarm(hour: Int, minute: Int, label: String, isBedtime: Bool, chainedTitle: String?, chainedMinutes: Int?) {
        let alarm = TempoAlarm(
            hour: hour,
            minute: minute,
            label: label.isEmpty ? "Tempo Alarm" : label,
            isEnabled: true,
            isBedtimeWindDown: isBedtime,
            chainedTaskTitle: (chainedTitle?.isEmpty == false) ? chainedTitle : nil,
            chainedTaskMinutes: chainedMinutes
        )
        alarms.append(alarm)
        alarms.sort { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
        saveAlarms()
        TactileFeedback.success()
    }
    
    public func deleteAlarm(_ id: UUID) {
        alarms.removeAll { $0.id == id }
        saveAlarms()
    }
    
    private func scheduleAlarmNotifications() {
        let center = UNUserNotificationCenter.current()
        for alarm in alarms {
            let identifier = "tempo.alarm.\(alarm.id.uuidString)"
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            guard alarm.isEnabled else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = alarm.isBedtimeWindDown ? "Tempo · Bedtime Wind-Down" : "Tempo · Twin-Bell Alarm"
            if let chain = alarm.chainedTaskTitle, let mins = alarm.chainedTaskMinutes {
                content.body = "\(alarm.label) — Ready to start your \(mins)m \(chain) block?"
            } else {
                content.body = alarm.label
            }
            content.sound = .default
            
            var comps = DateComponents()
            comps.hour = alarm.hour
            comps.minute = alarm.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(req)
        }
    }
    
    // MARK: - 2. Chronograph Stopwatch Logic
    
    public func chronoTotalElapsed(at now: Date = Date()) -> TimeInterval {
        if chronoIsRunning, let start = chronoStartedAt {
            return chronoAccumulatedSeconds + now.timeIntervalSince(start)
        }
        return chronoAccumulatedSeconds
    }
    
    public func chronoCurrentLapElapsed(at now: Date = Date()) -> TimeInterval {
        if chronoIsRunning, let lStart = chronoLapStartedAt {
            return chronoLapAccumulatedSeconds + now.timeIntervalSince(lStart)
        }
        return chronoLapAccumulatedSeconds
    }
    
    /// Right Orange Pusher Ear: Start / Stop Chronograph
    public func toggleChronoStartStop() {
        let now = Date()
        if chronoIsRunning {
            if let s = chronoStartedAt {
                chronoAccumulatedSeconds += now.timeIntervalSince(s)
            }
            if let ls = chronoLapStartedAt {
                chronoLapAccumulatedSeconds += now.timeIntervalSince(ls)
            }
            chronoStartedAt = nil
            chronoLapStartedAt = nil
            chronoIsRunning = false
            TactileFeedback.medium()
        } else {
            chronoStartedAt = now
            chronoLapStartedAt = now
            chronoIsRunning = true
            TactileFeedback.rigid()
        }
    }
    
    /// Left Black Pusher Ear: Record Lap Split (when running) or Reset (when stopped)
    public func pressChronoLeftEar() {
        let now = Date()
        if chronoIsRunning {
            let split = chronoCurrentLapElapsed(at: now)
            let total = chronoTotalElapsed(at: now)
            let lap = ChronoLap(
                lapNumber: chronoLaps.count + 1,
                splitSeconds: split,
                totalSeconds: total
            )
            chronoLaps.insert(lap, at: 0)
            chronoLapAccumulatedSeconds = 0
            chronoLapStartedAt = now
            lastLapSparkAt = now
            TactileFeedback.rigid()
        } else {
            // Reset to 00:00.00
            chronoAccumulatedSeconds = 0
            chronoLapAccumulatedSeconds = 0
            chronoStartedAt = nil
            chronoLapStartedAt = nil
            chronoLaps.removeAll()
            TactileFeedback.light()
        }
    }
    
    /// Breaks Apple Clock's disposable-time assumption: claims a stopwatch run or lap split as a calibrated SwiftData Session!
    public func claimChronoAsCalibratedTask(
        title: String,
        estimatedMinutes: Int,
        actualSeconds: TimeInterval,
        lapID: UUID? = nil,
        context: ModelContext
    ) {
        let actualMins = max(1, Int((actualSeconds / 60.0).rounded()))
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chronograph Sprint" : title
        let now = Date()
        let session = Session(
            rawText: cleanTitle,
            estimatedMinutes: max(1, estimatedMinutes),
            startedAt: now.addingTimeInterval(-actualSeconds),
            tempoResponse: "Claimed from Chronograph Stopwatch.",
            tempoEndResponse: "Logged \(actualMins)m actual vs \(estimatedMinutes)m estimate."
        )
        session.endedAt = now
        session.actualMinutes = actualMins
        context.insert(session)
        try? context.save()
        
        if let lapID, let idx = chronoLaps.firstIndex(where: { $0.id == lapID }) {
            chronoLaps[idx].claimedAsSession = true
            chronoLaps[idx].label = cleanTitle
        }
        mascotVoiceMessage = "Claimed \(actualMins)m stopwatch run as \"\(cleanTitle)\" (est. \(estimatedMinutes)m)."
        TactileFeedback.success()
    }
    
    // MARK: - 3. Bezel Timers, Natural-Language Task Input & Calibration Logic
    
    public func timerElapsed(at now: Date = Date()) -> TimeInterval {
        if timerIsRunning, let start = timerStartedAt {
            return timerAccumulatedSeconds + now.timeIntervalSince(start)
        }
        return timerAccumulatedSeconds
    }
    
    /// Positive when counting down, negative when in Honest Overtime (+m over)!
    public func timerRemaining(at now: Date = Date()) -> TimeInterval {
        Double(timerTargetSeconds) - timerElapsed(at: now)
    }
    
    /// Arms a preset on the bezel without starting it.
    public func selectTimerPreset(title: String, seconds: Int, isRest: Bool = false, isKitchen: Bool = false) {
        timerLinkedTaskTitle = title
        timerTargetSeconds = max(10, seconds)
        timerAccumulatedSeconds = 0
        timerStartedAt = nil
        timerIsRunning = false
        timerIsRestMode = isRest
        timerIsKitchenUtility = isKitchen
        TactileFeedback.selection()
    }
    
    public func startTimer(title: String, seconds: Int, isRest: Bool = false, isKitchen: Bool = false) {
        timerLinkedTaskTitle = title
        timerTargetSeconds = max(10, seconds)
        timerAccumulatedSeconds = 0
        timerStartedAt = Date()
        timerIsRunning = true
        timerIsRestMode = isRest
        timerIsKitchenUtility = isKitchen
        mascotVoiceMessage = "Calibrating \"\(title)\" · Target \(max(1, seconds / 60))m on the bezel."
        TactileFeedback.medium()
    }
    
    public var latestTravelResult: TravelAssessmentResult? = nil
    public var isCalculatingTravel: Bool = false
    
    /// Natural-Language Quick Input ("Design review 30m", "Ride to Airport", "Stop", "+5m", or conversational)
    func parseAndStartQuickInput(_ rawInput: String, sessions: [Session], context: ModelContext? = nil) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let intent = ChatParser.parse(trimmed, sessions: sessions)
        
        // 1. Stop / Done command
        if intent.isStopCommand {
            if timerIsRunning || timerAccumulatedSeconds > 0 {
                if let context {
                    completeAndCalibrateTimer(context: context)
                } else {
                    resetTimer()
                    mascotVoiceMessage = "Timer stopped and reset."
                }
            } else {
                mascotVoiceMessage = "No active timer running right now."
            }
            return
        }
        
        // 2. Extend command ("+5m", "add 10m")
        if let extendMins = intent.extendMinutes {
            extendTimer(bySeconds: extendMins * 60)
            return
        }
        
        // 3. Travel / Commute ETA query ("Ride to Airport", "Drive to Berlin")
        if intent.isTravelQuery {
            let dest = intent.destinationQuery ?? "Destination"
            let mode = intent.travelTransportMode ?? .driving
            isCalculatingTravel = true
            mascotVoiceMessage = "Checking live \(mode.actionTitle.lowercased()) route to \(dest)…"
            Task { @MainActor in
                let result = await LocationTravelManager.shared.calculateTravel(to: dest, mode: mode)
                self.isCalculatingTravel = false
                if let result {
                    self.latestTravelResult = result
                    self.mascotVoiceMessage = "\(result.destinationTitle): \(result.formattedDuration) (\(result.distanceString)) via \(result.transportTypeName)."
                } else {
                    self.mascotVoiceMessage = "Couldn't find route to \"\(dest)\"."
                }
            }
            return
        }
        
        // 4. Conversational / Status ("How am I doing?", "Hey", "Motivate me")
        if intent.isConversational, let reply = intent.conversationalReply {
            // Strip markdown asterisks for clean single-line pill
            mascotVoiceMessage = reply.replacingOccurrences(of: "**", with: "")
            TactileFeedback.light()
            return
        }
        
        // 5. Standard Task Timer ("Design review 30m" or "Code refactor")
        latestTravelResult = nil
        let parsedMins = intent.estimatedMinutes ?? ChatParser.extractMinutes(from: trimmed)
        let cleanTitle = RoutineEngine.normalizeTaskTitle(trimmed)
        let patterns = RoutineEngine.shared.minePatterns(from: sessions)
        let matchedPattern = patterns.first {
            $0.taskTitle.localizedCaseInsensitiveContains(cleanTitle) ||
            cleanTitle.localizedCaseInsensitiveContains($0.taskTitle)
        }
        
        let targetMins = parsedMins ?? matchedPattern?.typicalMinutes ?? (timerTargetSeconds / 60)
        startTimer(title: cleanTitle.isEmpty ? trimmed : cleanTitle, seconds: max(1, targetMins) * 60, isRest: false, isKitchen: false)
        
        if let pattern = matchedPattern {
            mascotVoiceMessage = "Routine: \"\(cleanTitle)\" usually takes \(pattern.typicalMinutes)m — started \(targetMins)m timer."
        } else if let parsedMins {
            mascotVoiceMessage = "Started \(parsedMins)m timer for \"\(cleanTitle)\"."
        } else {
            mascotVoiceMessage = "Started \(targetMins)m timer for \"\(cleanTitle)\"."
        }
    }
    
    public func toggleTimerPauseResume() {
        let now = Date()
        if timerIsRunning {
            if let s = timerStartedAt {
                timerAccumulatedSeconds += now.timeIntervalSince(s)
            }
            timerStartedAt = nil
            timerIsRunning = false
            TactileFeedback.light()
        } else {
            timerStartedAt = now
            timerIsRunning = true
            TactileFeedback.medium()
        }
    }
    
    public func extendTimer(bySeconds delta: Int) {
        timerTargetSeconds = max(30, timerTargetSeconds + delta)
        mascotVoiceMessage = "Extended \"\(timerLinkedTaskTitle)\" bezel target to \(timerTargetSeconds / 60)m."
        TactileFeedback.light()
    }
    
    public func resetTimer() {
        timerIsRunning = false
        timerStartedAt = nil
        timerAccumulatedSeconds = 0
        TactileFeedback.light()
    }
    
    /// Finishes the active timer and saves the Predicted vs. Actual duration into SwiftData for Task Calibration!
    public func completeAndCalibrateTimer(context: ModelContext) {
        let elapsed = timerElapsed()
        let actualMins = max(1, Int((elapsed / 60.0).rounded()))
        let estMins = max(1, Int((Double(timerTargetSeconds) / 60.0).rounded()))
        let now = Date()
        
        let session = Session(
            rawText: timerLinkedTaskTitle,
            estimatedMinutes: estMins,
            startedAt: now.addingTimeInterval(-max(60, elapsed)),
            tempoResponse: "Started from Bezel Timer (\(estMins)m target).",
            tempoEndResponse: actualMins <= estMins
                ? "Spot-on calibration! Finished in \(actualMins)m vs \(estMins)m target."
                : "Honest overtime logged: \(actualMins)m actual vs \(estMins)m target."
        )
        session.endedAt = now
        session.actualMinutes = actualMins
        context.insert(session)
        try? context.save()
        
        let diff = actualMins - estMins
        if abs(diff) <= 2 {
            mascotVoiceMessage = "Spot-on calibration! \"\(timerLinkedTaskTitle)\" took \(actualMins)m vs \(estMins)m est."
        } else if diff > 0 {
            mascotVoiceMessage = "Honest overtime logged: \"\(timerLinkedTaskTitle)\" took \(actualMins)m (+\(diff)m over \(estMins)m est)."
        } else {
            mascotVoiceMessage = "Finished early! \"\(timerLinkedTaskTitle)\" took \(actualMins)m (\(abs(diff))m under \(estMins)m est)."
        }
        
        resetTimer()
        TactileFeedback.success()
    }
    
    // MARK: - 4. World Clock & Overlap Timer Logic
    
    public func addWorldCity(name: String, tzIdentifier: String, note: String) {
        guard !name.isEmpty else { return }
        let city = TempoWorldCity(cityName: name, timeZoneIdentifier: tzIdentifier, teamNote: note)
        worldCities.append(city)
        saveCities()
        TactileFeedback.success()
    }
    
    public func removeWorldCity(_ id: UUID) {
        worldCities.removeAll { $0.id == id }
        saveCities()
    }
    
    /// Starts a countdown timer until a remote city's 9:00 AM morning overlap window!
    public func startOverlapCountdown(for city: TempoWorldCity) {
        let comp = city.localComponents()
        let remoteHour = comp.hour ?? 9
        let hoursUntil9AM = remoteHour < 9 ? (9 - remoteHour) : (24 - remoteHour + 9)
        let countdownSeconds = max(15 * 60, min(hoursUntil9AM * 3600, 4 * 3600))
        startTimer(
            title: "\(city.cityName) Sync Window",
            seconds: countdownSeconds,
            isRest: false,
            isKitchen: false
        )
        activeService = .timers
        selectedMainTab = 0
        mascotVoiceMessage = "Started overlap sync timer for \(city.cityName) (\(countdownSeconds / 60)m)."
    }
}
