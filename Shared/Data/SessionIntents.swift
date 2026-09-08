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
    public func perform() async throws -> some IntentResult & ProvidesDialog {
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

        guard let session = target else {
            return .result(dialog: "Nothing is running right now.")
        }

        // The same rule as everywhere else: closing writes immediately, with nothing to
        // confirm. A quick start still owes a label, and the app asks for it next open.
        let title = session.title
        session.endedAt = .now
        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result(dialog: "Ended \(title).")
    }
}

/// Starts something: one tap from the widget with a category already chosen, or a
/// spoken "Hey Siri, start a session in Actual" with nothing chosen at all.
///
/// A category is optional on purpose. Siri asking "which category?" on every single
/// invocation would be exactly the friction quick start exists to avoid, so an absent
/// category falls through to the same blind-start path the app's own quick start uses:
/// the session begins now, and gets labelled once it is clear what it was.
public struct StartSessionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start a session"
    public static var description = IntentDescription(
        "Begins timing something in Actual. Leave the category blank to start now and label it when you're done."
    )
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Category")
    public var category: CategoryEntity?

    @Parameter(title: "Context", default: "normal")
    public var contextTag: String

    @Parameter(title: "About how long, in minutes")
    public var estimatedMinutes: Int?

    public init() {
        contextTag = ContextTag.normal.rawValue
    }

    public init(category: CategoryEntity?, contextTag: String = ContextTag.normal.rawValue, estimatedMinutes: Int?) {
        self.category = category
        self.contextTag = contextTag
        self.estimatedMinutes = estimatedMinutes
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.makeContext()

        let session = Session(
            categoryID: category?.id,
            title: category?.name ?? "Unlabelled session",
            contextTag: ContextTag(contextTag),
            estimatedMinutes: estimatedMinutes,
            startedAt: .now
        )
        context.insert(session)
        try? context.save()

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif

        let dialog: IntentDialog = category != nil
            ? "Started \(category!.name)."
            : "Started. Say what it was when you're done."
        return .result(dialog: dialog)
    }
}

/// Registers the two intents above with Siri, so they can be triggered by voice or
/// found in the Shortcuts app without the person ever opening Actual.
///
/// No entitlement, no Info.plist key: App Intents-based shortcuts (the iOS 16+
/// replacement for the older SiriKit `INIntent` domains) are auto-discovered from the
/// compiled binary. This is a genuinely different mechanism from the deprecated Siri
/// domains that needed `com.apple.developer.siri`, which is why it works on a free
/// Personal Team the same as a paid one.
public struct ActualAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartSessionIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Start a session in \(.applicationName)",
                "Start \(\.$category) in \(.applicationName)"
            ],
            shortTitle: "Start a session",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: EndSessionIntent(),
            phrases: [
                "End \(.applicationName)",
                "End my session in \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "End session",
            systemImageName: "stop.circle"
        )
    }
}
