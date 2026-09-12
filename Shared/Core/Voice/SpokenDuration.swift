import Foundation

/// Turns the duration part of a spoken phrase into whole minutes.
///
/// Everything downstream — capture, the widget, the watch — writes into one identical
/// schema, so voice has to produce the same integer minutes a tapped preset would.
public enum SpokenDuration {

    public struct Result: Equatable, Sendable {
        public let minutes: Int?
        /// Indices of the tokens the duration used up, so the caller can lift them out
        /// before reading what remains as the category.
        public let consumedIndices: Set<Int>
    }

    /// Scans tokens left to right, accumulating a running total as units are met.
    ///
    /// Handles "three hours", "twenty five minutes", "90m", "half an hour", "an hour and
    /// a half", "quarter of an hour", "полтора часа", "півгодини".
    public static func scan(tokens: [String], lexicon: VoiceLexicon) -> Result {
        var total = 0
        var sawUnit = false

        var pending: Int?
        var pendingIsOneAndAHalf = false
        var halfPending = false
        var quarterPending = false
        var lastUnitMinutes: Int?
        var consumed: Set<Int> = []

        func flushUnit(_ unitMinutes: Int, at index: Int) {
            var value = pending ?? 1
            if quarterPending {
                total += unitMinutes / 4
                quarterPending = false
            } else if halfPending {
                total += unitMinutes / 2
                halfPending = false
            } else {
                total += value * unitMinutes
                if pendingIsOneAndAHalf { total += unitMinutes / 2 }
            }
            value = 0
            pending = nil
            pendingIsOneAndAHalf = false
            lastUnitMinutes = unitMinutes
            sawUnit = true
            consumed.insert(index)
        }

        for (index, token) in tokens.enumerated() {
            // "90m", "2h", "30min" arrive as one token.
            if let glued = gluedNumberAndUnit(token, lexicon: lexicon) {
                total += glued
                sawUnit = true
                consumed.insert(index)
                continue
            }

            if lexicon.halfHourWords.contains(token) {
                total += 30
                sawUnit = true
                consumed.insert(index)
                continue
            }

            if lexicon.oneAndAHalfWords.contains(token) {
                pending = 1
                pendingIsOneAndAHalf = true
                consumed.insert(index)
                continue
            }

            if let digits = Int(token), digits >= 0 {
                pending = digits
                consumed.insert(index)
                continue
            }

            if let value = lexicon.numbers[token] {
                // "twenty five" composes; "five twenty" does not, and neither does a
                // fresh number after a completed unit.
                if let current = pending, current >= 20, value < 10 {
                    pending = current + value
                } else {
                    pending = value
                }
                consumed.insert(index)
                continue
            }

            if lexicon.halfWords.contains(token) {
                // "an hour and a half": the unit already landed, so this is a bonus on it.
                if let unit = lastUnitMinutes, sawUnit {
                    total += unit / 2
                    pending = nil
                    consumed.insert(index)
                } else {
                    // "half an hour": wait for the unit to know half of what.
                    halfPending = true
                    pending = nil
                    consumed.insert(index)
                }
                continue
            }

            if lexicon.quarterWords.contains(token) {
                quarterPending = true
                pending = nil
                consumed.insert(index)
                continue
            }

            if lexicon.hourUnits.contains(token) {
                flushUnit(60, at: index)
                continue
            }

            if lexicon.minuteUnits.contains(token) {
                flushUnit(1, at: index)
                continue
            }

            if lexicon.conjunctions.contains(token), sawUnit {
                // Only a joiner inside a duration, as in "and a half". Left unconsumed
                // otherwise so it stays available to the category text.
                consumed.insert(index)
                continue
            }

            // Anything else ends the numeric run. A number left dangling belongs to the
            // category, not the duration, unless a unit turns up later.
            if pending != nil, !sawUnit {
                pending = nil
                consumed = consumed.filter { $0 > index }
            }
        }

        // A bare trailing number with no unit anywhere, as in "guessing 90", is minutes.
        if !sawUnit, let bare = pending {
            return Result(minutes: bare > 0 ? bare : nil, consumedIndices: consumed)
        }

        guard sawUnit, total > 0 else {
            return Result(minutes: nil, consumedIndices: [])
        }
        return Result(minutes: total, consumedIndices: consumed)
    }

    /// "90m" / "2h" / "45min" written as a single token.
    private static func gluedNumberAndUnit(_ token: String, lexicon: VoiceLexicon) -> Int? {
        let digits = token.prefix { $0.isNumber }
        guard !digits.isEmpty, let value = Int(digits) else { return nil }

        let suffix = String(token.dropFirst(digits.count))
        guard !suffix.isEmpty else { return nil }

        if lexicon.hourUnits.contains(suffix) { return value * 60 }
        if lexicon.minuteUnits.contains(suffix) { return value }
        return nil
    }
}
