import Foundation
import SwiftData

/// What a widget needs to draw, read once from the shared store.
///
/// A plain value rather than live model objects, because a widget renders from a
/// timeline snapshot rather than from a live query.
public struct WidgetSnapshot: Equatable, Sendable {
    public struct QuickStart: Equatable, Sendable, Identifiable {
        public let id: String
        public let categoryID: String
        public let name: String
        public let symbolName: String
        public let contextTag: String
        /// What this usually takes, so a one-tap start still carries a real guess.
        public let expectedMinutes: Int?
    }

    public struct Running: Equatable, Sendable {
        public let sessionID: String
        public let title: String
        public let contextTag: String
        public let startedAt: Date
        public let expectedMinutes: Int?
    }

    public let running: Running?
    /// Ranked by how often the person actually uses them, recalculated on each read
    /// rather than frozen at onboarding.
    public let quickStarts: [QuickStart]

    public init(running: Running?, quickStarts: [QuickStart]) {
        self.running = running
        self.quickStarts = quickStarts
    }

    public static let placeholder = WidgetSnapshot(
        running: nil,
        quickStarts: [
            .init(id: "1", categoryID: "1", name: "Work session", symbolName: "laptopcomputer",
                  contextTag: "normal", expectedMinutes: 160),
            .init(id: "2", categoryID: "2", name: "Email and messages", symbolName: "envelope",
                  contextTag: "normal", expectedMinutes: 35)
        ]
    )

    /// Reads the current state out of the shared store.
    @MainActor
    public static func current(limit: Int = 4) -> WidgetSnapshot {
        let context = SharedStore.makeContext()

        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
        let records = sessions.records
        let engine = BiasEngine()

        func expected(categoryID: String, tag: ContextTag, guess: Int?) -> Int? {
            engine.recalibratedEstimate(
                rawGuessMinutes: guess,
                for: CategoryKey(categoryID: categoryID, contextTag: tag),
                from: records
            )?.minutes
        }

        let live = sessions
            .filter { $0.startedAt != nil && $0.endedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            .first

        let running = live.flatMap { session -> Running? in
            guard let start = session.clockStart else { return nil }
            return Running(
                sessionID: session.uuid.uuidString,
                title: session.title,
                contextTag: session.contextTag.rawValue,
                startedAt: start,
                // History alone. Re-multiplying an already-corrected guess would show
                // an expectation nobody's history supports.
                expectedMinutes: session.categoryID.flatMap {
                    expected(categoryID: $0, tag: session.contextTag, guess: nil)
                }
            )
        }

        // Most used pairs first, which is what a one-tap surface should offer.
        let counts = Dictionary(grouping: records, by: \.key).mapValues(\.count)
        let quickStarts = counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .compactMap { key, _ -> QuickStart? in
                guard let category = categories.first(where: { $0.id == key.categoryID }) else { return nil }
                return QuickStart(
                    id: "\(key.categoryID)|\(key.contextTag.rawValue)",
                    categoryID: key.categoryID,
                    name: category.name,
                    symbolName: category.symbolName,
                    contextTag: key.contextTag.rawValue,
                    expectedMinutes: expected(categoryID: key.categoryID, tag: key.contextTag, guess: nil)
                )
            }

        return WidgetSnapshot(running: running, quickStarts: Array(quickStarts))
    }
}
