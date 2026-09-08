import Foundation

/// A number ready to show next to the person's own guess, carrying everything the
/// display layer needs to render it honestly.
public struct RecalibratedEstimate: Hashable, Sendable {
    /// How the number was arrived at.
    public enum Basis: Hashable, Sendable {
        /// The person typed a guess and the engine adjusted it by their multiplier.
        case adjustedGuess(rawMinutes: Int)
        /// No guess yet, so the number is the recent average actual duration directly.
        case historyAverage
    }

    public let minutes: Int
    /// The same estimate as of one instance ago, when history allows it.
    public let previousMinutes: Int?
    /// The same estimate as it stood a window of sessions back.
    public let priorMinutes: Int?
    public let basis: Basis
    public let output: BiasEngineOutput

    public init(
        minutes: Int,
        previousMinutes: Int?,
        priorMinutes: Int?,
        basis: Basis,
        output: BiasEngineOutput
    ) {
        self.minutes = minutes
        self.previousMinutes = previousMinutes
        self.priorMinutes = priorMinutes
        self.basis = basis
        self.output = output
    }

    public var confidence: ConfidenceLevel { output.confidence }
    public var instanceCount: Int { output.instanceCount }
    public var scope: EstimateScope { output.scope }

    /// Signed change against the previous estimate, in minutes. `nil` when there is
    /// no previous value to compare against.
    public var trendMinutes: Int? {
        guard let previous = previousMinutes else { return nil }
        return minutes - previous
    }

    /// Signed change against where this stood a window of sessions ago.
    public var priorTrendMinutes: Int? {
        guard let prior = priorMinutes else { return nil }
        return minutes - prior
    }

    public var rawGuessMinutes: Int? {
        if case .adjustedGuess(let raw) = basis { return raw }
        return nil
    }
}
