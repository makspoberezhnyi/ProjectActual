import Testing
import Foundation
import SwiftData
@testable import Actual

/// Export and import operate on a real, in-memory store rather than mocked data,
/// since the interesting behaviour — upserting by unique key, not duplicating on a
/// repeat import — only shows up against SwiftData's own identity handling.
@MainActor
struct DataTransferTests {

    private func makeContext() -> ModelContext {
        let schema = Schema([TaskCategory.self, Session.self, ReceivedReminder.self, SentReminder.self])
        let container = try! ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("A round trip through encode and decode preserves every field")
    func roundTrips() throws {
        let context = makeContext()
        let category = TaskCategory(id: "work", name: "Work session", symbolName: "laptopcomputer")
        context.insert(category)
        let session = Session(
            categoryID: "work", title: "Work session", contextTag: .highPressure,
            estimatedMinutes: 90, startedAt: .now.addingTimeInterval(-3600), endedAt: .now
        )
        context.insert(session)
        try context.save()

        let export = DataTransfer.export(from: context)
        let data = try DataTransfer.encode(export)
        let decoded = try DataTransfer.decode(data)

        #expect(decoded.categories.count == 1)
        #expect(decoded.categories.first?.name == "Work session")
        #expect(decoded.sessions.count == 1)
        #expect(decoded.sessions.first?.contextTagRaw == "high pressure")
        #expect(decoded.sessions.first?.estimatedMinutes == 90)
    }

    @Test("Importing into an empty store adds everything")
    func importsIntoEmptyStore() throws {
        let source = makeContext()
        source.insert(TaskCategory(id: "work", name: "Work session", symbolName: "laptopcomputer"))
        source.insert(
            Session(categoryID: "work", title: "Work session", estimatedMinutes: 60, startedAt: .now, endedAt: .now)
        )
        try source.save()
        let export = DataTransfer.export(from: source)

        let destination = makeContext()
        let summary = DataTransfer.merge(export, into: destination)

        #expect(summary.categoriesAdded == 1)
        #expect(summary.sessionsAdded == 1)
        #expect((try? destination.fetch(FetchDescriptor<TaskCategory>()))?.count == 1)
        #expect((try? destination.fetch(FetchDescriptor<Session>()))?.count == 1)
    }

    @Test("Importing the same export twice does not duplicate anything")
    func idempotentOnRepeatImport() throws {
        let source = makeContext()
        source.insert(TaskCategory(id: "work", name: "Work session", symbolName: "laptopcomputer"))
        source.insert(
            Session(categoryID: "work", title: "Work session", estimatedMinutes: 60, startedAt: .now, endedAt: .now)
        )
        try source.save()
        let export = DataTransfer.export(from: source)

        let destination = makeContext()
        _ = DataTransfer.merge(export, into: destination)
        let second = DataTransfer.merge(export, into: destination)

        // The second pass finds the same rows already there and updates them in
        // place — the assertion that matters is that nothing new was *added*.
        #expect(second.categoriesAdded == 0)
        #expect(second.sessionsAdded == 0)
        #expect((try? destination.fetch(FetchDescriptor<TaskCategory>()))?.count == 1)
        #expect((try? destination.fetch(FetchDescriptor<Session>()))?.count == 1)
    }

    @Test("Importing merges with what is already there rather than replacing it")
    func mergesRatherThanReplaces() throws {
        let destination = makeContext()
        destination.insert(TaskCategory(id: "existing", name: "Already here", symbolName: "circle"))
        try destination.save()

        let source = makeContext()
        source.insert(TaskCategory(id: "new", name: "From the import", symbolName: "circle"))
        try source.save()
        let export = DataTransfer.export(from: source)

        _ = DataTransfer.merge(export, into: destination)

        let categories = (try? destination.fetch(FetchDescriptor<TaskCategory>())) ?? []
        #expect(categories.count == 2)
        #expect(categories.contains { $0.id == "existing" })
        #expect(categories.contains { $0.id == "new" })
    }

    @Test("Importing a category update changes its fields without creating a duplicate")
    func updatesExistingCategory() throws {
        let destination = makeContext()
        destination.insert(TaskCategory(id: "work", name: "Old name", symbolName: "circle"))
        try destination.save()

        let source = makeContext()
        source.insert(TaskCategory(id: "work", name: "New name", symbolName: "laptopcomputer"))
        try source.save()
        let export = DataTransfer.export(from: source)

        let summary = DataTransfer.merge(export, into: destination)

        #expect(summary.categoriesUpdated == 1)
        #expect(summary.categoriesAdded == 0)
        let categories = (try? destination.fetch(FetchDescriptor<TaskCategory>())) ?? []
        #expect(categories.count == 1)
        #expect(categories.first?.name == "New name")
    }

    @Test("Decoding garbage data fails cleanly rather than crashing")
    func decodingGarbageFails() {
        #expect(throws: (any Error).self) {
            try DataTransfer.decode(Data("not an export".utf8))
        }
    }
}
