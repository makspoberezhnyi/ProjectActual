import Testing
import Foundation
@testable import Actual

/// Exercises the on-device model for real.
///
/// Skipped automatically wherever the model is unavailable — an older OS, Apple
/// Intelligence switched off, a device that cannot run it — so the suite stays green on
/// machines that simply cannot do this, rather than failing for the wrong reason.
///
/// Assertions stay on properties a competent reading must get right, never on exact
/// wording, since model output is not deterministic.
@Suite(.enabled(if: LayeredVoiceParser.isModelAvailable))
struct ModelVoiceParserTests {

    private let parser = LayeredVoiceParser()

    /// The model, asked directly, returns 2 for "probably two hours". The merge policy
    /// is what makes this pass: durations come from the deterministic scanner, never
    /// from the model.
    @Test("Loose phrasing the fixed keywords would miss still reaches the right intent")
    func loosePhrasing() async throws {
        let phrases = [
            "right, I'm going to sit down and do a work session now, probably two hours",
            "kick off a work session, I reckon about two hours"
        ]

        for phrase in phrases {
            let command = try #require(await parser.parse(phrase), "no reading for: \(phrase)")
            #expect(command.intent == .start, "wrong intent for: \(phrase)")
            #expect(command.estimatedMinutes == 120, "wrong duration for: \(phrase)")
        }
    }

    @Test("An ending phrase is read as an ending")
    func ending() async throws {
        let command = try #require(await parser.parse("alright, I'm all done with that work session"))
        #expect(command.intent == .end)
    }

    @Test("No duration spoken means no duration invented")
    func inventsNothing() async throws {
        let command = try #require(await parser.parse("starting a work session"))
        #expect(command.estimatedMinutes == nil)
    }

    @Test("A duration the phrase does not plainly contain is dropped, not guessed")
    func doesNotInventDurations() async throws {
        let command = try #require(await parser.parse("starting a work session, this'll take a while"))
        // "a while" is not a number. A missing guess is a supported state; a fabricated
        // one silently corrupts the category's history.
        #expect(command.estimatedMinutes == nil)
    }

    @Test("The activity comes back in the person's own words")
    func keepsTheirWords() async throws {
        let command = try #require(await parser.parse("starting a grocery run, about 25 minutes"))
        let reference = try #require(command.categoryReference).lowercased()
        #expect(reference.contains("grocery"))
        #expect(command.estimatedMinutes == 25)
    }
}
