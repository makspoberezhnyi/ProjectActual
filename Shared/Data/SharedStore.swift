import Foundation
import SwiftData

/// The one store the app and its widgets both read.
///
/// A widget runs in its own process with its own sandbox, so it cannot see the app's
/// private container. Putting the store in a shared app group is what lets a widget show
/// a live session at all, rather than a stale copy pushed across by hand.
public enum SharedStore {
    public static let appGroupID = "group.app.actual.Actual"

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
    /// than refusing to open.
    public static func makeContainer() -> ModelContainer {
        if let storeURL, let shared = try? ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: storeURL)
        ) {
            return shared
        }

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
