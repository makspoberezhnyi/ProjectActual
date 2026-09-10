import Testing
import Foundation
import SwiftData
@testable import Actual

/// `SessionOperations` used to only exist as private methods on `RootView.MainShell`,
/// reachable only through a live view hierarchy. Extracting it made these rules —
/// category dedup, the abandoned-session ceiling, reminder expiry, ping-link gating —
/// testable against a real in-memory store, the same way `DataTransferTests` already
/// tests import/export.
@MainActor
struct SessionOperationsTests {

    private func makeContext() -> ModelContext {
        let schema = Schema([TaskCategory.self, Session.self, ReceivedReminder.self, SentReminder.self])
        let container = try! ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - resolveCategory

    @Test("A name matching an existing category, case-insensitively, reuses it rather than creating a duplicate")
    func resolveCategoryReusesExisting() {
        let context = makeContext()
        let existing = TaskCategory(name: "Work session")
        context.insert(existing)

        let resolved = SessionOperations.resolveCategory(
            named: "  WORK SESSION  ", categories: [existing], context: context
        )

        #expect(resolved.id == existing.id)
    }

    @Test("A name with no match creates and inserts a new category")
    func resolveCategoryCreatesNew() {
        let context = makeContext()
        let resolved = SessionOperations.resolveCategory(named: "Grocery run", categories: [], context: context)

        #expect(resolved.name == "Grocery run")
        try? context.save()
        let all = try? context.fetch(FetchDescriptor<TaskCategory>())
        #expect(all?.count == 1)
    }

    @Test("A provided symbol name is used for a newly created category, defaulting to a plain circle otherwise")
    func resolveCategoryUsesProvidedSymbol() {
        let context = makeContext()

        let withIcon = SessionOperations.resolveCategory(
            named: "Yoga class", symbolName: "dumbbell.fill", categories: [], context: context
        )
        #expect(withIcon.symbolName == "dumbbell.fill")

        let withoutIcon = SessionOperations.resolveCategory(
            named: "Something else", categories: [withIcon], context: context
        )
        #expect(withoutIcon.symbolName == "circle")
    }

    @Test("Resolving an existing category by name keeps its own icon rather than the caller's")
    func resolveCategoryKeepsExistingSymbol() {
        let context = makeContext()
        let existing = TaskCategory(name: "Work session", symbolName: "laptopcomputer")

        let resolved = SessionOperations.resolveCategory(
            named: "work session", symbolName: "dumbbell.fill", categories: [existing], context: context
        )

        #expect(resolved.id == existing.id)
        #expect(resolved.symbolName == "laptopcomputer")
    }

    // MARK: - isTrip

    @Test("A session under a trip category is a trip; one under a plain category, or with no category, is not")
    func isTripReadsTheCategory() {
        let trip = TaskCategory(id: "commute", name: "Commute", isTrip: true)
        let plain = TaskCategory(id: "work", name: "Work")
        let categoriesByID = [trip, plain].indexedByID()

        let tripSession = Session(categoryID: "commute", title: "Commute", estimatedMinutes: nil)
        let plainSession = Session(categoryID: "work", title: "Work", estimatedMinutes: nil)
        let quickStart = Session(categoryID: nil, title: "Unlabelled session", estimatedMinutes: nil)

        #expect(SessionOperations.isTrip(tripSession, categoriesByID: categoriesByID))
        #expect(!SessionOperations.isTrip(plainSession, categoriesByID: categoriesByID))
        #expect(!SessionOperations.isTrip(quickStart, categoriesByID: categoriesByID))
    }

    // MARK: - closeAbandoned

    @Test("A session still running past the twelve-hour ceiling is closed and flagged")
    func closeAbandonedClosesStaleSessions() {
        let context = makeContext()
        let stale = Session(
            categoryID: "work", title: "Work", estimatedMinutes: 60,
            startedAt: .now.addingTimeInterval(-13 * 3600)
        )
        let fresh = Session(
            categoryID: "work", title: "Work", estimatedMinutes: 60,
            startedAt: .now.addingTimeInterval(-30 * 60)
        )
        context.insert(stale)
        context.insert(fresh)

        SessionOperations.closeAbandoned([stale, fresh], context: context)

        #expect(stale.isClosed)
        #expect(stale.isFlaggedLowConfidence)
        #expect(!fresh.isClosed)
    }

    @Test("A session already closed is left alone")
    func closeAbandonedIgnoresClosedSessions() {
        let context = makeContext()
        let closed = Session(
            categoryID: "work", title: "Work", estimatedMinutes: 60,
            startedAt: .now.addingTimeInterval(-20 * 3600), endedAt: .now.addingTimeInterval(-19 * 3600)
        )
        context.insert(closed)

        SessionOperations.closeAbandoned([closed], context: context)

        #expect(!closed.isFlaggedLowConfidence)
    }

    // MARK: - expireLapsed

    @Test("A pending reminder past its window is marked expired, not deleted")
    func expireLapsedMarksPastWindow() {
        let context = makeContext()
        let lapsed = ReceivedReminder(
            shareID: "abc", title: "Call Sam",
            windowStart: .now.addingTimeInterval(-7200), windowEnd: .now.addingTimeInterval(-3600),
            senderName: "Sam", senderEstimatedMinutes: 20
        )
        let stillOpen = ReceivedReminder(
            shareID: "def", title: "Water the plants",
            windowStart: .now, windowEnd: .now.addingTimeInterval(3600),
            senderName: "Sam", senderEstimatedMinutes: 5
        )
        context.insert(lapsed)
        context.insert(stillOpen)

        SessionOperations.expireLapsed([lapsed, stillOpen], context: context)

        #expect(lapsed.state == .expired)
        #expect(stillOpen.state == .pending)
    }

    // MARK: - pingURL

    @Test("A session from a reminder with completion sharing on produces a ping link")
    func pingURLWhenSharingIsOn() {
        let reminder = ReceivedReminder(
            shareID: "share-1", title: "Call Sam", windowStart: .now, windowEnd: .now.addingTimeInterval(3600),
            senderName: "Sam", senderEstimatedMinutes: 20, sharesCompletion: true
        )
        let session = Session(
            categoryID: "calls", title: "Call Sam", estimatedMinutes: 20,
            sourceReminderShareID: "share-1"
        )

        let url = SessionOperations.pingURL(for: session, receivedReminders: [reminder])

        #expect(url != nil)
        #expect(PingLink.shareID(from: url!) == "share-1")
    }

    @Test("No ping link when the sender never asked to be told")
    func pingURLNilWhenSharingIsOff() {
        let reminder = ReceivedReminder(
            shareID: "share-2", title: "Call Sam", windowStart: .now, windowEnd: .now.addingTimeInterval(3600),
            senderName: "Sam", senderEstimatedMinutes: 20, sharesCompletion: false
        )
        let session = Session(
            categoryID: "calls", title: "Call Sam", estimatedMinutes: 20,
            sourceReminderShareID: "share-2"
        )

        #expect(SessionOperations.pingURL(for: session, receivedReminders: [reminder]) == nil)
    }

    @Test("No ping link for a session that never came from a reminder")
    func pingURLNilWithoutSourceReminder() {
        let session = Session(categoryID: "calls", title: "Call Sam", estimatedMinutes: 20)
        #expect(SessionOperations.pingURL(for: session, receivedReminders: []) == nil)
    }

    // MARK: - deleteSession

    @Test("Deleting a session removes it from the store")
    func deleteSessionRemovesIt() {
        let context = makeContext()
        let session = Session(categoryID: "work", title: "Work", estimatedMinutes: 60)
        context.insert(session)
        try? context.save()

        SessionOperations.deleteSession(session, context: context)

        let remaining = try? context.fetch(FetchDescriptor<Session>())
        #expect(remaining?.isEmpty == true)
    }
}
