import Foundation

/// The core of the product, and deliberately plain statistics rather than a model.
///
/// If a person asks why the app expects forty minutes instead of twenty, the honest
/// answer has to be that their last twelve similar sessions averaged forty. A black
/// box under a product whose whole pitch is telling people the truth about their own
/// numbers would quietly undercut the pitch. So: a weighted ratio with recency decay,
/// instant, free, and fully explainable.
///
/// No SwiftUI, SwiftData or CloudKit imports belong in this file.
public struct BiasEngine: Sendable {

    public struct Configuration: Sendable {
        /// Below this many instances, nothing is shown. No number implying data that
        /// does not exist yet.
        public var minimumInstances: Int
        /// Recency decay expressed as a half-life in instances: an instance this far
        /// back counts half as much as the most recent one. Keeping it around a dozen
        /// puts the weight on the most recent 10 to 15 sessions.
        public var halfLifeInInstances: Double
        /// Upper bound of the low confidence band.
        public var lowConfidenceUpperBound: Int
        /// Upper bound of the medium confidence band.
        public var mediumConfidenceUpperBound: Int
        /// How many instances each side of the drift comparison uses.
        public var driftWindow: Int
        /// Relative shift between the two windows that counts as a real pattern change
        /// rather than noise.
        public var driftThreshold: Double

        public init(
            minimumInstances: Int = 5,
            halfLifeInInstances: Double = 12,
            lowConfidenceUpperBound: Int = 15,
            mediumConfidenceUpperBound: Int = 40,
            driftWindow: Int = 10,
            driftThreshold: Double = 0.20
        ) {
            self.minimumInstances = minimumInstances
            self.halfLifeInInstances = halfLifeInInstances
            self.lowConfidenceUpperBound = lowConfidenceUpperBound
            self.mediumConfidenceUpperBound = mediumConfidenceUpperBound
            self.driftWindow = driftWindow
            self.driftThreshold = driftThreshold
        }

        public static let standard = Configuration()
    }

    public let configuration: Configuration

    public init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    // MARK: - Output for one key

    /// The engine's answer for a category and context pair, or `nil` when neither the
    /// exact pair nor its parent category has enough history to say anything yet.
    ///
    /// Falls back to the parent category rather than showing nothing, so a brand new
    /// context tag is not left sitting through a cold start with zero guidance. The
    /// caller can tell the two apart through `scope`.
    public func output(for key: CategoryKey, from records: [SessionRecord]) -> BiasEngineOutput? {
        let exact = usableRecords(records.filter { $0.key == key })
        if exact.count >= configuration.minimumInstances {
            return makeOutput(key: key, records: exact, scope: .exact)
        }

        let parent = usableRecords(records.filter { $0.categoryID == key.categoryID })
        if parent.count >= configuration.minimumInstances {
            return makeOutput(key: key, records: parent, scope: .categoryFallback)
        }

        return nil
    }

    /// Every key the person has enough history on, ranked by how far its multiplier
    /// sits from 1, largest deviation first. This is the "where you're most wrong"
    /// list, sorted plainly rather than alphabetically or by frequency.
    public func ranking(from records: [SessionRecord]) -> [BiasEngineOutput] {
        let grouped = Dictionary(grouping: usableRecords(records), by: \.key)
        return grouped.compactMap { key, group -> BiasEngineOutput? in
            guard group.count >= configuration.minimumInstances else { return nil }
            return makeOutput(key: key, records: group, scope: .exact)
        }
        .sorted {
            if $0.absoluteDeviation != $1.absoluteDeviation {
                return $0.absoluteDeviation > $1.absoluteDeviation
            }
            return $0.instanceCount > $1.instanceCount
        }
    }

    /// One honest headline figure: the average absolute deviation from 1 across every
    /// category with enough data, weighted by instance count so categories carrying
    /// more history count for more.
    ///
    /// Returns `nil` rather than a fabricated zero when nothing qualifies yet.
    public func aggregateDeviation(from records: [SessionRecord]) -> Double? {
        let outputs = ranking(from: records)
        guard !outputs.isEmpty else { return nil }

        let totalWeight = outputs.reduce(0.0) { $0 + Double($1.instanceCount) }
        guard totalWeight > 0 else { return nil }

        let weighted = outputs.reduce(0.0) {
            $0 + $1.absoluteDeviation * Double($1.instanceCount)
        }
        return weighted / totalWeight
    }

    /// How this person compares to the routing service's own prediction.
    ///
    /// A distinct question from the bias multiplier. The route already accounts for
    /// traffic; this measures whether someone consistently arrives later than it says —
    /// parking, walking from the car, leaving a few minutes after they meant to. That is
    /// a personal signal the routing service has no reason to model.
    ///
    /// Returns nil when too few trips carry a baseline, which is common: the call is
    /// allowed to fail and the trip still gets logged.
    public func baselineMultiplier(
        for key: CategoryKey,
        from records: [SessionRecord]
    ) -> Double? {
        let ratios = records
            .filter { $0.key == key && !$0.isFlaggedLowConfidence }
            .sorted { $0.endedAt > $1.endedAt }
            .compactMap(\.baselineRatio)

        guard ratios.count >= configuration.minimumInstances else { return nil }
        return weightedAverage(ratios)
    }

    // MARK: - Applying the multiplier

    /// The number to show alongside a raw guess, or in place of one when the person
    /// has not guessed yet.
    ///
    /// Both paths are needed: sometimes a person types a guess and the app adjusts it,
    /// sometimes the app suggests a number before they have guessed anything at all.
    public func recalibratedEstimate(
        rawGuessMinutes: Int?,
        for key: CategoryKey,
        from records: [SessionRecord]
    ) -> RecalibratedEstimate? {
        guard let output = output(for: key, from: records) else { return nil }

        if let raw = rawGuessMinutes, raw > 0 {
            return RecalibratedEstimate(
                minutes: minutes(raw, times: output.multiplier),
                previousMinutes: output.previousMultiplier.map { minutes(raw, times: $0) },
                priorMinutes: output.trailingMultiplier.map { minutes(raw, times: $0) },
                basis: .adjustedGuess(rawMinutes: raw),
                output: output
            )
        }

        return RecalibratedEstimate(
            minutes: max(1, Int(output.averageActualMinutes.rounded())),
            previousMinutes: nil,
            priorMinutes: nil,
            basis: .historyAverage,
            output: output
        )
    }

    /// The full multiplier history for a category and context pair, one point per
    /// instance, oldest first.
    ///
    /// Each point is what the multiplier stood at *as of that instance*, computed the
    /// same recency-weighted way as `output(for:from:)` — so plotting this line is
    /// plotting the actual number the person would have seen at each point in time, not
    /// a smoothed reconstruction.
    public struct HistoryPoint: Equatable, Sendable {
        public let date: Date
        public let multiplier: Double
        public let instanceCount: Int
    }

    public func multiplierHistory(for key: CategoryKey, from records: [SessionRecord]) -> [HistoryPoint] {
        let usable = usableRecords(records.filter { $0.key == key })
        guard usable.count >= configuration.minimumInstances else { return [] }

        // usableRecords sorts most-recent-first; walking it in reverse gives oldest
        // first, which is the order a chart reads left to right.
        let chronological = Array(usable.reversed())

        var points: [HistoryPoint] = []
        for count in configuration.minimumInstances...chronological.count {
            // The window ending at `count` instances in, read most-recent-first so the
            // same decay weighting applies as everywhere else.
            let window = Array(chronological.prefix(count).reversed())
            let ratios = window.compactMap(\.biasRatio)
            points.append(
                HistoryPoint(
                    date: chronological[count - 1].endedAt,
                    multiplier: weightedAverage(ratios),
                    instanceCount: count
                )
            )
        }
        return points
    }

    // MARK: - Internals

    /// Filters to instances the multiplier is allowed to see, ordered most recent first.
    private func usableRecords(_ records: [SessionRecord]) -> [SessionRecord] {
        records
            .filter(\.contributesToMultiplier)
            .sorted { $0.endedAt > $1.endedAt }
    }

    /// `records` must already be filtered and ordered most recent first.
    private func makeOutput(
        key: CategoryKey,
        records: [SessionRecord],
        scope: EstimateScope
    ) -> BiasEngineOutput {
        let ratios = records.compactMap(\.biasRatio)
        let actuals = records.compactMap(\.actualMinutes).map(Double.init)

        let multiplier = weightedAverage(ratios)
        // The same figure with the most recent instance withheld, which is what makes
        // "up 2m since last session" a real comparison rather than a decoration.
        let previous = ratios.count > configuration.minimumInstances
            ? weightedAverage(Array(ratios.dropFirst()))
            : nil

        // And as it stood a whole window back, which is what makes a "was 2h 25m"
        // comparison a real read on direction rather than a restatement of the last
        // session. Only offered where enough history remains after dropping that window.
        let trailing = ratios.count >= configuration.driftWindow + configuration.minimumInstances
            ? weightedAverage(Array(ratios.dropFirst(configuration.driftWindow)))
            : nil

        return BiasEngineOutput(
            key: key,
            multiplier: multiplier,
            averageActualMinutes: weightedAverage(actuals),
            instanceCount: records.count,
            confidence: confidence(forInstanceCount: records.count),
            driftFlag: hasDrifted(ratios),
            scope: scope,
            previousMultiplier: previous,
            trailingMultiplier: trailing
        )
    }

    /// Exponential recency decay. `values` ordered most recent first, so index 0 gets
    /// full weight and each half-life back halves it.
    private func weightedAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 1 }
        guard configuration.halfLifeInInstances > 0 else {
            return values.reduce(0, +) / Double(values.count)
        }

        var numerator = 0.0
        var denominator = 0.0
        for (index, value) in values.enumerated() {
            let weight = pow(0.5, Double(index) / configuration.halfLifeInInstances)
            numerator += weight * value
            denominator += weight
        }
        return denominator > 0 ? numerator / denominator : 1
    }

    private func confidence(forInstanceCount count: Int) -> ConfidenceLevel {
        if count < configuration.minimumInstances { return .none }
        if count < configuration.lowConfidenceUpperBound { return .low }
        if count < configuration.mediumConfidenceUpperBound { return .medium }
        return .high
    }

    /// Compares the most recent window against the window before it. A shift past the
    /// threshold is a life pattern change worth surfacing, not noise to absorb.
    private func hasDrifted(_ ratios: [Double]) -> Bool {
        let window = configuration.driftWindow
        guard ratios.count >= window * 2 else { return false }

        let recent = Array(ratios.prefix(window))
        let prior = Array(ratios.dropFirst(window).prefix(window))

        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let priorMean = prior.reduce(0, +) / Double(prior.count)
        guard priorMean > 0 else { return false }

        return abs(recentMean - priorMean) / priorMean > configuration.driftThreshold
    }

    private func minutes(_ raw: Int, times multiplier: Double) -> Int {
        max(1, Int((Double(raw) * multiplier).rounded()))
    }
}
