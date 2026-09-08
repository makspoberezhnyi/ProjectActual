import Foundation
import AppIntents
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Ends whatever is running, from a widget or the lock screen.
///
/// The whole promise of the widget is that starting or ending never requires unlocking a
/// phone or launching an app first, so this writes to the shared store directly rather
/// than deep-linking into the app and making the person wait for it to open.
public struct EndSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "End session"
    public static var description = IntentDescription("Stops the session that is running.")
    /// Stays out of the app: the point is not having to open it.
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Session")
    public var sessionID: String?

    public init() {}

    public init(sessionID: String? = nil) {
        self.sessionID = sessionID
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let context = SharedStore.makeContext()

        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.startedAt != nil && $0.endedAt == nil }
        )
        let running = (try? context.fetch(descriptor)) ?? []

        let target: Session?
        if let sessionID, let uuid = UUID(uuidString: sessionID) {
            target = running.first { $0.uuid == uuid }
        } else {
            target = running.sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }.first
        }

        guard let session = target else { return .result() }

        // The same rule as everywhere else: closing writes immediately, with nothing to
        // confirm. A quick start still owes a label, and the app asks for it next open.
        session.endedAt = .now
        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}

/// Starts one of the person's frequent category and context pairs with one tap.
public struct StartSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start session"
    public static var description = IntentDescription("Begins a session for a category you use often.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Category")
    public var categoryID: String

    @Parameter(title: "Context")
    public var contextTag: String

    @Parameter(title: "Expected minutes")
    public var estimatedMinutes: Int?

    public init() {
        categoryID = ""
        contextTag = ContextTag.normal.rawValue
    }

    public init(categoryID: String, contextTag: String, estimatedMinutes: Int?) {
        self.categoryID = categoryID
        self.contextTag = contextTag
        self.estimatedMinutes = estimatedMinutes
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let context = SharedStore.makeContext()

        let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
        guard let category = categories.first(where: { $0.id == categoryID }) else {
            return .result()
        }

        let session = Session(
            categoryID: category.id,
            title: category.name,
            contextTag: ContextTag(contextTag),
            estimatedMinutes: estimatedMinutes,
            startedAt: .now
        )
        context.insert(session)
        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result()
    }
}
