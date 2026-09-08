import Foundation

/// Matches a spoken category reference against the person's own categories.
///
/// Deliberately language agnostic. Category names come from whatever the person typed
/// or said when creating them, so a category named in Ukrainian matches a Ukrainian
/// phrase the same way an English one matches English. Nothing here translates.
public struct CategoryMatcher: Sendable {

    public struct Candidate: Equatable, Sendable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public enum Match: Equatable, Sendable {
        case one(Candidate)
        /// Two or more read as equally likely. The caller must ask, not pick.
        case several([Candidate])
        case none
    }

    /// How much of what was said a name must explain before it counts as a match.
    public var threshold: Double
    /// How close a runner-up has to be before the result is treated as ambiguous.
    public var ambiguityMargin: Double

    public init(threshold: Double = 0.5, ambiguityMargin: Double = 0.08) {
        self.threshold = threshold
        self.ambiguityMargin = ambiguityMargin
    }

    public func match(_ spoken: String, against candidates: [Candidate]) -> Match {
        let spokenTokens = Set(VoiceText.tokenize(spoken))
        guard !spokenTokens.isEmpty, !candidates.isEmpty else { return .none }

        let scored = candidates
            .map { (candidate: $0, score: score(spokenTokens: spokenTokens, name: $0.name)) }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }

        guard let best = scored.first else { return .none }

        // An exact reading beats everything; it is not ambiguous just because another
        // name happens to contain the same words.
        if best.score >= 1.0 {
            let exact = scored.filter { $0.score >= 1.0 }
            return exact.count == 1 ? .one(best.candidate) : .several(exact.map(\.candidate))
        }

        let contenders = scored.filter { best.score - $0.score <= ambiguityMargin }
        if contenders.count > 1 {
            return .several(contenders.map(\.candidate))
        }
        return .one(best.candidate)
    }

    /// The share of what was said that this name accounts for.
    ///
    /// Measuring against the spoken words rather than the name's words is what lets
    /// "work" find "Work session" without a longer name being punished for its length.
    private func score(spokenTokens: Set<String>, name: String) -> Double {
        let nameTokens = Set(VoiceText.tokenize(name))
        guard !nameTokens.isEmpty else { return 0 }

        if spokenTokens == nameTokens { return 1.0 }

        let shared = spokenTokens.intersection(nameTokens).count
        if shared == spokenTokens.count { return 0.95 }
        guard shared > 0 else { return prefixScore(spokenTokens: spokenTokens, nameTokens: nameTokens) }

        return Double(shared) / Double(spokenTokens.count) * 0.9
    }

    /// Catches a word spoken as a stem of the name's word, which happens constantly in
    /// inflected languages: "робоч" against "робоча сесія".
    private func prefixScore(spokenTokens: Set<String>, nameTokens: Set<String>) -> Double {
        var matched = 0
        for spoken in spokenTokens where spoken.count >= 3 {
            if nameTokens.contains(where: { $0.hasPrefix(spoken) || spoken.hasPrefix($0) }) {
                matched += 1
            }
        }
        guard matched > 0 else { return 0 }
        return Double(matched) / Double(spokenTokens.count) * 0.8
    }
}
