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
    /// Calendar weekdays (1 = Sunday … 7 = Saturday). `nil` or empty means every day.
    public var repeatWeekdays: [Int]?
    
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
        snoozedUntil: Date? = nil,
        repeatWeekdays: [Int]? = nil
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
        self.repeatWeekdays = repeatWeekdays
    }
    
    public var activeWeekdays: [Int] {
        let days = (repeatWeekdays ?? []).filter { (1...7).contains($0) }
        return days.isEmpty ? Array(1...7) : Array(Set(days)).sorted()
    }
    
    public func ringsOn(weekday: Int) -> Bool {
        activeWeekdays.contains(weekday)
    }
    
    /// Changes whenever the alarm needs to be rescheduled with the system.
    public var scheduleSignature: String {
        "\(hour):\(minute)|\(activeWeekdays.map(String.init).joined(separator: ","))|\(label)"
    }
    
    /// "Every day", "Weekdays", "Weekends" or short day names.
    public var repeatSummary: String {
        let days = activeWeekdays
        if days.count == 7 { return "Every day" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days == [1, 7] { return "Weekends" }
        let symbols = Calendar.current.shortWeekdaySymbols
        return days.map { symbols[$0 - 1] }.joined(separator: " ")
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
    public var mascotVoiceMessage: String = "Hi, I'm Tempo. Tell me what you're working on, like \"Design review 30m\", or drag the numbers to set a timer."
    
    // --- 1. ALARMS STATE ---
    public var alarms: [TempoAlarm] = []
    /// The alarm currently ringing (in-app chime, AlarmKit alert, or a preview).
    public var activeRingingAlarmID: UUID? = nil
    /// True while AlarmKit plays the sound, so the app must not ring on top of it.
    public var ringingIsSystemAlarm: Bool = false
    /// True when the ring was started from the mascot as a sound check.
    public var ringingIsPreview: Bool = false
    
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
    /// The countdown reached zero and the app is ringing for it.
    public var timerAlertActive: Bool = false
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
    
    /// Set by ContentView so notification actions ("Done & log") can write sessions.
    @ObservationIgnored public var modelContext: ModelContext?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var timerZeroHandled = false
    @ObservationIgnored private var recentlyHandledAlarms: [UUID: Date] = [:]
    
    private let defaults = UserDefaults.standard
    private let alarmsKey = "tempo.timeos.alarms.v2"
    private let citiesKey = "tempo.timeos.cities.v2"
    private let runtimeKey = "tempo.timeos.runtime.v1"
    
    private init() {
        loadPersistedState()
        loadRuntimeState()
        startHeartbeat()
    }
    
    // MARK: - Persistence
    
    public func loadPersistedState() {
        if let data = defaults.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([TempoAlarm].self, from: data) {
            alarms = decoded
        } else {
            // Starter alarms ship switched off. Real alarms must never ring unless the user asked.
            alarms = [
                TempoAlarm(
                    hour: 7,
                    minute: 0,
                    label: "Wake Up",
                    isEnabled: false,
                    chainedTaskTitle: "Morning Routine",
                    chainedTaskMinutes: 20
                ),
                TempoAlarm(
                    hour: 8,
                    minute: 25,
                    label: "Commute",
                    isEnabled: false,
                    isCommuteAutoCalibrated: true,
                    chainedTaskTitle: "Commute",
                    chainedTaskMinutes: 30
                ),
                TempoAlarm(
                    hour: 23,
                    minute: 0,
                    label: "Sleep",
                    isEnabled: false,
                    isBedtimeWindDown: true
                )
            ]
        }
        
        if let cData = defaults.data(forKey: citiesKey),
           let cDecoded = try? JSONDecoder().decode([TempoWorldCity].self, from: cData) {
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
        TempoAlarmScheduler.shared.sync(alarms)
    }
    
    /// Timer and stopwatch survive the app being closed or killed.
    private struct RuntimeSnapshot: Codable {
        var timerTargetSeconds: Int
        var timerLinkedTaskTitle: String
        var timerIsRunning: Bool
        var timerStartedAt: Date?
        var timerAccumulatedSeconds: TimeInterval
        var timerIsRestMode: Bool
        var timerIsKitchenUtility: Bool
        var chronoIsRunning: Bool
        var chronoStartedAt: Date?
        var chronoAccumulatedSeconds: TimeInterval
        var chronoLapStartedAt: Date?
        var chronoLapAccumulatedSeconds: TimeInterval
        var chronoLaps: [ChronoLap]
    }
    
    public func persistRuntimeState() {
        let snapshot = RuntimeSnapshot(
            timerTargetSeconds: timerTargetSeconds,
            timerLinkedTaskTitle: timerLinkedTaskTitle,
            timerIsRunning: timerIsRunning,
            timerStartedAt: timerStartedAt,
            timerAccumulatedSeconds: timerAccumulatedSeconds,
            timerIsRestMode: timerIsRestMode,
            timerIsKitchenUtility: timerIsKitchenUtility,
            chronoIsRunning: chronoIsRunning,
            chronoStartedAt: chronoStartedAt,
            chronoAccumulatedSeconds: chronoAccumulatedSeconds,
            chronoLapStartedAt: chronoLapStartedAt,
            chronoLapAccumulatedSeconds: chronoLapAccumulatedSeconds,
            chronoLaps: chronoLaps
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: runtimeKey)
        }
    }
    
    private func loadRuntimeState() {
        // Snoozes that ran out while the app was closed are over.
        for idx in alarms.indices {
            if let until = alarms[idx].snoozedUntil, until < Date().addingTimeInterval(-5 * 60) {
                alarms[idx].snoozedUntil = nil
            }
        }
        guard let data = defaults.data(forKey: runtimeKey),
              let snap = try? JSONDecoder().decode(RuntimeSnapshot.self, from: data) else { return }
        timerTargetSeconds = snap.timerTargetSeconds
        timerLinkedTaskTitle = snap.timerLinkedTaskTitle
        timerIsRunning = snap.timerIsRunning
        timerStartedAt = snap.timerStartedAt
        timerAccumulatedSeconds = snap.timerAccumulatedSeconds
        timerIsRestMode = snap.timerIsRestMode
        timerIsKitchenUtility = snap.timerIsKitchenUtility
        chronoIsRunning = snap.chronoIsRunning
        chronoStartedAt = snap.chronoStartedAt
        chronoAccumulatedSeconds = snap.chronoAccumulatedSeconds
        chronoLapStartedAt = snap.chronoLapStartedAt
        chronoLapAccumulatedSeconds = snap.chronoLapAccumulatedSeconds
        chronoLaps = snap.chronoLaps
        // The notification already rang for a timer that ended while we were closed.
        timerZeroHandled = timerRemaining() <= 0
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
            if activeRingingAlarmID == id { stopAlarm(id) }
        }
        TactileFeedback.light()
        saveAlarms()
    }
    
    /// Sound check from the mascot: rings the alarm right now without touching its schedule.
    public func triggerAlarmPreview(_ id: UUID) {
        if activeRingingAlarmID == id {
            stopAlarm(id)
        } else {
            ringAlarm(id, playSound: true, force: true)
            ringingIsPreview = true
        }
    }
    
    /// Starts ringing in the app. Ignores repeats of an occurrence the user already handled.
    public func ringAlarm(_ id: UUID, playSound: Bool = true, force: Bool = false) {
        guard alarms.contains(where: { $0.id == id }) else { return }
        if activeRingingAlarmID == id { return }
        if !force, let handled = recentlyHandledAlarms[id], Date().timeIntervalSince(handled) < 5 * 60 { return }
        timerAlertActive = false
        activeRingingAlarmID = id
        ringingIsSystemAlarm = false
        ringingIsPreview = false
        if playSound {
            TempoSoundEngine.shared.startRinging()
        }
        TactileFeedback.heavy()
    }
    
    /// Called by AlarmKit updates: the mascot rings along with the system alert.
    public func systemAlarmStateChanged(alertingID: UUID?) {
        if let alertingID {
            guard activeRingingAlarmID != alertingID else { return }
            TempoSoundEngine.shared.stopRinging()
            activeRingingAlarmID = alertingID
            ringingIsSystemAlarm = true
            ringingIsPreview = false
        } else if ringingIsSystemAlarm {
            if let id = activeRingingAlarmID { recentlyHandledAlarms[id] = Date() }
            activeRingingAlarmID = nil
            ringingIsSystemAlarm = false
        }
    }
    
    /// Stop: silences the ring and clears any queued follow-up rings for this occurrence.
    public func stopAlarm(_ id: UUID) {
        let wasPreview = ringingIsPreview
        TempoSoundEngine.shared.stopRinging()
        if activeRingingAlarmID == id {
            activeRingingAlarmID = nil
        }
        ringingIsSystemAlarm = false
        ringingIsPreview = false
        guard !wasPreview else { return }
        recentlyHandledAlarms[id] = Date()
        TempoAlarmScheduler.shared.silenceCurrentOccurrence(of: id, keepSnooze: false)
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        mascotVoiceMessage = alarms[idx].isBedtimeWindDown
            ? "Wind-down time. Phone down, sleep well."
            : "Alarm off. Have a good one."
        if alarms[idx].snoozedUntil != nil {
            alarms[idx].snoozedUntil = nil
            saveAlarms()
        }
    }
    
    public func snoozeAlarm(_ id: UUID, minutes: Int = 9) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        if ringingIsPreview {
            stopAlarm(id)
            return
        }
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        alarms[idx].snoozedUntil = until
        TempoSoundEngine.shared.stopRinging()
        if activeRingingAlarmID == id { activeRingingAlarmID = nil }
        ringingIsSystemAlarm = false
        recentlyHandledAlarms[id] = Date()
        TempoAlarmScheduler.shared.snooze(alarms[idx], until: until)
        TactileFeedback.medium()
        saveAlarms()
    }
    
    /// Connected Time Chain: Dismissing an alarm can immediately launch its chained routine timer & SwiftData Session!
    public func dismissAlarmAndStartRoutine(_ alarm: TempoAlarm, context: ModelContext) {
        stopAlarm(alarm.id)
        
        let taskTitle = alarm.chainedTaskTitle ?? alarm.label
        let estMins = alarm.chainedTaskMinutes ?? 20
        
        // Start linked bezel timer
        startTimer(title: taskTitle, seconds: estMins * 60, isRest: false, isKitchen: false)
        activeService = .timers
        selectedMainTab = 0
        mascotVoiceMessage = "Good morning. \(estMins)m on the clock for \"\(taskTitle)\"."
        
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
    
    public func addAlarm(hour: Int, minute: Int, label: String, isBedtime: Bool, chainedTitle: String?, chainedMinutes: Int?, repeatWeekdays: [Int]? = nil) {
        let alarm = TempoAlarm(
            hour: hour,
            minute: minute,
            label: label.isEmpty ? "Alarm" : label,
            isEnabled: true,
            isBedtimeWindDown: isBedtime,
            chainedTaskTitle: (chainedTitle?.isEmpty == false) ? chainedTitle : nil,
            chainedTaskMinutes: chainedMinutes,
            repeatWeekdays: repeatWeekdays
        )
        alarms.append(alarm)
        sortAlarms()
        saveAlarms()
        mascotVoiceMessage = "Alarm set for \(alarm.formattedTime)."
        TactileFeedback.success()
    }
    
    public func updateAlarm(_ alarm: TempoAlarm) {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        var updated = alarm
        updated.isEnabled = true
        updated.snoozedUntil = nil
        alarms[idx] = updated
        sortAlarms()
        saveAlarms()
        TactileFeedback.success()
    }
    
    public func deleteAlarm(_ id: UUID) {
        if activeRingingAlarmID == id { stopAlarm(id) }
        alarms.removeAll { $0.id == id }
        saveAlarms()
    }
    
    private func sortAlarms() {
        alarms.sort { ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute) }
    }
    
    /// The next time any enabled alarm rings, snoozes included.
    public func nextAlarmFire(after now: Date = Date()) -> (alarm: TempoAlarm, date: Date)? {
        var best: (TempoAlarm, Date)?
        for alarm in alarms where alarm.isEnabled {
            var candidates = Array(TempoAlarmScheduler.nextFireDates(for: alarm, after: now, within: 7).prefix(1))
            if let snooze = alarm.snoozedUntil, snooze > now { candidates.append(snooze) }
            for date in candidates where best.map({ date < $0.1 }) ?? true {
                best = (alarm, date)
            }
        }
        return best.map { (alarm: $0.0, date: $0.1) }
    }
    
    // MARK: - Heartbeat (rings alarms and timers while the app is open)
    
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { @MainActor [weak self] in
            var lastCheck = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                let now = Date()
                // A long gap means the app was suspended; notifications covered that stretch.
                if now.timeIntervalSince(lastCheck) < 30 {
                    self.checkDueAlarms(from: lastCheck, to: now)
                }
                self.checkTimerZero(at: now)
                lastCheck = now
            }
        }
    }
    
    private func checkDueAlarms(from start: Date, to end: Date) {
        // AlarmKit plays its own alert and reports it through systemAlarmStateChanged.
        guard !TempoAlarmScheduler.shared.usesSystemAlarms else { return }
        let cal = Calendar.current
        for alarm in alarms where alarm.isEnabled {
            if let snooze = alarm.snoozedUntil, snooze > start, snooze <= end {
                ringAlarm(alarm.id, force: true)
                return
            }
            guard let fire = cal.nextDate(
                after: start,
                matching: DateComponents(hour: alarm.hour, minute: alarm.minute, second: 0),
                matchingPolicy: .nextTime
            ), fire <= end, alarm.ringsOn(weekday: cal.component(.weekday, from: fire)) else { continue }
            ringAlarm(alarm.id)
            return
        }
    }
    
    private func checkTimerZero(at now: Date) {
        guard timerIsRunning, !timerZeroHandled, timerRemaining(at: now) <= 0 else { return }
        timerReachedZero()
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
        persistRuntimeState()
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
        persistRuntimeState()
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
        persistRuntimeState()
        mascotVoiceMessage = "Saved \(actualMins)m as \"\(cleanTitle)\" in your logbook."
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
        silenceTimerAlert()
        TempoAlarmScheduler.shared.cancelTimerEnd()
        persistRuntimeState()
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
        timerZeroHandled = false
        silenceTimerAlert()
        scheduleTimerEndNotification()
        persistRuntimeState()
        mascotVoiceMessage = "On it. \(TempoFormat.minutes(timerTargetSeconds)) for \"\(title)\"."
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
        silenceTimerAlert()
        if timerIsRunning {
            if let s = timerStartedAt {
                timerAccumulatedSeconds += now.timeIntervalSince(s)
            }
            timerStartedAt = nil
            timerIsRunning = false
            TempoAlarmScheduler.shared.cancelTimerEnd()
            mascotVoiceMessage = "Paused. Tap play when you're back."
            TactileFeedback.light()
        } else {
            if timerAccumulatedSeconds == 0 {
                timerZeroHandled = false
                mascotVoiceMessage = "On it. \(TempoFormat.minutes(timerTargetSeconds)) for \"\(timerLinkedTaskTitle)\"."
            }
            timerStartedAt = now
            timerIsRunning = true
            scheduleTimerEndNotification()
            TactileFeedback.medium()
        }
        persistRuntimeState()
    }
    
    public func extendTimer(bySeconds delta: Int) {
        timerTargetSeconds = max(30, timerTargetSeconds + delta)
        if timerRemaining() > 0 {
            timerZeroHandled = false
            silenceTimerAlert()
        }
        if timerIsRunning { scheduleTimerEndNotification() }
        persistRuntimeState()
        mascotVoiceMessage = "+\(max(1, delta / 60))m. New target \(TempoFormat.minutes(timerTargetSeconds))."
        TactileFeedback.light()
    }
    
    public func resetTimer() {
        timerIsRunning = false
        timerStartedAt = nil
        timerAccumulatedSeconds = 0
        timerZeroHandled = false
        silenceTimerAlert()
        TempoAlarmScheduler.shared.cancelTimerEnd()
        persistRuntimeState()
        TactileFeedback.light()
    }
    
    /// Countdown hit 00:00 with the app open: ring, and keep counting honest overtime.
    public func timerReachedZero() {
        guard !timerZeroHandled else { return }
        timerZeroHandled = true
        guard activeRingingAlarmID == nil else { return }
        timerAlertActive = true
        TempoSoundEngine.shared.startRinging(maxDuration: 60)
        mascotVoiceMessage = "Time's up for \"\(timerLinkedTaskTitle)\". Log it, or keep going and I'll count the overtime."
        TactileFeedback.success()
    }
    
    /// Stops the chime but leaves the timer running into overtime.
    public func silenceTimerAlert() {
        guard timerAlertActive else { return }
        timerAlertActive = false
        if activeRingingAlarmID == nil {
            TempoSoundEngine.shared.stopRinging()
        }
    }
    
    private func scheduleTimerEndNotification() {
        let remaining = timerRemaining()
        guard timerIsRunning, remaining > 0 else {
            TempoAlarmScheduler.shared.cancelTimerEnd()
            return
        }
        TempoAlarmScheduler.shared.scheduleTimerEnd(
            title: timerLinkedTaskTitle,
            targetMinutes: max(1, timerTargetSeconds / 60),
            in: remaining
        )
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
