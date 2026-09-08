import Foundation

/// A candidate app eligible for passive tracking.
///
/// The concept calls for choosing these through iOS's own app picker. That picker lives
/// in the `FamilyControls` framework, which needs an entitlement Apple grants by manual
/// review, separate from and not guaranteed by a paid developer account — see
/// `DeviceActivityUsageProvider` for the detail. Until that is in place, the candidate
/// list is fixed here by hand rather than chosen freely, which is the one real
/// difference from the finished feature.
/// A tiny seeded generator, local to this file rather than shared with the app's own
/// demo data — Shared code cannot reach into the app target, and pulling a whole
/// generator across for one jitter helper is not worth the coupling.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func jitter(_ magnitude: Double) -> Double {
        let unit = Double(next() % 10_000) / 10_000
        return (unit * 2 - 1) * magnitude
    }
}

public struct TrackableApp: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let symbolName: String

    public init(id: String, displayName: String, symbolName: String) {
        self.id = id
        self.displayName = displayName
        self.symbolName = symbolName
    }

    public static let candidates: [TrackableApp] = [
        TrackableApp(id: "tiktok", displayName: "TikTok", symbolName: "play.rectangle"),
        TrackableApp(id: "instagram", displayName: "Instagram", symbolName: "camera"),
        TrackableApp(id: "youtube", displayName: "YouTube", symbolName: "play.tv"),
        TrackableApp(id: "x", displayName: "X", symbolName: "bubble.left"),
        TrackableApp(id: "reddit", displayName: "Reddit", symbolName: "bubble.left.and.bubble.right")
    ]
}

/// Deterministic stand-in data, shaped to actually demonstrate the point of the
/// feature: TikTok skewed toward mornings, Instagram toward evenings, so the trend
/// view has a real pattern to show rather than a flat, uninformative spread.
///
/// Filtered to only the apps the person has opted into, exactly as the real provider
/// will be — this is a difference in where the numbers come from, not in how the rest
/// of the pipeline treats them.
public struct SeededAppUsageProvider: AppUsageProviding {
    private let enabledAppIDs: Set<String>

    public init(enabledAppIDs: Set<String>) {
        self.enabledAppIDs = enabledAppIDs
    }

    public func intervals(on day: Date) -> [AppUsageInterval] {
        var generator = SplitMix64(seed: seed(for: day))
        var intervals: [AppUsageInterval] = []
        let calendar = Calendar.current

        func minutesJitter(_ base: Double, _ magnitude: Double) -> Int {
            max(2, Int((base + generator.jitter(magnitude)).rounded()))
        }

        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        if enabledAppIDs.contains("tiktok") {
            for (hour, minute) in [(7, 40), (8, 15), (9, 5)] {
                let duration = minutesJitter(14, 6)
                intervals.append(interval("tiktok", at(hour, minute), duration))
            }
            intervals.append(interval("tiktok", at(21, 30), minutesJitter(4, 2)))
        }

        if enabledAppIDs.contains("instagram") {
            intervals.append(interval("instagram", at(8, 10), minutesJitter(5, 2)))
            for (hour, minute) in [(19, 20), (20, 45), (22, 10)] {
                let duration = minutesJitter(12, 5)
                intervals.append(interval("instagram", at(hour, minute), duration))
            }
        }

        if enabledAppIDs.contains("youtube") {
            intervals.append(interval("youtube", at(13, 0), minutesJitter(18, 6)))
            intervals.append(interval("youtube", at(21, 15), minutesJitter(22, 8)))
        }

        return intervals
    }

    private func interval(_ appID: String, _ start: Date, _ minutes: Int) -> AppUsageInterval {
        AppUsageInterval(appID: appID, start: start, end: start.addingTimeInterval(Double(minutes) * 60))
    }

    /// A distinct, stable seed per calendar day, so the same day always regenerates the
    /// same pattern rather than a new random one on every read.
    private func seed(for day: Date) -> UInt64 {
        let days = Int(day.timeIntervalSince1970 / 86_400)
        return UInt64(bitPattern: Int64(20_260_908 &+ days))
    }
}
