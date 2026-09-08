import Foundation

/// The engine's answer for one category and context pair.
///
/// Never a bare number. Every feature that touches an estimate — capture, display,
/// the insight view, nudges — consumes this same object rather than reimplementing
/// its own version of the calculation.
public struct BiasEngineOutput: Hashable, Sendable, Identifiable {
    public let key: CategoryKey
    public var id: CategoryKey { key }
    /// Weighted average of `actual / estimated` across this dataset.
    public let multiplier: Double
    /// Weighted average of the raw actual durations, for pre-filling blind when the
    /// person has not guessed anything yet.
    public let averageActualMinutes: Double
    public let instanceCount: Int
    public let confidence: ConfidenceLevel
    /// True when the multiplier has shifted meaningfully in a short window: a new
    /// job, a new commute, a new baby. Worth surfacing rather than absorbing.
    public let driftFlag: Bool
    /// Whether this came from the exact pair or the broader parent category.
    public let scope: EstimateScope
    /// The same multiplier computed as of one instance ago, when there is enough
    /// history for it. Drives the "up 2m since last session" indicator.
    public let previousMultiplier: Double?
    /// The multiplier as it stood a window of instances back, which is the longer read
    /// behind "up from 2h 25m". A different question from the one-session delta, so it
    /// is a different number rather than the same one relabelled.
    public let trailingMultiplier: Double?

    public init(
        key: CategoryKey,
        multiplier: Double,
        averageActualMinutes: Double,
        instanceCount: Int,
        confidence: ConfidenceLevel,
        driftFlag: Bool,
        scope: EstimateScope,
        previousMultiplier: Double?,
        trailingMultiplier: Double?
    ) {
        self.key = key
        self.multiplier = multiplier
        self.averageActualMinutes = averageActualMinutes
        self.instanceCount = instanceCount
        self.confidence = confidence
        self.driftFlag = driftFlag
        self.scope = scope
        self.previousMultiplier = previousMultiplier
        self.trailingMultiplier = trailingMultiplier
    }

    /// How far this sits from a perfect guess, as a signed proportion.
    /// `+0.78` means sessions run 78% longer than guessed.
    public var deviation: Double { multiplier - 1 }

    /// Distance from 1 regardless of direction. Both running long and running short
    /// are equally real estimation gaps, so the ranking uses the absolute value.
    public var absoluteDeviation: Double { abs(deviation) }

    /// Plain sentence for the direction, matching the app's neutral voice.
    public var deviationDescription: String {
        if deviation > 0.005 { return "longer than you guess" }
        if deviation < -0.005 { return "shorter than you guess" }
        return "about what you guess"
    }
}
