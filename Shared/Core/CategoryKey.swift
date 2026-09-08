import Foundation

/// Every calculation in the bias engine is keyed by category *and* context together,
/// never by category alone, so a normal work session and a high pressure one build
/// entirely separate datasets.
public struct CategoryKey: Hashable, Codable, Sendable {
    public let categoryID: String
    public let contextTag: ContextTag

    public init(categoryID: String, contextTag: ContextTag) {
        self.categoryID = categoryID
        self.contextTag = contextTag
    }
}

/// Whether a number came from the exact category + context pair asked for, or from
/// the broader parent category because the specific pair does not have enough
/// history yet. The display layer must label these differently.
public enum EstimateScope: Hashable, Sendable {
    /// Built from this exact category and context tag.
    case exact
    /// Built from the parent category across all its context tags.
    case categoryFallback
}
