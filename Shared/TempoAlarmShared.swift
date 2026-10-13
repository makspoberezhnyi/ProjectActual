import Foundation
import AppIntents
#if canImport(AlarmKit)
import AlarmKit

/// Shared by the app (which schedules alarms) and the widget extension (which draws their Live Activity).
@available(iOS 26.0, *)
public struct TempoAlarmMetadata: AlarmMetadata {
    public init() {}
}

/// "I'm up" on the snooze Live Activity: ends the alarm for good instead of waiting for the next ring.
@available(iOS 26.0, *)
public struct StopTempoAlarmIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Stop Alarm"
    public static let description = IntentDescription("Stops a snoozing or ringing Tempo alarm.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Alarm ID")
    public var alarmID: String

    public init() {
        self.alarmID = ""
    }

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        return .result()
    }
}
#endif
