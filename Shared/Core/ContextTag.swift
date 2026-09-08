import Foundation

/// A context tag describes the *situation* a session happened in, chosen at capture
/// time rather than afterward. `normal` is one context among several, not a baseline
/// the others deviate from.
///
/// Defaults ship as a fixed set so there is no setup on day one. Custom tags are
/// stored identically once created, with no structural difference from a default.
public struct ContextTag: Hashable, Codable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static let normal = ContextTag("normal")
    public static let highPressure = ContextTag("high pressure")
    public static let lowEnergy = ContextTag("low energy")
    public static let distracted = ContextTag("distracted")

    /// The fixed set every person starts with.
    public static let defaults: [ContextTag] = [.normal, .highPressure, .lowEnergy, .distracted]

    public var isDefault: Bool { Self.defaults.contains(self) }

    /// Title-cased for display: "high pressure" renders as "High pressure".
    public var displayName: String {
        guard let first = rawValue.first else { return rawValue }
        return first.uppercased() + rawValue.dropFirst()
    }
}

extension ContextTag: CustomStringConvertible {
    public var description: String { rawValue }
}
