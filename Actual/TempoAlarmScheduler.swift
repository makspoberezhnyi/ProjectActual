import Foundation
import SwiftUI
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import ActivityKit
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct TempoAlarmMetadata: AlarmMetadata {}
#endif

/// Owns everything that has to fire while Tempo is closed: alarms and the end of a running timer.
///
/// iOS 26+: alarms go through AlarmKit, so they ring like the system Clock app
/// (full screen, through silent mode and Focus, with Stop and Snooze).
/// Older iOS or no AlarmKit permission: each alarm becomes a short chain of notifications
/// with the twin-bell chime, so a missed first ring gets a second and third try.
@MainActor
final class TempoAlarmScheduler {
    static let shared = TempoAlarmScheduler()

    nonisolated static let alarmPrefix = "tempo.alarm."
    nonisolated static let snoozePrefix = "tempo.alarm.snooze."
    nonisolated static let timerIdentifier = "tempo.timer.end"

    nonisolated static let alarmCategory = "TEMPO_ALARM_CATEGORY"
    nonisolated static let timerCategory = "TEMPO_TIMER_CATEGORY"
    nonisolated static let snoozeAction = "TEMPO_ALARM_SNOOZE"
    nonisolated static let wakeAction = "TEMPO_ALARM_WAKE"
    nonisolated static let timerDoneAction = "TEMPO_TIMER_DONE"
    nonisolated static let timerExtendAction = "TEMPO_TIMER_EXTEND_5"

    /// Follow-up rings for the notification fallback (minutes after the alarm time).
    private let followUpMinutes = [1, 3]
    /// How many days ahead the notification fallback is scheduled.
    private let lookaheadDays = 2

    /// True when alarms are handed to AlarmKit and the system plays the alert.
    private(set) var usesSystemAlarms = false
    private var isObservingSystemAlarms = false

    private let signaturesKey = "tempo.alarmkit.signatures.v1"

    private init() {}

    // MARK: - Permissions

    /// Asks for AlarmKit (iOS 26+) and notification permission. Safe to call often.
    func requestPermissions() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await NotificationManager.shared.checkAuthorizationStatus()

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            let manager = AlarmManager.shared
            if manager.authorizationState == .notDetermined {
                _ = try? await manager.requestAuthorization()
            }
            usesSystemAlarms = manager.authorizationState == .authorized
            if usesSystemAlarms { observeSystemAlarms() }
        }
        #endif
    }

    // MARK: - Alarms

    func sync(_ alarms: [TempoAlarm]) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), AlarmManager.shared.authorizationState == .authorized {
            usesSystemAlarms = true
            observeSystemAlarms()
            Task { await syncSystemAlarms(alarms) }
            return
        }
        #endif
        usesSystemAlarms = false
        syncNotificationAlarms(alarms)
    }

    /// Clears the rings that are still queued for the occurrence the user just dismissed.
    func silenceCurrentOccurrence(of alarmID: UUID, keepSnooze: Bool = false) {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), usesSystemAlarms, !keepSnooze {
            try? AlarmManager.shared.stop(id: alarmID)
        }
        #endif
        let prefix = Self.alarmPrefix + alarmID.uuidString
        let snoozeID = keepSnooze ? "" : Self.snoozePrefix + alarmID.uuidString
        let horizon = Date().addingTimeInterval(10 * 60)
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let ids = pending.compactMap { req -> String? in
                guard req.identifier.hasPrefix(prefix) || req.identifier == snoozeID else { return nil }
                let next = (req.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                    ?? (req.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                guard let next, next <= horizon else { return nil }
                return req.identifier
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let ids = delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) || $0 == snoozeID }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    /// Snooze: AlarmKit counts down by itself; the fallback queues one more ring.
    func snooze(_ alarm: TempoAlarm, until date: Date) {
        silenceCurrentOccurrence(of: alarm.id, keepSnooze: true)
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *), usesSystemAlarms {
            try? AlarmManager.shared.countdown(id: alarm.id)
            return
        }
        #endif
        let content = alarmContent(for: alarm, followUp: false)
        content.title = "Tempo · Snooze over"
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.snoozePrefix + alarm.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Next times an alarm rings, respecting its repeat days.
    static func nextFireDates(for alarm: TempoAlarm, after now: Date, within days: Int) -> [Date] {
        let cal = Calendar.current
        let horizon = cal.date(byAdding: .day, value: days, to: now) ?? now
        var dates: [Date] = []
        var cursor = now
        while dates.count < days + 1 {
            guard let next = cal.nextDate(
                after: cursor,
                matching: DateComponents(hour: alarm.hour, minute: alarm.minute, second: 0),
                matchingPolicy: .nextTime
            ), next <= horizon else { break }
            if alarm.ringsOn(weekday: cal.component(.weekday, from: next)) {
                dates.append(next)
            }
            cursor = next.addingTimeInterval(60)
        }
        return dates
    }

    // MARK: - Timer end

    func scheduleTimerEnd(title: String, targetMinutes: Int, in seconds: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.timerIdentifier])
        guard seconds > 0.5 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time's up · \(title)"
        content.body = "Your \(targetMinutes)m block is done. Log it, or give yourself 5 more minutes."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(TempoSoundEngine.chimeFileName))
        content.categoryIdentifier = Self.timerCategory
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.timerIdentifier, content: content, trigger: trigger))
    }

    func cancelTimerEnd() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.timerIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.timerIdentifier])
    }

    // MARK: - Notification fallback

    private func alarmContent(for alarm: TempoAlarm, followUp: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        if followUp {
            content.title = "Still ringing · \(alarm.label)"
        } else {
            content.title = alarm.isBedtimeWindDown ? "Tempo · Wind down" : "Tempo · \(alarm.label)"
        }
        if let chain = alarm.chainedTaskTitle, let mins = alarm.chainedTaskMinutes {
            content.body = "\(alarm.formattedTime). Tap Wake up to start your \(mins)m \(chain) block."
        } else {
            content.body = alarm.formattedTime
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName(TempoSoundEngine.chimeFileName))
        content.categoryIdentifier = Self.alarmCategory
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["alarmID": alarm.id.uuidString]
        return content
    }

    private func syncNotificationAlarms(_ alarms: [TempoAlarm]) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMddHHmm"
        stamp.locale = Locale(identifier: "en_US_POSIX")

        // Adding an identifier that already exists replaces it, so add first and prune the rest after.
        var keep: Set<String> = []
        for alarm in alarms where alarm.isEnabled {
            if let snooze = alarm.snoozedUntil, snooze > now {
                keep.insert(Self.snoozePrefix + alarm.id.uuidString)
            }
            for fire in Self.nextFireDates(for: alarm, after: now, within: lookaheadDays) {
                let base = Self.alarmPrefix + alarm.id.uuidString + "." + stamp.string(from: fire)
                for offset in [0] + followUpMinutes {
                    let identifier = "\(base).\(offset)"
                    let date = fire.addingTimeInterval(TimeInterval(offset * 60))
                    let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                    center.add(UNNotificationRequest(
                        identifier: identifier,
                        content: alarmContent(for: alarm, followUp: offset > 0),
                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    ))
                    keep.insert(identifier)
                }
            }
        }

        let alarmPrefix = Self.alarmPrefix
        let keepIDs = keep
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(alarmPrefix) && !keepIDs.contains($0) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    // MARK: - AlarmKit

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func syncSystemAlarms(_ alarms: [TempoAlarm]) async {
        let manager = AlarmManager.shared
        var signatures = (UserDefaults.standard.dictionary(forKey: signaturesKey) as? [String: String]) ?? [:]
        let wanted = Dictionary(uniqueKeysWithValues: alarms.filter(\.isEnabled).map { ($0.id.uuidString, $0) })

        // Drop alarms that were deleted or switched off.
        for id in signatures.keys where wanted[id] == nil {
            if let uuid = UUID(uuidString: id) { try? manager.cancel(id: uuid) }
            signatures[id] = nil
        }

        // Schedule new or edited alarms. Unchanged ones are left alone so a running snooze survives.
        var failed: [TempoAlarm] = []
        for (id, alarm) in wanted where signatures[id] != alarm.scheduleSignature {
            try? manager.cancel(id: alarm.id)
            if await scheduleSystemAlarm(alarm) {
                signatures[id] = alarm.scheduleSignature
            } else {
                signatures[id] = nil
                failed.append(alarm)
            }
        }
        UserDefaults.standard.set(signatures, forKey: signaturesKey)

        // If AlarmKit refused an alarm, it still rings through notifications.
        if !failed.isEmpty {
            syncNotificationAlarms(failed)
            return
        }

        // Any leftover notification rings from the fallback would double up with AlarmKit.
        let alarmPrefix = Self.alarmPrefix
        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(alarmPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: stale)
        }
    }

    @available(iOS 26.0, *)
    private func scheduleSystemAlarm(_ alarm: TempoAlarm) async -> Bool {
        let title = LocalizedStringResource(stringLiteral: alarm.label)
        let stop = AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill")
        let snooze = AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz")

        let weekdays: [Locale.Weekday] = alarm.activeWeekdays.compactMap { Self.localeWeekday($0) }
        let schedule = Alarm.Schedule.relative(.init(
            time: .init(hour: alarm.hour, minute: alarm.minute),
            repeats: .weekly(weekdays)
        ))

        // First choice: Stop + 9 minute Snooze.
        let snoozingAlert = AlarmPresentation.Alert(
            title: title,
            stopButton: stop,
            secondaryButton: snooze,
            secondaryButtonBehavior: .countdown
        )
        let withSnooze = AlarmManager.AlarmConfiguration<TempoAlarmMetadata>(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60),
            schedule: schedule,
            attributes: AlarmAttributes(
                presentation: AlarmPresentation(alert: snoozingAlert),
                metadata: TempoAlarmMetadata(),
                tintColor: Color.tempoAccent
            ),
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )
        if (try? await AlarmManager.shared.schedule(id: alarm.id, configuration: withSnooze)) != nil {
            return true
        }

        // Fallback: Stop only.
        let plainAlert = AlarmPresentation.Alert(
            title: title,
            stopButton: stop,
            secondaryButton: nil,
            secondaryButtonBehavior: nil
        )
        let plain = AlarmManager.AlarmConfiguration<TempoAlarmMetadata>(
            countdownDuration: nil,
            schedule: schedule,
            attributes: AlarmAttributes(
                presentation: AlarmPresentation(alert: plainAlert),
                metadata: TempoAlarmMetadata(),
                tintColor: Color.tempoAccent
            ),
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )
        return (try? await AlarmManager.shared.schedule(id: alarm.id, configuration: plain)) != nil
    }

    /// Mirrors the system alarm state into the store so the mascot rings along with the system alert.
    @available(iOS 26.0, *)
    private func observeSystemAlarms() {
        guard !isObservingSystemAlarms else { return }
        isObservingSystemAlarms = true
        Task { @MainActor in
            for await alarms in AlarmManager.shared.alarmUpdates {
                let alerting = alarms.first { $0.state == .alerting }?.id
                TimeOSStore.shared.systemAlarmStateChanged(alertingID: alerting)
            }
        }
    }

    @available(iOS 26.0, *)
    private static func localeWeekday(_ calendarWeekday: Int) -> Locale.Weekday? {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return nil
        }
    }
    #endif
}
