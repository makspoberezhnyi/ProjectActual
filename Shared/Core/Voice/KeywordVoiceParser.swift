import Foundation

/// The deterministic parser: fixed keywords, no model, no network, no OS version floor.
///
/// This is the layer that guarantees the basic commands work at all. Where the on-device
/// model supports a language well it handles freer phrasing; where it does not, or is
/// unavailable, this still understands "start a work session, guessing two hours".
///
/// Pure Swift by design, so the whole language surface is testable with string literals.
public struct KeywordVoiceParser: Sendable {

    public init() {}

    /// Reads a phrase, picking the language by which lexicon explains it best.
    ///
    /// Detection is by evidence rather than by asking the person to declare a language
    /// mid-sentence: whichever lexicon recognises the most of what was said wins.
    public func parse(_ phrase: String, preferring languages: [VoiceLanguage] = VoiceLanguage.allCases) -> VoiceCommand? {
        let tokens = VoiceText.tokenize(phrase)
        guard !tokens.isEmpty else { return nil }

        let candidates = languages.map { VoiceLexicon.lexicon(for: $0) }
        let scored = candidates
            .map { (lexicon: $0, command: parse(tokens: tokens, lexicon: $0)) }
            .filter { $0.command != nil }

        guard !scored.isEmpty else { return nil }

        // Prefer the reading that recognised the most, and on a tie the earlier language
        // in the caller's preference order, which is the one used most recently.
        let best = scored.max { left, right in
            recognitionScore(tokens: tokens, lexicon: left.lexicon)
                < recognitionScore(tokens: tokens, lexicon: right.lexicon)
        }
        return best?.command ?? nil
    }

    /// Parses against one specific language.
    public func parse(_ phrase: String, language: VoiceLanguage) -> VoiceCommand? {
        parse(tokens: VoiceText.tokenize(phrase), lexicon: .lexicon(for: language))
    }

    /// Reads just the duration, without needing the phrase to be a recognised command.
    ///
    /// Separate from `parse` on purpose: loose phrasing is exactly where no fixed intent
    /// verb appears, and that is also exactly where a second opinion on the number is
    /// worth most. Arithmetic does not need the sentence to be well formed.
    public func scanDuration(
        _ phrase: String,
        preferring languages: [VoiceLanguage] = VoiceLanguage.allCases
    ) -> Int? {
        let tokens = VoiceText.tokenize(phrase)
        guard !tokens.isEmpty else { return nil }

        let lexicons = languages.map { VoiceLexicon.lexicon(for: $0) }
        let best = lexicons.max {
            recognitionScore(tokens: tokens, lexicon: $0) < recognitionScore(tokens: tokens, lexicon: $1)
        }
        guard let lexicon = best else { return nil }

        // A guess marker, where there is one, says where the number starts.
        let start = tokens.firstIndex { lexicon.guessMarkers.contains($0) }.map { $0 + 1 } ?? 0
        guard start < tokens.count else { return nil }

        return SpokenDuration.scan(tokens: Array(tokens[start...]), lexicon: lexicon).minutes
    }

    // MARK: - Internals

    private func parse(tokens: [String], lexicon: VoiceLexicon) -> VoiceCommand? {
        guard let intentIndex = tokens.firstIndex(where: {
            lexicon.startVerbs.contains($0) || lexicon.endVerbs.contains($0)
        }) else { return nil }

        let intent: VoiceIntent = lexicon.startVerbs.contains(tokens[intentIndex]) ? .start : .end

        // The estimate belongs to whatever follows a guess marker. Splitting there keeps
        // "call mum for twenty minutes" from eating "twenty" out of the category name in
        // the rare phrasing where a number is genuinely part of it.
        let guessIndex = tokens.firstIndex { lexicon.guessMarkers.contains($0) }
        let durationRange = guessIndex.map { ($0 + 1)..<tokens.count } ?? tokens.indices.suffix(from: intentIndex + 1)
        let durationTokens = Array(tokens[durationRange])

        let duration = SpokenDuration.scan(tokens: durationTokens, lexicon: lexicon)
        let durationOffset = durationRange.lowerBound
        let durationConsumed = Set(duration.consumedIndices.map { $0 + durationOffset })

        let context = tokens.compactMap { lexicon.contextCues[$0] }.first
        let contextIndices = Set(
            tokens.indices.filter { lexicon.contextCues[tokens[$0]] != nil }
        )

        // Whatever is left once the grammar is lifted out is the category the person
        // named, in their own words and their own language.
        var dropped = durationConsumed
            .union(contextIndices)
            .union([intentIndex])
        if let guessIndex { dropped.formUnion([guessIndex]) }
        if let guessIndex { dropped.formUnion(Set(guessIndex..<tokens.count)) }

        let remaining = tokens.indices
            .filter { !dropped.contains($0) }
            .map { tokens[$0] }
            .filter { !lexicon.fillers.contains($0) && !lexicon.conjunctions.contains($0) }

        let reference = remaining.joined(separator: " ").trimmingCharacters(in: .whitespaces)

        return VoiceCommand(
            intent: intent,
            categoryReference: reference.isEmpty ? nil : reference,
            estimatedMinutes: duration.minutes,
            contextTag: context,
            language: lexicon.language
        )
    }

    /// How much of the phrase this lexicon actually accounts for. Used to pick a
    /// language rather than guessing blind on every attempt.
    private func recognitionScore(tokens: [String], lexicon: VoiceLexicon) -> Int {
        tokens.reduce(0) { score, token in
            let known = lexicon.startVerbs.contains(token)
                || lexicon.endVerbs.contains(token)
                || lexicon.guessMarkers.contains(token)
                || lexicon.minuteUnits.contains(token)
                || lexicon.hourUnits.contains(token)
                || lexicon.halfWords.contains(token)
                || lexicon.halfHourWords.contains(token)
                || lexicon.oneAndAHalfWords.contains(token)
                || lexicon.quarterWords.contains(token)
                || lexicon.numbers[token] != nil
                || lexicon.contextCues[token] != nil
            return score + (known ? 1 : 0)
        }
    }
}

/// Text handling shared by every voice path.
public enum VoiceText {

    /// Lowercases and splits on whitespace, keeping the marks that live inside words in
    /// the languages supported: the apostrophe in "п'ять", the hyphen in "где-то".
    public static func tokenize(_ phrase: String) -> [String] {
        phrase
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .split { character in
                if character == "'" || character == "-" { return false }
                return !character.isLetter && !character.isNumber
            }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// A comparable form for matching names: lowercased, punctuation gone.
    public static func normalize(_ text: String) -> String {
        tokenize(text).joined(separator: " ")
    }
}
