import Foundation

/// One continuous stretch a tracked app was open, on device, with no content ever
/// inspected.
///
/// This is deliberately the whole payload: which app, when it opened, when it closed.
/// Nothing about what happened inside it. Whatever produces these — today, seeded
/// examples; eventually, Apple's DeviceActivity framework — hands over exactly this
/// much and no more.
public struct AppUsageInterval: Equatable, Sendable {
    public let appID: String
    public let start: Date
    public let end: Date

    public init(appID: String, start: Date, end: Date) {
        self.appID = appID
        self.start = start
        self.end = max(start, end)
    }

    public var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

/// Anything that can hand over today's tracked intervals.
///
/// The seam the real OS integration slots into. `SeededAppUsageProvider` is what runs
/// today; a `DeviceActivityUsageProvider` conforming to the same protocol is what
/// replaces it once the Family Controls entitlement is in place — nothing above this
/// protocol needs to change when that happens.
public protocol AppUsageProviding: Sendable {
    func intervals(on day: Date) -> [AppUsageInterval]
}

/// The four bands a day gets read against. Coarse on purpose: "TikTok in the morning,
/// not the evening" is the kind of pattern this is for, not a minute-by-minute log.
public enum DayPart: String, CaseIterable, Sendable {
    case morning, afternoon, evening, night

    /// Which band an hour of the day (0–23) falls into.
    public static func part(forHour hour: Int) -> DayPart {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    public var label: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }
}
