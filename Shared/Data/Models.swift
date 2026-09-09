import Foundation
import SwiftData

/// A kind of thing the person does. Categories are theirs, named in whatever language
/// they typed, so nothing here assumes English.
@Model
final class TaskCategory {
    @Attribute(.unique) var id: String
    var name: String
    /// SF Symbol standing in for the design's hand-drawn glyphs.
    var symbolName: String
    /// Trips close automatically on arrival; everything else needs an explicit end.
    var isTrip: Bool
    /// Where a trip goes. Present only once the person has actually set one.
    var destinationName: String?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var createdAt: Date

    var hasDestination: Bool {
        destinationLatitude != nil && destinationLongitude != nil
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        symbolName: String = "circle",
        isTrip: Bool = false,
        destinationName: String? = nil,
        destinationLatitude: Double? = nil,
        destinationLongitude: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.isTrip = isTrip
        self.destinationName = destinationName
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.createdAt = createdAt
    }
}

extension Array where Element == TaskCategory {
    /// Built once and reused, rather than a fresh linear scan for every session row
    /// that needs its category's name, symbol, or trip status — `id` is unique, so
    /// this is a lossless O(1) index rather than an approximation.
    func indexedByID() -> [String: TaskCategory] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0) })
    }
}

/// One thing that happened, or is happening now.
///
/// A session exists from the moment it is created and carries its guess from the
/// start. `actualMinutes` stays nil until it closes, and closing writes immediately
/// with no confirmation step: the system is not asking for agreement, it is recording
/// what happened.
@Model
final class Session {
    @Attribute(.unique) var uuid: UUID
    /// Nil for a quick start that has not been resolved to a category yet.
    var categoryID: String?
    var title: String
    var contextTagRaw: String
    /// The person's own guess. Nil when they skipped it.
    var estimatedMinutes: Int?
    var startedAt: Date?
    /// When GPS judged the person to have actually left. A trip's duration runs from
    /// here rather than from the tap, so hunting for keys is not counted as driving.
    var departedAt: Date?
    var endedAt: Date?
    /// Set when a session auto-closed against its ceiling rather than deliberately.
    /// Kept visible as an outlier rather than deleted, but withheld from the engine.
    var isFlaggedLowConfidence: Bool
    /// True for durations observed passively rather than guessed and timed.
    var wasTrackedPassively: Bool
    /// What a routing service said this trip would take, fetched when it started.
    ///
    /// Stored separately from both the guess and the actual, because it answers a
    /// different question: not whether the person was right, but whether they tend to
    /// run later than the route itself predicts.
    var apiBaselineMinutes: Int?
    /// The path recorded for a trip, JSON-encoded `[RoutePoint]`. Nil for anything that
    /// isn't a trip, or a trip too old to have carried this field.
    var routeData: Data?
    /// Set when this session started from a reminder someone else sent. Lets a
    /// completion ping know which reminder to notify about.
    var sourceReminderShareID: String?
    var createdAt: Date

    init(
        uuid: UUID = UUID(),
        categoryID: String?,
        title: String,
        contextTag: ContextTag = .normal,
        estimatedMinutes: Int?,
        startedAt: Date? = nil,
        departedAt: Date? = nil,
        endedAt: Date? = nil,
        isFlaggedLowConfidence: Bool = false,
        wasTrackedPassively: Bool = false,
        apiBaselineMinutes: Int? = nil,
        routeData: Data? = nil,
        sourceReminderShareID: String? = nil,
        createdAt: Date = .now
    ) {
        self.uuid = uuid
        self.categoryID = categoryID
        self.title = title
        self.contextTagRaw = contextTag.rawValue
        self.estimatedMinutes = estimatedMinutes
        self.startedAt = startedAt
        self.departedAt = departedAt
        self.endedAt = endedAt
        self.isFlaggedLowConfidence = isFlaggedLowConfidence
        self.wasTrackedPassively = wasTrackedPassively
        self.apiBaselineMinutes = apiBaselineMinutes
        self.routeData = routeData
        self.sourceReminderShareID = sourceReminderShareID
        self.createdAt = createdAt
    }

    var contextTag: ContextTag {
        get { ContextTag(contextTagRaw) }
        set { contextTagRaw = newValue.rawValue }
    }

    var isRunning: Bool { startedAt != nil && endedAt == nil }
    var isClosed: Bool { endedAt != nil }

    /// Where the clock counts from: the moment of departure once GPS has seen one,
    /// otherwise the moment the person started it.
    var clockStart: Date? { departedAt ?? startedAt }

    /// Seconds elapsed, live while running and fixed once closed.
    func elapsedSeconds(now: Date = .now) -> Int {
        guard let started = clockStart else { return 0 }
        let end = endedAt ?? now
        return max(0, Int(end.timeIntervalSince(started)))
    }

    var actualMinutes: Int? {
        guard let started = clockStart, let ended = endedAt else { return nil }
        return max(0, Int(ended.timeIntervalSince(started) / 60))
    }

    /// A session only reaches the bias engine once it has a category. A quick start
    /// contributes nothing until it is resolved, which is the point: an unresolved
    /// pile should not quietly become its own backlog.
    var isResolved: Bool { categoryID != nil }

    /// The route decoded for drawing. Empty for anything that isn't a trip, or a trip
    /// with too few fixes to plot yet.
    var route: [RoutePoint] { RouteCodec.decode(routeData) }

    /// Metres actually covered, walked along the recorded path rather than a straight
    /// line between the endpoints.
    var routeDistanceMeters: Double { RouteCodec.distanceMeters(route) }

    /// The plain-value form the engine reads. Returns nil while the session is still
    /// open or unresolved.
    var record: SessionRecord? {
        guard let categoryID, let ended = endedAt else { return nil }
        return SessionRecord(
            id: uuid,
            categoryID: categoryID,
            contextTag: contextTag,
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes,
            endedAt: ended,
            isFlaggedLowConfidence: isFlaggedLowConfidence,
            apiBaselineMinutes: apiBaselineMinutes
        )
    }
}

extension Array where Element == Session {
    /// Maps a fetched list of sessions down into the values the engine works with.
    var records: [SessionRecord] { compactMap(\.record) }
}

/// A reminder someone else sent, once it has been accepted into this person's app.
///
/// It stays a distinct object only until it is started. From that point it becomes an
/// ordinary session in the recipient's own history, under whichever category they
/// mapped it to.
@Model
final class ReceivedReminder {
    enum State: String, Codable {
        case pending
        case started
        case done
        /// The window closed without it happening. Kept visible as a plain, undone item
        /// rather than deleted: a factual record that this one did not happen.
        case expired
    }

    @Attribute(.unique) var shareID: String
    var title: String
    var windowStart: Date
    var windowEnd: Date
    var senderName: String
    var senderEstimatedMinutes: Int?
    var stateRaw: String
    var acceptedAt: Date
    /// Set once the recipient actually starts it.
    var sessionID: UUID?
    /// Off by default. The sender learns only that it happened, never how long it took.
    var sharesCompletion: Bool

    init(
        shareID: String,
        title: String,
        windowStart: Date,
        windowEnd: Date,
        senderName: String,
        senderEstimatedMinutes: Int?,
        state: State = .pending,
        acceptedAt: Date = .now,
        sessionID: UUID? = nil,
        sharesCompletion: Bool = false
    ) {
        self.shareID = shareID
        self.title = title
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.senderName = senderName
        self.senderEstimatedMinutes = senderEstimatedMinutes
        self.stateRaw = state.rawValue
        self.acceptedAt = acceptedAt
        self.sessionID = sessionID
        self.sharesCompletion = sharesCompletion
    }

    convenience init(accepting reminder: SharedReminder) {
        self.init(
            shareID: reminder.shareID,
            title: reminder.title,
            windowStart: reminder.windowStart,
            windowEnd: reminder.windowEnd,
            senderName: reminder.senderName,
            senderEstimatedMinutes: reminder.senderEstimatedMinutes
        )
    }

    var state: State {
        get { State(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var window: TimeWindow { TimeWindow(start: windowStart, end: windowEnd) }

    func hasExpired(at moment: Date = .now) -> Bool {
        state == .pending && moment > windowEnd
    }

    var windowDescription: String {
        SharedReminder(
            shareID: shareID, title: title,
            windowStart: windowStart, windowEnd: windowEnd,
            senderName: senderName, senderEstimatedMinutes: senderEstimatedMinutes
        ).windowDescription
    }

    /// Whether an open stretch is genuinely big enough for what the sender expected.
    ///
    /// This is the whole point of carrying their guess: the reminder waits for a window
    /// that actually fits instead of sitting in a list to be noticed.
    func fits(_ window: TimeWindow, defaultMinutes: Int = 20) -> Bool {
        guard state == .pending else { return false }
        let needed = senderEstimatedMinutes ?? defaultMinutes
        return window.minutes >= needed && window.start <= windowEnd && window.end >= windowStart
    }
}

/// A reminder this person sent to someone else, kept so there is somewhere for a
/// completion ping to land.
///
/// Without a backend, the only way the sender learns a reminder was done is if the
/// recipient's device tells them directly — a ping link, opened on the sender's own
/// device. This is what that ping updates.
@Model
final class SentReminder {
    @Attribute(.unique) var shareID: String
    var title: String
    var windowStart: Date
    var windowEnd: Date
    var senderEstimatedMinutes: Int?
    var createdAt: Date
    /// Set when a ping link for this reminder is opened. Never how long it took or
    /// what the recipient guessed, only that it happened.
    var recipientCompletedAt: Date?

    init(
        shareID: String,
        title: String,
        windowStart: Date,
        windowEnd: Date,
        senderEstimatedMinutes: Int?,
        createdAt: Date = .now,
        recipientCompletedAt: Date? = nil
    ) {
        self.shareID = shareID
        self.title = title
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.senderEstimatedMinutes = senderEstimatedMinutes
        self.createdAt = createdAt
        self.recipientCompletedAt = recipientCompletedAt
    }

    convenience init(sharing reminder: SharedReminder) {
        self.init(
            shareID: reminder.shareID,
            title: reminder.title,
            windowStart: reminder.windowStart,
            windowEnd: reminder.windowEnd,
            senderEstimatedMinutes: reminder.senderEstimatedMinutes,
            createdAt: reminder.createdAt
        )
    }

    var hasExpired: Bool {
        recipientCompletedAt == nil && Date.now > windowEnd
    }
}
