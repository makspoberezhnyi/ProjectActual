import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Anything that can read a spoken phrase into a command.
public protocol VoiceParsing: Sendable {
    func parse(_ phrase: String) async -> VoiceCommand?
}

extension KeywordVoiceParser: VoiceParsing {
    public func parse(_ phrase: String) async -> VoiceCommand? {
        parse(phrase, preferring: VoiceLanguage.allCases)
    }
}

/// The two-layer parser the concept describes.
///
/// Where the on-device model is available and handles the language, it does the flexible
/// parsing: natural phrasing varies too much for fixed rules to hold up. Where it is
/// not — an older OS, Apple Intelligence off, a device that cannot run it, a language it
/// does not cover — the keyword parser still handles the basic commands.
///
/// The fallback is not an error path. It is the guarantee that voice works at all.
public struct LayeredVoiceParser: VoiceParsing {
    private let keyword: KeywordVoiceParser
    /// Languages the model is trusted with. Anything outside this goes straight to
    /// keywords rather than risking a confident misreading.
    private let modelLanguages: Set<VoiceLanguage>

    public init(
        keyword: KeywordVoiceParser = KeywordVoiceParser(),
        modelLanguages: Set<VoiceLanguage> = [.english]
    ) {
        self.keyword = keyword
        self.modelLanguages = modelLanguages
    }

    /// Whether the on-device model can be used at all right now.
    ///
    /// Checked at the point of use rather than cached, since Apple Intelligence can be
    /// switched off, and the model can be still downloading, between one command and
    /// the next.
    public static var isModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    public func parse(_ phrase: String) async -> VoiceCommand? {
        // The keyword pass runs first regardless: it is instant, it decides the
        // language, and it is the answer if the model cannot be reached.
        let fallback = keyword.parse(phrase, preferring: VoiceLanguage.allCases)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let language = fallback?.language ?? .english
            guard modelLanguages.contains(language), Self.isModelAvailable else { return fallback }

            if let parsed = await modelParse(phrase, language: language) {
                return merge(
                    model: parsed,
                    deterministic: fallback,
                    scannedMinutes: keyword.scanDuration(phrase)
                )
            }
        }
        #endif

        return fallback
    }

    /// Combines the two readings, giving each layer only what it is actually good at.
    ///
    /// The model is used for language: loose phrasing, and the words naming the activity.
    /// It is **not** trusted with the number. Asked for "probably two hours" it will
    /// happily answer 2, and a two hour session logged against a two minute estimate is
    /// a sixty-fold error feeding straight into the bias engine. Arithmetic stays with
    /// the deterministic scanner, which either reads a duration correctly or reports
    /// none at all.
    private func merge(
        model: VoiceCommand,
        deterministic: VoiceCommand?,
        scannedMinutes: Int?
    ) -> VoiceCommand {
        var merged = model

        // The scanner is the sole authority on the number. If it read one, that is the
        // number; if it read none, the phrase did not plainly contain one and the
        // model's answer is dropped. A missing guess is a supported state throughout the
        // app. A wrong one is silent corruption.
        merged.estimatedMinutes = scannedMinutes

        if let deterministic {
            // A cue matched by an explicit word beats the model's impression of tone.
            if let tag = deterministic.contextTag {
                merged.contextTag = tag
            }
            if merged.categoryReference == nil {
                merged.categoryReference = deterministic.categoryReference
            }
            merged.language = deterministic.language
        }

        return merged
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func modelParse(_ phrase: String, language: VoiceLanguage) async -> VoiceCommand? {
        let session = LanguageModelSession(instructions: Self.instructions)

        do {
            let response = try await session.respond(to: phrase, generating: SpokenCommand.self)
            return response.content.command(language: language)
        } catch {
            // A refusal, a timeout, a model that unloaded mid-sentence: none of these
            // should cost the person their command, so the keyword reading stands.
            return nil
        }
    }

    private static let instructions = """
        You extract structured commands from short spoken phrases in a personal time \
        tracking app.

        Return the intent, the words naming the activity, an optional duration in whole \
        minutes, and an optional context.

        Rules:
        - intent is "start" or "end". If the phrase is neither, return "start" only when \
        it clearly begins something.
        - activity is the person's own words for what they are doing, with the grammar \
        stripped out. Never translate it and never rename it. "starting a work session" \
        gives "work session".
        - durationMinutes is whole MINUTES, or 0 when no duration was spoken. Convert \
        units: "two hours" is 120, not 2. "half an hour" is 30. "an hour and a half" is \
        90. Never invent a duration that was not spoken.
        - context is one of "normal", "high pressure", "low energy", "distracted", and \
        only when the phrase actually signals it. Use "normal" when nothing was said.
        """
    #endif
}

#if canImport(FoundationModels)
/// The shape the model is asked to fill in.
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "A spoken command in a time tracking app")
struct SpokenCommand {
    @Guide(description: "Either 'start' or 'end'")
    var intent: String

    @Guide(description: "The person's own words for the activity, grammar removed, never translated")
    var activity: String

    @Guide(description: "Duration in whole minutes, or 0 if none was spoken")
    var durationMinutes: Int

    @Guide(description: "One of: normal, high pressure, low energy, distracted")
    var context: String

    /// Converts the model's answer into the same value type the keyword parser produces,
    /// so nothing downstream can tell which layer did the work.
    func command(language: VoiceLanguage) -> VoiceCommand? {
        let normalizedIntent = intent.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let intent: VoiceIntent
        switch normalizedIntent {
        case "start", "begin": intent = .start
        case "end", "stop", "finish": intent = .end
        default: return nil
        }

        let activityText = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = ContextTag(context)

        return VoiceCommand(
            intent: intent,
            categoryReference: activityText.isEmpty ? nil : activityText,
            // Zero means nothing was spoken, which is different from a zero-minute guess.
            estimatedMinutes: durationMinutes > 0 ? durationMinutes : nil,
            contextTag: ContextTag.defaults.contains(tag) ? tag : nil,
            language: language
        )
    }
}
#endif
