import Testing
import Foundation
@testable import Actual

struct GapFinderTests {

    private let day = Date(timeIntervalSince1970: 1_757_000_000)

    private func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
    private func bounds(_ from: Double, _ to: Double) -> TimeWindow {
        TimeWindow(start: at(from), end: at(to))
    }
    private func busy(_ from: Double, _ to: Double, _ title: String = "") -> BusyInterval {
        BusyInterval(start: at(from), end: at(to), title: title)
    }

    @Test("An empty day is one long gap")
    func emptyDay() {
        let gaps = GapFinder.gaps(in: bounds(9, 17), busy: [])
        #expect(gaps.count == 1)
        #expect(gaps.first?.minutes == 480)
    }

    @Test("Gaps fall between fixed commitments")
    func betweenEvents() {
        let gaps = GapFinder.gaps(in: bounds(9, 17), busy: [busy(10, 11), busy(14, 15)])
        #expect(gaps.count == 3)
        #expect(gaps.map(\.minutes) == [60, 180, 120])
    }

    @Test("Overlapping commitments merge rather than inventing a gap between them")
    func overlapsMerge() {
        // Two meetings that overlap are one busy block. Treating them separately would
        // produce a free stretch that does not exist.
        let gaps = GapFinder.gaps(in: bounds(9, 17), busy: [busy(10, 12), busy(11, 13)])
        #expect(gaps.map(\.minutes) == [60, 240])
    }

    @Test("Commitments running past the bounds are clipped, not discarded")
    func clipsToBounds() {
        let gaps = GapFinder.gaps(in: bounds(9, 17), busy: [busy(7, 10), busy(16, 20)])
        #expect(gaps.count == 1)
        #expect(gaps.first?.minutes == 360)
    }

    @Test("Stretches too short to suggest into are not offered")
    func minimumSize() {
        let gaps = GapFinder.gaps(in: bounds(9, 17), busy: [busy(9, 12), busy(12.1, 17)])
        #expect(gaps.isEmpty)
    }

    @Test("A fully booked day has no gaps")
    func fullyBooked() {
        #expect(GapFinder.gaps(in: bounds(9, 17), busy: [busy(9, 17)]).isEmpty)
    }

    @Test("The current gap runs from now, not from when the gap opened")
    func currentGapStartsNow() throws {
        // Standing at 15:30 in a gap that opened at 15:00, the free stretch is ninety
        // minutes, not two hours.
        let gap = try #require(
            GapFinder.currentGap(at: at(15.5), in: bounds(9, 17), busy: [busy(14, 15)])
        )
        #expect(gap.minutes == 90)
    }

    @Test("There is no current gap in the middle of a commitment")
    func noGapWhenBusy() {
        #expect(GapFinder.currentGap(at: at(14.5), in: bounds(9, 17), busy: [busy(14, 15)]) == nil)
    }
}

struct SuggestionRankerTests {

    private let ranker = SuggestionRanker()
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    private func window(minutes: Int) -> TimeWindow {
        TimeWindow(start: now, end: now.addingTimeInterval(Double(minutes) * 60))
    }

    private func history(
        category: String,
        minutes: Int,
        count: Int
    ) -> [SessionRecord] {
        (0..<count).map { index in
            SessionRecord(
                categoryID: category, contextTag: .normal,
                estimatedMinutes: minutes, actualMinutes: minutes,
                endedAt: now.addingTimeInterval(-Double(index) * 86_400)
            )
        }
    }

    private let names = [
        "call": "Call mum", "reading": "Read a chapter",
        "work": "Work session", "commute": "Commute to office"
    ]

    @Test("Only activities that fit the window are offered")
    func fitsTheWindow() {
        let records = history(category: "call", minutes: 15, count: 10)
            + history(category: "work", minutes: 150, count: 10)

        let suggestions = ranker.suggestions(
            for: window(minutes: 55), history: records, categoryNames: names
        )
        #expect(suggestions.map(\.title) == ["Call mum"])
    }

    @Test("More habitual activities rank above rarer ones")
    func ranksByHabit() {
        let records = history(category: "call", minutes: 15, count: 18)
            + history(category: "reading", minutes: 20, count: 6)

        let suggestions = ranker.suggestions(
            for: window(minutes: 55), history: records, categoryNames: names
        )
        #expect(suggestions.map(\.title) == ["Call mum", "Read a chapter"])
    }

    @Test("The list is capped rather than overwhelming a short window")
    func capped() {
        let records = history(category: "call", minutes: 15, count: 18)
            + history(category: "reading", minutes: 20, count: 12)
            + history(category: "commute", minutes: 10, count: 9)
            + history(category: "work", minutes: 25, count: 4)

        #expect(
            ranker.suggestions(for: window(minutes: 55), history: records, categoryNames: names).count == 3
        )
    }

    @Test("A pending item with no logged history is still offered, without a time")
    func planningItemWithoutDuration() throws {
        let suggestions = ranker.suggestions(
            for: window(minutes: 55),
            history: [],
            categoryNames: [:],
            pending: [PendingItem(id: "1", title: "Book the dentist", dueDate: nil)],
            now: now
        )
        let first = try #require(suggestions.first)
        #expect(first.title == "Book the dentist")
        // Never logged through the app, so there is nothing honest to say about length.
        #expect(first.typicalMinutes == nil)
    }

    @Test("An item due soon is weighted above one with no due date")
    func urgencyWeighting() {
        let suggestions = ranker.suggestions(
            for: window(minutes: 55),
            history: [],
            categoryNames: [:],
            pending: [
                PendingItem(id: "later", title: "Someday thing", dueDate: nil),
                PendingItem(id: "soon", title: "Book the dentist",
                            dueDate: now.addingTimeInterval(20 * 3600))
            ],
            now: now
        )
        #expect(suggestions.first?.title == "Book the dentist")
    }

    @Test("A strong habit still outranks a pending item")
    func habitBeatsPending() {
        let records = history(category: "call", minutes: 15, count: 20)
        let suggestions = ranker.suggestions(
            for: window(minutes: 55),
            history: records,
            categoryNames: names,
            pending: [PendingItem(id: "1", title: "Book the dentist",
                                  dueDate: now.addingTimeInterval(20 * 3600))],
            now: now
        )
        #expect(suggestions.first?.title == "Call mum")
    }

    @Test("Excluded categories are never offered, however habitual they are")
    func excludedCategories() {
        // A commute is travel to a fixed place, not a way to spend a free hour.
        let records = history(category: "commute", minutes: 35, count: 20)
            + history(category: "call", minutes: 15, count: 8)

        let suggestions = ranker.suggestions(
            for: window(minutes: 55),
            history: records,
            categoryNames: names,
            excluding: ["commute"]
        )
        #expect(suggestions.map(\.title) == ["Call mum"])
    }

    @Test("Nothing fitting means nothing offered, rather than a bad suggestion")
    func nothingFits() {
        let records = history(category: "work", minutes: 150, count: 20)
        #expect(
            ranker.suggestions(for: window(minutes: 20), history: records, categoryNames: names).isEmpty
        )
    }
}
