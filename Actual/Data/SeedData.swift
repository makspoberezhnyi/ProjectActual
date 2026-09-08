import Foundation
import SwiftData

/// Deterministic history so a fresh install opens onto a populated app rather than an
/// empty one.
///
/// Nothing here writes a display number directly. It writes plausible sessions and
/// lets the bias engine compute the multipliers, which means the screens are exercising
/// the real calculation rather than showing decoration.
enum SeedData {

    /// A small linear congruential generator. Seeded, so the same history appears on
    /// every launch and screenshots stay comparable.
    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed &* 6364136223846793005 &+ 1442695040888963407 }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        /// A jitter value in -magnitude...magnitude.
        mutating func jitter(_ magnitude: Double) -> Double {
            let unit = Double(next() % 10_000) / 10_000
            return (unit * 2 - 1) * magnitude
        }
    }

    struct Categories {
        let work: TaskCategory
        let commute: TaskCategory
        let email: TaskCategory
        let grocery: TaskCategory
        let callMum: TaskCategory
        let reading: TaskCategory
        let scrolling: TaskCategory

        var all: [TaskCategory] { [work, commute, email, grocery, callMum, reading, scrolling] }
    }

    static func populateIfEmpty(_ context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Session>())) ?? 0
        guard existing == 0 else { return }

        let categories = Categories(
            work: TaskCategory(id: "work", name: "Work session", symbolName: "laptopcomputer"),
            commute: TaskCategory(id: "commute", name: "Commute to office", symbolName: "car.fill", isTrip: true),
            email: TaskCategory(id: "email", name: "Email and messages", symbolName: "envelope"),
            grocery: TaskCategory(id: "grocery", name: "Grocery run", symbolName: "cart"),
            callMum: TaskCategory(id: "call-mum", name: "Call with mum", symbolName: "phone"),
            reading: TaskCategory(id: "reading", name: "Read a chapter", symbolName: "book"),
            scrolling: TaskCategory(id: "scrolling", name: "Scrolling, Instagram", symbolName: "rectangle.on.rectangle")
        )
        categories.all.forEach(context.insert)

        var rng = SeededGenerator(seed: 20_260_908)
        var sessions: [Session] = []

        // Work sessions, normal. 32 instances running about a third longer than guessed,
        // which is what puts 2h 40m next to a two hour guess on the capture screen.
        sessions += history(
            category: categories.work, tag: .normal, count: 32,
            guessMinutes: 120, ratio: 1.335, ratioJitter: 0.13, guessJitter: 15,
            firstDaysAgo: 0.6, dayStep: 0.92, rng: &rng
        )

        // The same category under pressure builds its own separate average, and with
        // only nine instances it stays explicitly low confidence.
        sessions += history(
            category: categories.work, tag: .highPressure, count: 9,
            guessMinutes: 90, ratio: 1.41, ratioJitter: 0.16, guessJitter: 10,
            firstDaysAgo: 1.1, dayStep: 3.2, rng: &rng
        )

        // The category people are most wrong about, and the one with the most history.
        sessions += history(
            category: categories.email, tag: .normal, count: 51,
            guessMinutes: 20, ratio: 1.78, ratioJitter: 0.22, guessJitter: 5,
            firstDaysAgo: 0.4, dayStep: 0.57, rng: &rng
        )

        sessions += history(
            category: categories.commute, tag: .normal, count: 24,
            guessMinutes: 25, ratio: 1.34, ratioJitter: 0.12, guessJitter: 3,
            firstDaysAgo: 0.9, dayStep: 1.21, rng: &rng
        )

        // Grocery runs shifted recently: the last ten sit well above the twelve before
        // them, which is what the drift detector is meant to catch and surface.
        sessions += history(
            category: categories.grocery, tag: .normal, count: 10,
            guessMinutes: 30, ratio: 1.46, ratioJitter: 0.08, guessJitter: 4,
            firstDaysAgo: 0.7, dayStep: 1.25, rng: &rng
        )
        sessions += history(
            category: categories.grocery, tag: .normal, count: 12,
            guessMinutes: 30, ratio: 1.09, ratioJitter: 0.07, guessJitter: 4,
            firstDaysAgo: 13.2, dayStep: 1.42, rng: &rng
        )

        // Two categories the person is close to right about, so the ranking has a
        // bottom as well as a top.
        sessions += history(
            category: categories.callMum, tag: .normal, count: 18,
            guessMinutes: 15, ratio: 1.10, ratioJitter: 0.10, guessJitter: 3,
            firstDaysAgo: 1.3, dayStep: 1.62, rng: &rng
        )
        sessions += history(
            category: categories.reading, tag: .normal, count: 14,
            guessMinutes: 20, ratio: 0.95, ratioJitter: 0.09, guessJitter: 4,
            firstDaysAgo: 1.8, dayStep: 2.05, rng: &rng
        )

        sessions += today(categories: categories)
        sessions += [activeWorkSession(categories: categories)]

        sessions.forEach(context.insert)
        try? context.save()
    }

    // MARK: - Generators

    private static func history(
        category: TaskCategory,
        tag: ContextTag,
        count: Int,
        guessMinutes: Int,
        ratio: Double,
        ratioJitter: Double,
        guessJitter: Double,
        firstDaysAgo: Double,
        dayStep: Double,
        rng: inout SeededGenerator
    ) -> [Session] {
        (0..<count).map { index in
            let daysAgo = firstDaysAgo + Double(index) * dayStep
            let ended = Date.now.addingTimeInterval(-daysAgo * 86_400)

            let guess = max(5, guessMinutes + Int(rng.jitter(guessJitter).rounded()))
            let effective = max(0.2, ratio + rng.jitter(ratioJitter))
            let actual = max(1, Int((Double(guess) * effective).rounded()))

            return Session(
                categoryID: category.id,
                title: category.name,
                contextTag: tag,
                estimatedMinutes: guess,
                startedAt: ended.addingTimeInterval(-Double(actual) * 60),
                endedAt: ended
            )
        }
    }

    /// The three closed items the home screen lists under Today.
    private static func today(categories: Categories) -> [Session] {
        let now = Date.now
        func at(hoursAgo: Double, lasting minutes: Int) -> (Date, Date) {
            let end = now.addingTimeInterval(-hoursAgo * 3600)
            return (end.addingTimeInterval(-Double(minutes) * 60), end)
        }

        let commute = at(hoursAgo: 6.5, lasting: 38)
        let call = at(hoursAgo: 3.2, lasting: 17)
        let scroll = at(hoursAgo: 1.6, lasting: 24)

        return [
            Session(
                categoryID: categories.commute.id, title: categories.commute.name,
                estimatedMinutes: 25, startedAt: commute.0, endedAt: commute.1
            ),
            Session(
                categoryID: categories.callMum.id, title: categories.callMum.name,
                estimatedMinutes: 15, startedAt: call.0, endedAt: call.1
            ),
            // Passively observed, so there is a duration but no guess to compare it to.
            Session(
                categoryID: categories.scrolling.id, title: categories.scrolling.name,
                estimatedMinutes: nil, startedAt: scroll.0, endedAt: scroll.1,
                wasTrackedPassively: true
            )
        ]
    }

    /// The session already running when the app opens, matching the home mockup.
    private static func activeWorkSession(categories: Categories) -> Session {
        Session(
            categoryID: categories.work.id,
            title: categories.work.name,
            contextTag: .normal,
            estimatedMinutes: 120,
            startedAt: Date.now.addingTimeInterval(-(42 * 60 + 18))
        )
    }
}
