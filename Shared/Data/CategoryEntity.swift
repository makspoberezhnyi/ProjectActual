import Foundation
import AppIntents
import SwiftData

/// A category, exposed to Siri and Shortcuts.
///
/// Category names are never translated or centrally defined — they are whatever the
/// person typed or said when they first created one. This just makes that same list
/// something Siri can offer and match against, the same way any picker in the app would.
public struct CategoryEntity: AppEntity {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    public static var defaultQuery = CategoryEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

public struct CategoryEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        await MainActor.run {
            let context = SharedStore.makeContext()
            let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
            return categories
                .filter { identifiers.contains($0.id) }
                .map { CategoryEntity(id: $0.id, name: $0.name) }
        }
    }

    /// What Siri offers when it needs to ask "which one?" — every category the person
    /// has, most recently created first, so a fresh category is easy to find.
    public func suggestedEntities() async throws -> [CategoryEntity] {
        await MainActor.run {
            let context = SharedStore.makeContext()
            let descriptor = FetchDescriptor<TaskCategory>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let categories = (try? context.fetch(descriptor)) ?? []
            return categories.map { CategoryEntity(id: $0.id, name: $0.name) }
        }
    }
}
