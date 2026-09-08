import Foundation

/// The plain-value view of a closed session that the bias engine reads.
///
/// This deliberately knows nothing about SwiftData, CloudKit or SwiftUI. The
/// persistence layer maps its own models down into these before handing them to
/// the engine, which keeps the whole calculation testable with literals.
public struct SessionRecord: Hashable, Sendable {
    public let id: UUID
    public let categoryID: String
    public let contextTag: ContextTag
    /// The person's own guess, in minutes. `nil` when they skipped it.
    public let estimatedMinutes: Int?
    /// The measured duration in minutes. `nil` while the session is still open.
    public let actualMinutes: Int?
    /// When the session closed. Used for recency weighting.
    public let endedAt: Date
    /// Set when a session auto-closed against its ceiling rather than being ended
    /// deliberately. Flagged sessions stay visible as outliers but are excluded
    /// from the weighted average.
    public let isFlaggedLowConfidence: Bool
    /// What a routing service predicted, where one was consulted. Always optional: the
    /// call can fail, time out, or simply not apply.
    public let apiBaselineMinutes: Int?

    public init(
        id: UUID = UUID(),
        categoryID: String,
        contextTag: ContextTag,
        estimatedMinutes: Int?,
        actualMinutes: Int?,
        endedAt: Date,
        isFlaggedLowConfidence: Bool = false,
        apiBaselineMinutes: Int? = nil
    ) {
        self.id = id
        self.categoryID = categoryID
        self.contextTag = contextTag
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.endedAt = endedAt
        self.isFlaggedLowConfidence = isFlaggedLowConfidence
        self.apiBaselineMinutes = apiBaselineMinutes
    }

    /// How this compared to the route's own prediction, rather than to the guess.
    public var baselineRatio: Double? {
        guard let baseline = apiBaselineMinutes, baseline > 0,
              let actual = actualMinutes, actual >= 0 else { return nil }
        return Double(actual) / Double(baseline)
    }

    public var key: CategoryKey {
        CategoryKey(categoryID: categoryID, contextTag: contextTag)
    }

    /// `actual / estimated`. Above 1 means underestimated, below 1 overestimated,
    /// exactly 1 spot on.
    ///
    /// A ratio rather than a raw difference, because "plus ten minutes" does not
    /// mean the same thing on a five minute task and a five hour one.
    public var biasRatio: Double? {
        guard let estimated = estimatedMinutes, estimated > 0,
              let actual = actualMinutes, actual >= 0 else { return nil }
        return Double(actual) / Double(estimated)
    }

    /// A record contributes to the multiplier only with both numbers present and
    /// no low-confidence flag.
    public var contributesToMultiplier: Bool {
        biasRatio != nil && !isFlaggedLowConfidence
    }

    /// A record with an actual duration but no guess still contributes raw duration
    /// data, just not a ratio.
    public var contributesToDuration: Bool {
        actualMinutes != nil && !isFlaggedLowConfidence
    }
}
