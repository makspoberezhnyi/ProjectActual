import Testing
import Foundation
@testable import Actual

struct CategoryMatcherTests {

    private let matcher = CategoryMatcher()

    private let categories = [
        CategoryMatcher.Candidate(id: "work", name: "Work session"),
        CategoryMatcher.Candidate(id: "commute", name: "Commute to office"),
        CategoryMatcher.Candidate(id: "email", name: "Email and messages"),
        CategoryMatcher.Candidate(id: "grocery", name: "Grocery run")
    ]

    @Test("An exact name matches")
    func exact() {
        #expect(matcher.match("work session", against: categories) == .one(categories[0]))
    }

    @Test("A partial name matches, since nobody says a category the same way twice")
    func partial() {
        #expect(matcher.match("work", against: categories) == .one(categories[0]))
        #expect(matcher.match("grocery", against: categories) == .one(categories[3]))
    }

    @Test("Case and punctuation do not matter")
    func normalisation() {
        #expect(matcher.match("Work Session!", against: categories) == .one(categories[0]))
    }

    @Test("Nothing close enough returns no match rather than the nearest thing")
    func noMatch() {
        #expect(matcher.match("swimming", against: categories) == .none)
    }

    @Test("Two equally likely names come back as ambiguous, not silently picked")
    func ambiguity() {
        let overlapping = [
            CategoryMatcher.Candidate(id: "a", name: "Work session"),
            CategoryMatcher.Candidate(id: "b", name: "Work call")
        ]
        guard case .several(let matches) = matcher.match("work", against: overlapping) else {
            Issue.record("Expected an ambiguous match")
            return
        }
        #expect(matches.count == 2)
    }

    @Test("An exact match wins over a name that merely contains the same word")
    func exactBeatsOverlap() {
        let overlapping = [
            CategoryMatcher.Candidate(id: "a", name: "Work"),
            CategoryMatcher.Candidate(id: "b", name: "Work session")
        ]
        #expect(matcher.match("work", against: overlapping) == .one(overlapping[0]))
    }

    @Test("Matching does not depend on the language the category was named in")
    func languageAgnostic() {
        let mixed = [
            CategoryMatcher.Candidate(id: "ru", name: "Рабочая сессия"),
            CategoryMatcher.Candidate(id: "ua", name: "Читати книгу"),
            CategoryMatcher.Candidate(id: "en", name: "Work session")
        ]
        #expect(matcher.match("рабочая сессия", against: mixed) == .one(mixed[0]))
        #expect(matcher.match("читати книгу", against: mixed) == .one(mixed[1]))
    }

    @Test("An empty list matches nothing rather than crashing")
    func emptyList() {
        #expect(matcher.match("work", against: []) == .none)
    }
}

struct VoiceResolverTests {

    private let parser = KeywordVoiceParser()
    private let resolver = VoiceResolver()

    private let categories = [
        CategoryMatcher.Candidate(id: "work", name: "Work session"),
        CategoryMatcher.Candidate(id: "grocery", name: "Grocery run")
    ]

    private func resolve(_ phrase: String, open: [OpenSession] = []) throws -> VoiceOutcome {
        let command = try #require(parser.parse(phrase))
        return resolver.resolve(command, categories: categories, openSessions: open)
    }

    // MARK: - Starting

    @Test("A spoken start becomes a start request against the right category")
    func startsKnownCategory() throws {
        let outcome = try resolve("starting a work session, guessing two hours")
        guard case .start(let request) = outcome else {
            Issue.record("Expected a start, got \(outcome)")
            return
        }
        #expect(request.categoryID == "work")
        #expect(request.title == "Work session")
        #expect(request.estimatedMinutes == 120)
        #expect(request.contextTag == .normal)
    }

    @Test("An unstated context resolves to normal")
    func defaultsToNormal() throws {
        let outcome = try resolve("starting a work session")
        guard case .start(let request) = outcome else {
            Issue.record("Expected a start")
            return
        }
        #expect(request.contextTag == .normal)
    }

    @Test("A spoken context cue carries through to the request")
    func carriesContext() throws {
        let outcome = try resolve("starting a work session, deadline tomorrow, guessing an hour")
        guard case .start(let request) = outcome else {
            Issue.record("Expected a start")
            return
        }
        #expect(request.contextTag == .highPressure)
        #expect(request.estimatedMinutes == 60)
    }

    @Test("An unfamiliar category is created rather than refused")
    func createsNewCategory() throws {
        let outcome = try resolve("starting a swimming lesson, guessing 45 minutes")
        guard case .start(let request) = outcome else {
            Issue.record("Expected a start, got \(outcome)")
            return
        }
        // Saying something out loud is a perfectly good way to create a category.
        #expect(request.categoryID == nil)
        #expect(request.title == "Swimming lesson")
        #expect(request.estimatedMinutes == 45)
    }

    // MARK: - Ending

    @Test("Ending names the session to close, even with several running")
    func endsTheNamedSession() throws {
        let work = OpenSession(id: UUID(), categoryID: "work", title: "Work session")
        let grocery = OpenSession(id: UUID(), categoryID: "grocery", title: "Grocery run")

        let outcome = try resolve("ending the work session", open: [work, grocery])
        #expect(outcome == .end(sessionID: work.id))
    }

    @Test("A bare stop with one session running closes it")
    func bareStopWithOneRunning() throws {
        let work = OpenSession(id: UUID(), categoryID: "work", title: "Work session")
        let outcome = try resolve("stop", open: [work])
        #expect(outcome == .end(sessionID: work.id))
    }

    @Test("A bare stop with several running asks which one")
    func bareStopWithSeveralRunning() throws {
        let work = OpenSession(id: UUID(), categoryID: "work", title: "Work session")
        let grocery = OpenSession(id: UUID(), categoryID: "grocery", title: "Grocery run")

        let outcome = try resolve("stop", open: [work, grocery])
        guard case .ambiguous(let choice) = outcome else {
            Issue.record("Expected a question, got \(outcome)")
            return
        }
        #expect(choice.options.count == 2)
    }

    @Test("Ending something that is not running does not close whatever happens to be")
    func doesNotCloseTheWrongSession() throws {
        let work = OpenSession(id: UUID(), categoryID: "work", title: "Work session")
        // Writing an end time onto a session the person did not name would corrupt the
        // history quietly, which is worse than admitting it was not understood.
        let outcome = try resolve("ending the grocery run", open: [work])
        #expect(outcome == .notUnderstood(.noMatchingOpenSession(spoken: "grocery run")))
    }

    @Test("Ending with nothing running says so")
    func nothingRunning() throws {
        let outcome = try resolve("ending the work session", open: [])
        #expect(outcome == .notUnderstood(.nothingRunning))
    }

    // MARK: - Other languages end to end

    @Test("A Russian phrase resolves against English-named categories")
    func russianAgainstEnglishCategories() throws {
        // The grammar is Russian, the category name is English, and matching never
        // depends on translating either one.
        let command = try #require(parser.parse("начинаю work session, думаю два часа"))
        let outcome = resolver.resolve(command, categories: categories, openSessions: [])

        guard case .start(let request) = outcome else {
            Issue.record("Expected a start, got \(outcome)")
            return
        }
        #expect(request.categoryID == "work")
        #expect(request.estimatedMinutes == 120)
    }
}
