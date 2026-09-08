import Testing
import Foundation
@testable import Actual

struct SharedReminderTests {

    private let saturday = Date(timeIntervalSince1970: 1_757_500_000)

    private func reminder(
        estimate: Int? = 25,
        start: Double = 0,
        end: Double = 24
    ) -> SharedReminder {
        SharedReminder(
            shareID: "8f2k1q",
            title: "Call Sam",
            windowStart: saturday.addingTimeInterval(start * 3600),
            windowEnd: saturday.addingTimeInterval(end * 3600),
            senderName: "Sam",
            senderEstimatedMinutes: estimate,
            createdAt: saturday
        )
    }

    @Test("A reminder survives the round trip through a link")
    func roundTrip() throws {
        let original = reminder()
        let url = try #require(SharedReminderLink.url(for: original))
        let decoded = try #require(SharedReminderLink.reminder(from: url))
        #expect(decoded == original)
    }

    @Test("The sender's guess travels with the link")
    func carriesSenderEstimate() throws {
        let url = try #require(SharedReminderLink.url(for: reminder(estimate: 25)))
        #expect(try #require(SharedReminderLink.reminder(from: url)).senderEstimatedMinutes == 25)
    }

    @Test("A reminder sent without a guess is still a valid link")
    func optionalEstimate() throws {
        let url = try #require(SharedReminderLink.url(for: reminder(estimate: nil)))
        #expect(try #require(SharedReminderLink.reminder(from: url)).senderEstimatedMinutes == nil)
    }

    @Test("A title with punctuation and non-Latin characters survives the encoding")
    func awkwardTitles() throws {
        let awkward = SharedReminder(
            title: "Подзвонити Сергію / забрати #2 — 50%",
            windowStart: saturday, windowEnd: saturday.addingTimeInterval(3600),
            senderName: "Максим", senderEstimatedMinutes: 15
        )
        let url = try #require(SharedReminderLink.url(for: awkward))
        #expect(try #require(SharedReminderLink.reminder(from: url)).title == awkward.title)
    }

    @Test(
        "A link that is not a reminder is refused rather than half-read",
        arguments: [
            "https://example.com/r/abc",
            "actual://something/else",
            "actual://r/not-base64!!",
            "actual://r/"
        ]
    )
    func rejectsBadLinks(string: String) {
        let url = URL(string: string)
        #expect(url.flatMap(SharedReminderLink.reminder(from:)) == nil)
    }

    @Test("Expiry is judged against the window closing, not the day")
    func expiry() {
        let item = reminder(start: 0, end: 5)
        #expect(item.hasExpired(at: saturday.addingTimeInterval(3 * 3600)) == false)
        #expect(item.hasExpired(at: saturday.addingTimeInterval(6 * 3600)) == true)
    }

    @Test("A window is only a fit when it is genuinely big enough for the sender's guess")
    func fitting() {
        let stored = ReceivedReminder(
            shareID: "x", title: "Call Sam",
            windowStart: saturday, windowEnd: saturday.addingTimeInterval(24 * 3600),
            senderName: "Sam", senderEstimatedMinutes: 25
        )

        let hour = TimeWindow(start: saturday.addingTimeInterval(3600),
                              end: saturday.addingTimeInterval(2 * 3600))
        let tenMinutes = TimeWindow(start: saturday.addingTimeInterval(3600),
                                    end: saturday.addingTimeInterval(3600 + 600))

        #expect(stored.fits(hour) == true)
        #expect(stored.fits(tenMinutes) == false)
    }

    @Test("A window outside the sender's range is not a fit, however long it is")
    func outsideTheWindow() {
        let stored = ReceivedReminder(
            shareID: "x", title: "Call Sam",
            windowStart: saturday, windowEnd: saturday.addingTimeInterval(6 * 3600),
            senderName: "Sam", senderEstimatedMinutes: 25
        )
        let nextWeek = TimeWindow(start: saturday.addingTimeInterval(8 * 86_400),
                                  end: saturday.addingTimeInterval(8 * 86_400 + 7200))
        #expect(stored.fits(nextWeek) == false)
    }

    @Test("An already started reminder stops matching windows")
    func startedNoLongerFits() {
        let stored = ReceivedReminder(
            shareID: "x", title: "Call Sam",
            windowStart: saturday, windowEnd: saturday.addingTimeInterval(24 * 3600),
            senderName: "Sam", senderEstimatedMinutes: 25, state: .started
        )
        let hour = TimeWindow(start: saturday, end: saturday.addingTimeInterval(3600))
        #expect(stored.fits(hour) == false)
    }
}
