import Foundation
import SwiftData
import os

/// The one store the app and its widgets both read.
///
/// A widget runs in its own process with its own sandbox, so it cannot see the app's
/// private container. Putting the store in a shared app group is what lets a widget show
/// a live session at all, rather than a stale copy pushed across by hand.
public enum SharedStore {
    public static let appGroupID = "group.app.actual.Actual"

    private static let logger = Logger(subsystem: "app.actual.Actual", category: "SharedStore")

    /// Nil when the app group is unavailable, which happens if the entitlement is
    /// missing. The app falls back to a private store rather than refusing to open.
    public static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Actual.store")
    }

    public static let schema = Schema([TaskCategory.self, Session.self, ReceivedReminder.self, SentReminder.self])

    /// Opens the shared store, falling back to a private one, and finally to memory.
    ///
    /// Losing the store should never take the app down with it. Running in memory means
    /// this launch records nothing durable, which is worse than normal but far better
    /// than refusing to open. But a silent fallback here is exactly what made a widget
    /// starting sessions no app ever saw invisible to debug: the widget process opened
    /// its own private container (a real, working store, just not the shared one) and
    /// nothing said so anywhere. Every path below is logged — visible in Console.app —
    /// specifically so "the widget runs a timer but the app never sees it" is a one-look
    /// diagnosis (private store opened, or app group unreadable) instead of a mystery.
    public static func makeContainer() -> ModelContainer {
        guard let storeURL else {
            logger.error("App group '\(appGroupID, privacy: .public)' container unavailable — falling back to a private, unshared store. Check Signing & Capabilities has App Groups enabled with this group ID on every target (Actual and ActualWidgets), and that the entitlements weren't stripped by automatic signing.")
            return makePrivateOrInMemoryContainer()
        }

        do {
            let shared = try ModelContainer(
                for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL)
            )
            logger.info("Opened shared app-group store at \(storeURL.path, privacy: .public).")
            return shared
        } catch {
            logger.error("Failed to open the shared app-group store (\(error.localizedDescription, privacy: .public)) — falling back to a private, unshared store.")
            return makePrivateOrInMemoryContainer()
        }
    }

    private static func makePrivateOrInMemoryContainer() -> ModelContainer {
        if let private_ = try? ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        ) {
            return private_
        }

        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Could not open a store of any kind: \(error)")
        }
    }

    /// A context for reading and writing outside the app's own view hierarchy, which is
    /// what a widget's intent has to do.
    @MainActor
    public static func makeContext() -> ModelContext {
        ModelContext(makeContainer())
    }
}
