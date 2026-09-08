import Foundation

/// How much history a number rests on. A number built on two data points must not
/// look as authoritative as one built on forty, so this drives a visual treatment
/// rather than only a label.
public enum ConfidenceLevel: Int, Comparable, Sendable, CaseIterable {
    /// Below the minimum threshold. No recalibrated number is shown at all.
    case none = 0
    /// Roughly 5 to 15 instances. Rendered muted, with the instance count stated plainly.
    case low = 1
    /// Roughly 15 to 40. Full visual weight, instance count still shown.
    case medium = 2
    /// 40 or more. Full weight, and the instance count can recede to a secondary label.
    case high = 3

    public static func < (lhs: ConfidenceLevel, rhs: ConfidenceLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var isUsable: Bool { self != .none }

    public var label: String {
        switch self {
        case .none: return "not enough history"
        case .low: return "low confidence"
        case .medium: return "medium confidence"
        case .high: return "high confidence"
        }
    }
}
