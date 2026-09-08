import Foundation

/// A reminder one person hands another, without either needing to already share the app.
///
/// Note what is deliberately absent: no category and no context tag. Those describe the
/// recipient's own relationship to the task, not the sender's, and are chosen later by
/// whoever actually receives it.
public struct SharedReminder: Equatable, Sendable, Codable, Identifiable {
    public let shareID: String
    public var id: String { shareID }
    public let title: String
    public let windowStart: Date
    public let windowEnd: Date
    public let senderName: String
    /// The sender's own rough guess. Optional, and it is what lets the app wait for a
    /// stretch that actually fits rather than dropping this into a list.
    public let senderEstimatedMinutes: Int?
    public let createdAt: Date

    public init(
        shareID: String = SharedReminder.makeShareID(),
        title: String,
        windowStart: Date,
        windowEnd: Date,
        senderName: String,
        senderEstimatedMinutes: Int?,
        createdAt: Date = .now
    ) {
        self.shareID = shareID
        self.title = title
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.senderName = senderName
        self.senderEstimatedMinutes = senderEstimatedMinutes
        self.createdAt = createdAt
    }

    /// A short token, in the shape the eventual server-resolved link would use.
    public static func makeShareID() -> String {
        let alphabet = Array("abcdefghijkmnpqrstuvwxyz23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }

    public var window: TimeWindow { TimeWindow(start: windowStart, end: windowEnd) }

    public func hasExpired(at moment: Date = .now) -> Bool { moment > windowEnd }

    /// "Anytime Saturday", "Today", "This weekend" — the loose window as the sender
    /// meant it, rather than a fixed slot.
    public var windowDescription: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(windowStart), calendar.isDateInToday(windowEnd) {
            return "Today"
        }
        if calendar.isDate(windowStart, inSameDayAs: windowEnd) {
            return "Anytime \(windowStart.formatted(.dateTime.weekday(.wide)))"
        }
        return "\(windowStart.formatted(.dateTime.weekday(.abbreviated))) to \(windowEnd.formatted(.dateTime.weekday(.abbreviated)))"
    }
}

/// Turns a reminder into a link and back.
///
/// The concept calls for CKShare, with a short token resolved by the sender's own
/// iCloud record. That needs a CloudKit container and an associated domain, so until
/// those exist the payload travels inside the link itself. The shape on both sides is
/// the same, so swapping the transport later does not change anything above this.
public enum SharedReminderLink {
    public static let scheme = "actual"
    public static let path = "r"
    /// What the sender sees and copies. Cosmetic: the real link carries the payload.
    public static func displayText(for reminder: SharedReminder) -> String {
        "actual.app/r/\(reminder.shareID)"
    }

    public static func url(for reminder: SharedReminder) -> URL? {
        guard let data = try? JSONEncoder.shareEncoder.encode(reminder) else { return nil }
        return URL(string: "\(scheme)://\(path)/\(data.base64URLEncodedString())")
    }

    public static func reminder(from url: URL) -> SharedReminder? {
        guard url.scheme == scheme else { return nil }

        // Tolerates both actual://r/<payload> and actual:///r/<payload>.
        let components = ([url.host].compactMap { $0 } + url.pathComponents)
            .filter { $0 != "/" && !$0.isEmpty }
        guard components.first == path, components.count >= 2 else { return nil }

        guard let data = Data(base64URLEncoded: components[1]) else { return nil }
        return try? JSONDecoder.shareDecoder.decode(SharedReminder.self, from: data)
    }
}

/// The boolean-only notification a recipient can send back to a sender: that
/// something happened, never how long it took or what either guess was.
///
/// This exists because the app has no backend. Stage 6 of the concept calls for the
/// sender to get "a single boolean notification once the item is marked done" — here
/// that notification travels the same way the original invite did, as a link, and the
/// recipient's own share sheet is the transport (Messages, AirDrop, whatever they'd
/// already use). It is exactly as real as the rest of the link-based design, just
/// visibly manual rather than pretending to be a push notification with nowhere to
/// come from.
public enum PingLink {
    public static let path = "ping"

    public static func url(shareID: String) -> URL? {
        URL(string: "\(SharedReminderLink.scheme)://\(path)/\(shareID)")
    }

    public static func shareID(from url: URL) -> String? {
        guard url.scheme == SharedReminderLink.scheme else { return nil }
        let components = ([url.host].compactMap { $0 } + url.pathComponents)
            .filter { $0 != "/" && !$0.isEmpty }
        guard components.first == path, components.count >= 2 else { return nil }
        return components[1]
    }
}

extension JSONEncoder {
    static var shareEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

extension JSONDecoder {
    static var shareDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}

extension Data {
    /// Base64 without the characters that need escaping inside a URL.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded string: String) {
        var padded = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        self.init(base64Encoded: padded)
    }
}
