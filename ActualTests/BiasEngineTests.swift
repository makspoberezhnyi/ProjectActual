import Testing
import Foundation
@testable import Actual

/// The bias engine is pure arithmetic with clear expected inputs and outputs, and the
/// whole product's credibility rests on it being right, so it is tested directly
/// rather than through the views.
struct BiasEngineTests {

    // MARK: - Helpers

    /// Builds records ending one day apart, most recent first.
    private func records(
        category: String = "work",
        tag: ContextTag = .normal,
        ratios: [Double],
        estimated: Int = 60,
        flagged: Bool = false
    ) -> [SessionRecord] {
        ratios.enumerated().map { index, ratio in
            SessionRecord(
                categoryID: category,
                contextTag: tag,
                estimatedMinutes: estimated,
                actualMinutes: Int((Double(estimated) * ratio).rounded()),
                endedAt: Date(timeIntervalSince1970: 1_000_000 - Double(index) * 86_400),
                isFlaggedLowConfidence: flagged
            )
        }
    }

    private let workKey = CategoryKey(categoryID: "work", contextTag: .normal)

    // MARK: - The ratio itself

    @Test("A ratio above 1 means underestimated, below 1 overestimated")
    func biasRatioDirection() {
        let under = SessionRecord(
            categoryID: "work", contextTag: .normal,
            estimatedMinutes: 60, actualMinutes: 90, endedAt: .now
        )
        let over = SessionRecord(
            categoryID: "work", contextTag: .normal,
            estimatedMinutes: 60, actualMinutes: 30, endedAt: .now
        )
        let exact = SessionRecord(
            categoryID: "work", contextTag: .normal,
            estimatedMinutes: 60, actualMinutes: 60, endedAt: .now
        )

        #expect(under.biasRatio == 1.5)
        #expect(over.biasRatio == 0.5)
        #expect(exact.biasRatio == 1.0)
    }

    @Test("A ratio scales across task sizes where a flat difference would not")
    func ratioScalesAcrossSizes() {
        let short = SessionRecord(
            categoryID: "a", contextTag: .normal,
            estimatedMinutes: 5, actualMinutes: 10, endedAt: .now
        )
        let long = SessionRecord(
            categoryID: "b", contextTag: .normal,
            estimatedMinutes: 300, actualMinutes: 600, endedAt: .now
        )
        // Ten minutes over on a five minute task is not the same event as ten minutes
        // over on a five hour one, but doubling is doubling in both.
        #expect(short.biasRatio == long.biasRatio)
    }

    @Test("A session with no guess yields no ratio but still carries a duration")
    func missingGuessYieldsNoRatio() {
        let record = SessionRecord(
            categoryID: "work", contextTag: .normal,
            estimatedMinutes: nil, actualMinutes: 40, endedAt: .now
        )
        #expect(record.biasRatio == nil)
        #expect(record.contributesToMultiplier == false)
        #expect(record.contributesToDuration == true)
    }

    // MARK: - The threshold

    @Test("Below the minimum threshold the engine says nothing at all")
    func coldStartReturnsNothing() {
        let engine = BiasEngine()
        let history = records(ratios: [1.4, 1.5, 1.3])

        #expect(engine.output(for: workKey, from: history) == nil)
        #expect(engine.recalibratedEstimate(rawGuessMinutes: 60, for: workKey, from: history) == nil)
    }

    @Test("At the threshold the engine starts answering")
    func thresholdActivates() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 1.4, count: 5))
        let output = try #require(engine.output(for: workKey, from: history))

        #expect(output.instanceCount == 5)
        #expect(output.confidence == .low)
    }

    // MARK: - Weighting

    @Test("Constant ratios average to that ratio regardless of weighting")
    func constantRatios() throws {
        let engine = BiasEngine()
        let output = try #require(
            engine.output(for: workKey, from: records(ratios: Array(repeating: 1.5, count: 20)))
        )
        #expect(abs(output.multiplier - 1.5) < 0.0001)
    }

    @Test("Recent instances count for more than older ones")
    func recencyWeighting() throws {
        let engine = BiasEngine()
        // Ten recent sessions at 2.0, then ten older ones at 1.0. A flat mean would be
        // 1.5; recency weighting has to land above that.
        let history = records(ratios: Array(repeating: 2.0, count: 10) + Array(repeating: 1.0, count: 10))
        let output = try #require(engine.output(for: workKey, from: history))

        #expect(output.multiplier > 1.5)
        #expect(output.multiplier < 2.0)
    }

    @Test("Order of the input array does not matter, only when sessions ended")
    func orderIndependence() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 2.0, count: 10) + Array(repeating: 1.0, count: 10))
        let forwards = try #require(engine.output(for: workKey, from: history))
        let shuffled = try #require(engine.output(for: workKey, from: history.shuffled()))

        #expect(abs(forwards.multiplier - shuffled.multiplier) < 0.0001)
    }

    // MARK: - Isolation between contexts

    @Test("A context tag builds its own dataset rather than blending into the category")
    func contextsStaySeparate() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 1.2, count: 20))
            + records(tag: .highPressure, ratios: Array(repeating: 2.0, count: 20))

        let normal = try #require(engine.output(for: workKey, from: history))
        let pressured = try #require(
            engine.output(
                for: CategoryKey(categoryID: "work", contextTag: .highPressure),
                from: history
            )
        )

        #expect(abs(normal.multiplier - 1.2) < 0.001)
        #expect(abs(pressured.multiplier - 2.0) < 0.001)
        #expect(normal.scope == .exact)
        #expect(pressured.scope == .exact)
    }

    @Test("A category never blends with a different category")
    func categoriesStaySeparate() throws {
        let engine = BiasEngine()
        let history = records(category: "work", ratios: Array(repeating: 1.2, count: 20))
            + records(category: "email", ratios: Array(repeating: 2.5, count: 20))

        let output = try #require(engine.output(for: workKey, from: history))
        #expect(abs(output.multiplier - 1.2) < 0.001)
    }

    // MARK: - Fallback

    @Test("A brand new context falls back to the parent category, clearly marked")
    func fallsBackToCategory() throws {
        let engine = BiasEngine()
        // Plenty of history on the category, none at all on this particular tag.
        let history = records(tag: .normal, ratios: Array(repeating: 1.6, count: 20))
        let newTagKey = CategoryKey(categoryID: "work", contextTag: ContextTag("kids are home"))

        let output = try #require(engine.output(for: newTagKey, from: history))
        #expect(output.scope == .categoryFallback)
        #expect(abs(output.multiplier - 1.6) < 0.001)
    }

    @Test("The exact pair wins over the fallback once it has enough of its own history")
    func exactBeatsFallback() throws {
        let engine = BiasEngine()
        let history = records(tag: .normal, ratios: Array(repeating: 1.2, count: 30))
            + records(tag: .distracted, ratios: Array(repeating: 2.2, count: 6))

        let output = try #require(
            engine.output(
                for: CategoryKey(categoryID: "work", contextTag: .distracted),
                from: history
            )
        )
        #expect(output.scope == .exact)
        #expect(abs(output.multiplier - 2.2) < 0.001)
    }

    @Test("With neither the pair nor the category above threshold, nothing is returned")
    func noFallbackWithoutEnoughAnywhere() {
        let engine = BiasEngine()
        let history = records(tag: .normal, ratios: [1.5, 1.5])
        let key = CategoryKey(categoryID: "work", contextTag: .lowEnergy)

        #expect(engine.output(for: key, from: history) == nil)
    }

    // MARK: - Flagged sessions

    @Test("Flagged sessions are excluded from the multiplier")
    func flaggedExcluded() throws {
        let engine = BiasEngine()
        let clean = records(ratios: Array(repeating: 1.5, count: 20))
        // A trip that never resolved an arrival and auto-closed at its ceiling.
        let junk = records(ratios: Array(repeating: 20.0, count: 5), flagged: true)

        let output = try #require(engine.output(for: workKey, from: clean + junk))
        #expect(abs(output.multiplier - 1.5) < 0.001)
        #expect(output.instanceCount == 20)
    }

    // MARK: - Confidence

    @Test(
        "Confidence tiers follow instance count",
        arguments: [(5, ConfidenceLevel.low), (14, .low), (15, .medium), (39, .medium), (40, .high), (80, .high)]
    )
    func confidenceTiers(count: Int, expected: ConfidenceLevel) throws {
        let engine = BiasEngine()
        let output = try #require(
            engine.output(for: workKey, from: records(ratios: Array(repeating: 1.3, count: count)))
        )
        #expect(output.confidence == expected)
        #expect(output.instanceCount == count)
    }

    // MARK: - Applying the multiplier

    @Test("A raw guess is scaled by the person's own multiplier")
    func adjustsRawGuess() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 1.3333, count: 32), estimated: 120)

        let estimate = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: 120, for: workKey, from: history)
        )
        // Two hours guessed, and their own history says two forty.
        #expect(estimate.minutes == 160)
        #expect(estimate.rawGuessMinutes == 120)
        if case .adjustedGuess = estimate.basis {} else {
            Issue.record("Expected an adjusted guess basis")
        }
    }

    @Test("With no guess at all the number comes from recent actual durations")
    func prefillsBlindFromHistory() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 1.5, count: 20), estimated: 60)

        let estimate = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: nil, for: workKey, from: history)
        )
        // Every session ran 90 minutes, so that is what the blind pre-fill offers.
        #expect(estimate.minutes == 90)
        #expect(estimate.basis == .historyAverage)
    }

    @Test("The estimate never rounds down to zero")
    func neverZero() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 0.02, count: 20), estimated: 10)

        let estimate = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: 5, for: workKey, from: history)
        )
        #expect(estimate.minutes >= 1)
    }

    @Test("Accepting the app's number does not get it corrected a second time")
    func acceptedEstimateIsNotRecorrected() throws {
        let engine = BiasEngine()
        // Guesses of two hours that consistently run to two forty.
        let history = records(ratios: Array(repeating: 1.3333, count: 32), estimated: 120)

        let corrected = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: 120, for: workKey, from: history)
        )
        #expect(corrected.minutes == 160)

        // What a running session should show is how long this usually takes, which comes
        // from history alone. Feeding the accepted 160 back through the multiplier would
        // give 213, an expectation nothing in the history supports.
        let expectation = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: nil, for: workKey, from: history)
        )
        #expect(expectation.minutes == 160)
        #expect(expectation.basis == .historyAverage)
    }

    // MARK: - Trend

    @Test("A shift in the latest session moves the estimate off its previous value")
    func trendReflectsLatestSession() throws {
        let engine = BiasEngine()
        var history = records(ratios: Array(repeating: 1.3, count: 30), estimated: 120)
        // One much longer session, ending most recently of all.
        history.insert(
            SessionRecord(
                categoryID: "work", contextTag: .normal,
                estimatedMinutes: 120, actualMinutes: 300,
                endedAt: Date(timeIntervalSince1970: 2_000_000)
            ),
            at: 0
        )

        let estimate = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: 120, for: workKey, from: history)
        )
        let delta = try #require(estimate.trendMinutes)
        #expect(delta > 0)
    }

    @Test("The longer-run comparison reads a window back, not just the last session")
    func trailingComparisonIsAWindowBack() throws {
        let engine = BiasEngine()
        // The last ten sessions ran much longer than the twenty before them, so the
        // estimate now must sit above where it stood a window ago.
        let history = records(
            ratios: Array(repeating: 1.8, count: 10) + Array(repeating: 1.1, count: 20),
            estimated: 120
        )

        let estimate = try #require(
            engine.recalibratedEstimate(rawGuessMinutes: 120, for: workKey, from: history)
        )
        let prior = try #require(estimate.priorMinutes)
        #expect(estimate.minutes > prior)
        #expect(try #require(estimate.priorTrendMinutes) > 0)
    }

    @Test("Without enough history behind it, no longer-run comparison is offered")
    func noTrailingComparisonOnThinData() throws {
        let engine = BiasEngine()
        let estimate = try #require(
            engine.recalibratedEstimate(
                rawGuessMinutes: 60,
                for: workKey,
                from: records(ratios: Array(repeating: 1.3, count: 8))
            )
        )
        #expect(estimate.priorMinutes == nil)
    }

    // MARK: - Drift

    @Test("A steady pattern raises no drift flag")
    func noDriftWhenSteady() throws {
        let engine = BiasEngine()
        let output = try #require(
            engine.output(for: workKey, from: records(ratios: Array(repeating: 1.3, count: 30)))
        )
        #expect(output.driftFlag == false)
    }

    @Test("A real shift between the last window and the one before it is flagged")
    func driftDetected() throws {
        let engine = BiasEngine()
        let history = records(
            ratios: Array(repeating: 1.6, count: 10) + Array(repeating: 1.1, count: 12)
        )
        let output = try #require(engine.output(for: workKey, from: history))
        #expect(output.driftFlag == true)
    }

    @Test("A shift below the threshold is treated as noise, not a pattern change")
    func smallShiftIsNoise() throws {
        let engine = BiasEngine()
        let history = records(
            ratios: Array(repeating: 1.15, count: 10) + Array(repeating: 1.10, count: 12)
        )
        let output = try #require(engine.output(for: workKey, from: history))
        #expect(output.driftFlag == false)
    }

    // MARK: - Against the routing service

    @Test("Running consistently later than the route is measured separately from the guess")
    func baselineMultiplier() throws {
        let engine = BiasEngine()
        // The route says twenty minutes every time; this person takes twenty five. That
        // is a personal signal, and it is not the same as their guess being wrong.
        let history = (0..<20).map { index in
            SessionRecord(
                categoryID: "commute", contextTag: .normal,
                estimatedMinutes: 25, actualMinutes: 25,
                endedAt: Date(timeIntervalSince1970: 1_000_000 - Double(index) * 86_400),
                apiBaselineMinutes: 20
            )
        }

        let key = CategoryKey(categoryID: "commute", contextTag: .normal)
        let against = try #require(engine.baselineMultiplier(for: key, from: history))
        #expect(abs(against - 1.25) < 0.001)

        // Their own guess was spot on the whole time, which is a different fact.
        let output = try #require(engine.output(for: key, from: history))
        #expect(abs(output.multiplier - 1.0) < 0.001)
    }

    @Test("Trips without a baseline simply do not contribute one")
    func baselineAbsent() {
        let engine = BiasEngine()
        let history = records(category: "commute", ratios: Array(repeating: 1.3, count: 20))
        #expect(
            engine.baselineMultiplier(
                for: CategoryKey(categoryID: "commute", contextTag: .normal), from: history
            ) == nil
        )
    }

    // MARK: - History series

    @Test("Below the threshold there is no history series at all")
    func historyEmptyBelowThreshold() {
        let engine = BiasEngine()
        let series = engine.multiplierHistory(
            for: workKey, from: records(ratios: [1.5, 1.5, 1.5])
        )
        #expect(series.isEmpty)
    }

    @Test("The series has one point per instance once at the threshold")
    func historyGrowsWithInstances() {
        let engine = BiasEngine()
        let series = engine.multiplierHistory(
            for: workKey, from: records(ratios: Array(repeating: 1.3, count: 10))
        )
        // Five is the minimum threshold, ten instances total: points 5 through 10.
        #expect(series.count == 6)
        #expect(series.map(\.instanceCount) == [5, 6, 7, 8, 9, 10])
    }

    @Test("The series is ordered oldest to newest, the order a chart reads")
    func historyIsChronological() {
        let engine = BiasEngine()
        let series = engine.multiplierHistory(
            for: workKey, from: records(ratios: Array(repeating: 1.3, count: 8))
        )
        let dates = series.map(\.date)
        #expect(dates == dates.sorted())
    }

    @Test("A real shift shows up as a real move in the series, not a flat line")
    func historyReflectsDrift() throws {
        let engine = BiasEngine()
        // Ten steady instances, then ten much longer ones, most recent last in the
        // input (this helper builds most-recent-first).
        let history = records(ratios: Array(repeating: 1.8, count: 10) + Array(repeating: 1.1, count: 10))
        let series = engine.multiplierHistory(for: workKey, from: history)

        let first = try #require(series.first)
        let last = try #require(series.last)
        // The series starts near the old steady value and ends near the new one.
        #expect(abs(first.multiplier - 1.1) < 0.05)
        #expect(last.multiplier > first.multiplier)
    }

    @Test("The last point in the series matches the engine's own current output")
    func historyEndsAtCurrentOutput() throws {
        let engine = BiasEngine()
        let history = records(ratios: Array(repeating: 1.4, count: 12))
        let series = engine.multiplierHistory(for: workKey, from: history)
        let output = try #require(engine.output(for: workKey, from: history))

        let last = try #require(series.last)
        #expect(abs(last.multiplier - output.multiplier) < 0.0001)
        #expect(last.instanceCount == output.instanceCount)
    }

    // MARK: - Ranking and the headline

    @Test("The ranking sorts by distance from a perfect guess, largest first")
    func rankingOrder() {
        let engine = BiasEngine()
        let history = records(category: "email", ratios: Array(repeating: 1.78, count: 51))
            + records(category: "commute", ratios: Array(repeating: 1.34, count: 24))
            + records(category: "reading", ratios: Array(repeating: 0.95, count: 14))

        let ranked = engine.ranking(from: history)
        #expect(ranked.map(\.key.categoryID) == ["email", "commute", "reading"])
    }

    @Test("Overestimating ranks by the same distance as underestimating")
    func rankingIsDirectionless() {
        let engine = BiasEngine()
        // Half as long as guessed and twice as long as guessed are both real gaps, but
        // 0.5 is further from 1 than 1.4 is, so it must rank first.
        let history = records(category: "over", ratios: Array(repeating: 0.5, count: 20))
            + records(category: "under", ratios: Array(repeating: 1.4, count: 20))

        #expect(engine.ranking(from: history).first?.key.categoryID == "over")
    }

    @Test("Categories below the threshold stay out of the ranking entirely")
    func rankingExcludesThinData() {
        let engine = BiasEngine()
        let history = records(category: "email", ratios: Array(repeating: 1.78, count: 51))
            + records(category: "barely", ratios: [3.0, 3.0])

        let ranked = engine.ranking(from: history)
        #expect(ranked.count == 1)
        #expect(ranked.first?.key.categoryID == "email")
    }

    @Test("The headline figure is weighted by instance count")
    func aggregateIsWeighted() throws {
        let engine = BiasEngine()
        // Forty sessions off by 50%, ten off by 10%. An unweighted mean would give 30%;
        // weighting by how much history each rests on gives 42%.
        let history = records(category: "big", ratios: Array(repeating: 1.5, count: 40))
            + records(category: "small", ratios: Array(repeating: 1.1, count: 10))

        let aggregate = try #require(engine.aggregateDeviation(from: history))
        #expect(abs(aggregate - 0.42) < 0.01)
    }

    @Test("With nothing above the threshold the headline is absent rather than zero")
    func aggregateAbsentOnColdStart() {
        let engine = BiasEngine()
        #expect(engine.aggregateDeviation(from: records(ratios: [1.5, 1.5])) == nil)
    }
}
