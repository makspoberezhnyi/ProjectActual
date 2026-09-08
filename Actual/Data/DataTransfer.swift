import Foundation
import SwiftData

/// Everything the app has recorded, in one file the person actually holds.
///
/// The data belongs to whoever logged it — that is the product's whole premise — so
/// getting it out has to be as real as getting it in. This is a plain JSON snapshot of
/// every table, not a proprietary format, and importing it back is safe to run more
/// than once: matching by the same unique keys the store already uses means a repeat
/// import updates existing rows rather than duplicating history.
struct ActualDataExport: Codable {
    static let currentVersion = 1

    struct CategoryRecord: Codable {
        var id: String
        var name: String
        var symbolName: String
        var isTrip: Bool
        var destinationName: String?
        var destinationLatitude: Double?
        var destinationLongitude: Double?
        var createdAt: Date
    }

    struct SessionRecordDTO: Codable {
        var uuid: UUID
        var categoryID: String?
        var title: String
        var contextTagRaw: String
        var estimatedMinutes: Int?
        var startedAt: Date?
        var departedAt: Date?
        var endedAt: Date?
        var isFlaggedLowConfidence: Bool
        var wasTrackedPassively: Bool
        var apiBaselineMinutes: Int?
        var routeData: Data?
        var sourceReminderShareID: String?
        var createdAt: Date
    }

    struct ReceivedReminderRecord: Codable {
        var shareID: String
        var title: String
        var windowStart: Date
        var windowEnd: Date
        var senderName: String
        var senderEstimatedMinutes: Int?
        var stateRaw: String
        var acceptedAt: Date
        var sessionID: UUID?
        var sharesCompletion: Bool
    }

    struct SentReminderRecord: Codable {
        var shareID: String
        var title: String
        var windowStart: Date
        var windowEnd: Date
        var senderEstimatedMinutes: Int?
        var createdAt: Date
        var recipientCompletedAt: Date?
    }

    var version: Int
    var exportedAt: Date
    var categories: [CategoryRecord]
    var sessions: [SessionRecordDTO]
    var receivedReminders: [ReceivedReminderRecord]
    var sentReminders: [SentReminderRecord]
}

/// Reads every table out of the store and writes every table back in.
///
/// Kept as a plain enum operating on a `ModelContext` rather than living on the models
/// themselves — export/import is a app-level concern, not something a `Session` or
/// `TaskCategory` needs to know about itself.
enum DataTransfer {

    // MARK: - Export

    @MainActor
    static func export(from context: ModelContext) -> ActualDataExport {
        let categories = (try? context.fetch(FetchDescriptor<TaskCategory>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<Session>())) ?? []
        let received = (try? context.fetch(FetchDescriptor<ReceivedReminder>())) ?? []
        let sent = (try? context.fetch(FetchDescriptor<SentReminder>())) ?? []

        return ActualDataExport(
            version: ActualDataExport.currentVersion,
            exportedAt: .now,
            categories: categories.map {
                .init(
                    id: $0.id, name: $0.name, symbolName: $0.symbolName, isTrip: $0.isTrip,
                    destinationName: $0.destinationName,
                    destinationLatitude: $0.destinationLatitude,
                    destinationLongitude: $0.destinationLongitude,
                    createdAt: $0.createdAt
                )
            },
            sessions: sessions.map {
                .init(
                    uuid: $0.uuid, categoryID: $0.categoryID, title: $0.title,
                    contextTagRaw: $0.contextTagRaw, estimatedMinutes: $0.estimatedMinutes,
                    startedAt: $0.startedAt, departedAt: $0.departedAt, endedAt: $0.endedAt,
                    isFlaggedLowConfidence: $0.isFlaggedLowConfidence,
                    wasTrackedPassively: $0.wasTrackedPassively,
                    apiBaselineMinutes: $0.apiBaselineMinutes, routeData: $0.routeData,
                    sourceReminderShareID: $0.sourceReminderShareID, createdAt: $0.createdAt
                )
            },
            receivedReminders: received.map {
                .init(
                    shareID: $0.shareID, title: $0.title, windowStart: $0.windowStart,
                    windowEnd: $0.windowEnd, senderName: $0.senderName,
                    senderEstimatedMinutes: $0.senderEstimatedMinutes, stateRaw: $0.stateRaw,
                    acceptedAt: $0.acceptedAt, sessionID: $0.sessionID,
                    sharesCompletion: $0.sharesCompletion
                )
            },
            sentReminders: sent.map {
                .init(
                    shareID: $0.shareID, title: $0.title, windowStart: $0.windowStart,
                    windowEnd: $0.windowEnd, senderEstimatedMinutes: $0.senderEstimatedMinutes,
                    createdAt: $0.createdAt, recipientCompletedAt: $0.recipientCompletedAt
                )
            }
        )
    }

    static func encode(_ export: ActualDataExport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    /// Writes the export to a file the share sheet can hand off — Files, AirDrop,
    /// Mail, another app, wherever the person actually wants their data to go.
    static func writeToTemporaryFile(_ export: ActualDataExport) throws -> URL {
        let data = try encode(export)
        let name = "Actual-Export-\(DateFormatter.exportFilename.string(from: export.exportedAt)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    struct ImportSummary: Equatable {
        var categoriesAdded = 0
        var categoriesUpdated = 0
        var sessionsAdded = 0
        var sessionsUpdated = 0
        var remindersAdded = 0

        var totalChanged: Int {
            categoriesAdded + categoriesUpdated + sessionsAdded + sessionsUpdated + remindersAdded
        }
    }

    static func decode(_ data: Data) throws -> ActualDataExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ActualDataExport.self, from: data)
    }

    /// Upserts every table by the same unique key the store already enforces, so
    /// importing the same file twice changes nothing the second time, and importing an
    /// updated export from another device merges rather than duplicating.
    @MainActor
    static func merge(_ export: ActualDataExport, into context: ModelContext) -> ImportSummary {
        var summary = ImportSummary()

        var existingCategories = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<TaskCategory>())) ?? [])
                .map { ($0.id, $0) }
        )
        for record in export.categories {
            if let existing = existingCategories[record.id] {
                existing.name = record.name
                existing.symbolName = record.symbolName
                existing.isTrip = record.isTrip
                existing.destinationName = record.destinationName
                existing.destinationLatitude = record.destinationLatitude
                existing.destinationLongitude = record.destinationLongitude
                summary.categoriesUpdated += 1
            } else {
                let category = TaskCategory(
                    id: record.id, name: record.name, symbolName: record.symbolName,
                    isTrip: record.isTrip, destinationName: record.destinationName,
                    destinationLatitude: record.destinationLatitude,
                    destinationLongitude: record.destinationLongitude,
                    createdAt: record.createdAt
                )
                context.insert(category)
                existingCategories[record.id] = category
                summary.categoriesAdded += 1
            }
        }

        var existingSessions = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Session>())) ?? [])
                .map { ($0.uuid, $0) }
        )
        for record in export.sessions {
            if let existing = existingSessions[record.uuid] {
                // A session already on this device is the more trustworthy copy for
                // anything the device itself would have written since — route data,
                // an auto-close flag — so only fields an import could legitimately
                // correct are touched, not blindly overwritten.
                existing.categoryID = record.categoryID
                existing.title = record.title
                existing.contextTagRaw = record.contextTagRaw
                existing.estimatedMinutes = record.estimatedMinutes
                summary.sessionsUpdated += 1
            } else {
                let session = Session(
                    uuid: record.uuid, categoryID: record.categoryID, title: record.title,
                    contextTag: ContextTag(record.contextTagRaw),
                    estimatedMinutes: record.estimatedMinutes, startedAt: record.startedAt,
                    departedAt: record.departedAt, endedAt: record.endedAt,
                    isFlaggedLowConfidence: record.isFlaggedLowConfidence,
                    wasTrackedPassively: record.wasTrackedPassively,
                    apiBaselineMinutes: record.apiBaselineMinutes, routeData: record.routeData,
                    sourceReminderShareID: record.sourceReminderShareID,
                    createdAt: record.createdAt
                )
                context.insert(session)
                existingSessions[record.uuid] = session
                summary.sessionsAdded += 1
            }
        }

        var existingReceived = Set(
            ((try? context.fetch(FetchDescriptor<ReceivedReminder>())) ?? []).map(\.shareID)
        )
        for record in export.receivedReminders where !existingReceived.contains(record.shareID) {
            let reminder = ReceivedReminder(
                shareID: record.shareID, title: record.title, windowStart: record.windowStart,
                windowEnd: record.windowEnd, senderName: record.senderName,
                senderEstimatedMinutes: record.senderEstimatedMinutes,
                state: ReceivedReminder.State(rawValue: record.stateRaw) ?? .pending,
                acceptedAt: record.acceptedAt, sessionID: record.sessionID,
                sharesCompletion: record.sharesCompletion
            )
            context.insert(reminder)
            existingReceived.insert(record.shareID)
            summary.remindersAdded += 1
        }

        var existingSent = Set(
            ((try? context.fetch(FetchDescriptor<SentReminder>())) ?? []).map(\.shareID)
        )
        for record in export.sentReminders where !existingSent.contains(record.shareID) {
            let sent = SentReminder(
                shareID: record.shareID, title: record.title, windowStart: record.windowStart,
                windowEnd: record.windowEnd, senderEstimatedMinutes: record.senderEstimatedMinutes,
                createdAt: record.createdAt, recipientCompletedAt: record.recipientCompletedAt
            )
            context.insert(sent)
            existingSent.insert(record.shareID)
            summary.remindersAdded += 1
        }

        try? context.save()
        return summary
    }
}

private extension DateFormatter {
    static let exportFilename: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter
    }()
}
