import Testing
import Foundation
@testable import Actual

/// The deterministic parser, exercised across the phrasings people actually use.
///
/// This is where the risk in voice lives: transcription either works or visibly does
/// not, but a parser that quietly reads "twenty five minutes" as twenty writes wrong
/// data forever. So the corpus is broad and the assertions are exact.
struct VoiceParsingTests {

    private let parser = KeywordVoiceParser()

    // MARK: - English, starting

    @Test(
        "Start phrasings are recognised",
        arguments: [
            "start a work session",
            "starting my work session",
            "I'm starting a work session",
            "begin work session",
            "let's start the work session"
        ]
    )
    func englishStart(phrase: String) throws {
        let command = try #require(parser.parse(phrase, language: .english))
        #expect(command.intent == .start)
        #expect(command.categoryReference == "work session")
    }

    @Test(
        "End phrasings are recognised",
        arguments: [
            "end work session",
            "ending the work session",
            "I'm finished with the work session",
            "stop the work session",
            "done with my work session"
        ]
    )
    func englishEnd(phrase: String) throws {
        let command = try #require(parser.parse(phrase, language: .english))
        #expect(command.intent == .end)
        #expect(command.categoryReference == "work session")
    }

    // MARK: - Durations

    @Test(
        "Spoken durations become whole minutes",
        arguments: [
            ("starting a work session, guessing three hours", 180),
            ("starting a work session, guessing two hours", 120),
            ("start work session guessing twenty five minutes", 25),
            ("start work session guessing forty five minutes", 45),
            ("start work session about ninety minutes", 90),
            ("start work session about half an hour", 30),
            ("start work session guessing an hour and a half", 90),
            ("start work session about a quarter of an hour", 15),
            ("start work session guessing 90m", 90),
            ("start work session guessing 2h", 120),
            ("start work session roughly one hour", 60),
            ("start work session guessing 45", 45)
        ]
    )
    func englishDurations(phrase: String, expected: Int) throws {
        let command = try #require(parser.parse(phrase, language: .english))
        #expect(command.estimatedMinutes == expected)
    }

    @Test("A phrase with no estimate leaves the guess empty rather than inventing one")
    func noDurationStaysNil() throws {
        let command = try #require(parser.parse("starting a work session", language: .english))
        #expect(command.estimatedMinutes == nil)
    }

    @Test("The category survives the duration being lifted out of the phrase")
    func categorySurvivesDuration() throws {
        let command = try #require(
            parser.parse("start a grocery run, guessing twenty five minutes", language: .english)
        )
        #expect(command.categoryReference == "grocery run")
        #expect(command.estimatedMinutes == 25)
    }

    // MARK: - Context tags

    @Test(
        "A spoken context cue maps onto a tag",
        arguments: [
            ("starting a work session, deadline today", ContextTag.highPressure),
            ("starting a work session, I'm tired", ContextTag.lowEnergy),
            ("starting a work session, it's noisy", ContextTag.distracted)
        ]
    )
    func contextCues(phrase: String, expected: ContextTag) throws {
        let command = try #require(parser.parse(phrase, language: .english))
        #expect(command.contextTag == expected)
    }

    @Test("Saying nothing about context leaves it unstated, not normal")
    func contextUnstated() throws {
        // The difference matters: the resolver applies the default, so the parser must
        // not pretend the person chose one.
        let command = try #require(parser.parse("starting a work session", language: .english))
        #expect(command.contextTag == nil)
    }

    @Test("A context cue does not leak into the category name")
    func contextDoesNotPolluteCategory() throws {
        let command = try #require(
            parser.parse("starting a work session, deadline today", language: .english)
        )
        #expect(command.categoryReference?.contains("deadline") == false)
    }

    // MARK: - Russian

    @Test(
        "Russian commands parse",
        arguments: [
            ("начинаю рабочую сессию, думаю два часа", VoiceIntent.start, Int?.some(120)),
            ("начинаю рабочую сессию, примерно полтора часа", .start, 90),
            ("начинаю рабочую сессию, около полчаса", .start, 30),
            ("начинаю рабочую сессию, думаю сорок пять минут", .start, 45),
            ("заканчиваю рабочую сессию", .end, nil)
        ]
    )
    func russian(phrase: String, intent: VoiceIntent, minutes: Int?) throws {
        let command = try #require(parser.parse(phrase, language: .russian))
        #expect(command.intent == intent)
        #expect(command.estimatedMinutes == minutes)
        #expect(command.language == .russian)
    }

    @Test("A Russian category name comes through untranslated")
    func russianCategoryUntouched() throws {
        let command = try #require(
            parser.parse("начинаю рабочую сессию, думаю два часа", language: .russian)
        )
        #expect(command.categoryReference == "рабочую сессию")
    }

    // MARK: - Ukrainian

    @Test(
        "Ukrainian commands parse",
        arguments: [
            ("починаю робочу сесію, думаю дві години", VoiceIntent.start, Int?.some(120)),
            ("починаю робочу сесію, приблизно півгодини", .start, 30),
            ("починаю робочу сесію, близько сорок п'ять хвилин", .start, 45),
            ("закінчую робочу сесію", .end, nil)
        ]
    )
    func ukrainian(phrase: String, intent: VoiceIntent, minutes: Int?) throws {
        let command = try #require(parser.parse(phrase, language: .ukrainian))
        #expect(command.intent == intent)
        #expect(command.estimatedMinutes == minutes)
    }

    // MARK: - Language detection

    @Test("The language is picked from the phrase, not declared in advance")
    func languageDetection() throws {
        let english = try #require(parser.parse("starting a work session, guessing two hours"))
        #expect(english.language == .english)

        let russian = try #require(parser.parse("начинаю рабочую сессию, думаю два часа"))
        #expect(russian.language == .russian)

        let ukrainian = try #require(parser.parse("починаю робочу сесію, думаю дві години"))
        #expect(ukrainian.language == .ukrainian)
    }

    // MARK: - Refusals

    @Test(
        "A phrase with no start or end verb is not forced into a command",
        arguments: ["what's the weather", "work session", "hello there", ""]
    )
    func rejectsNonCommands(phrase: String) {
        #expect(parser.parse(phrase, language: .english) == nil)
    }
}
