import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// What the lock screen and Dynamic Island show for a running session.
///
/// Shared between the app, which starts and updates the activity, and the widget
/// extension, which draws it.
public struct SessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// What the timer counts from. For a trip this is the detected departure, so
        /// the lock screen shows driving time rather than time since the tap.
        public var startedAt: Date
        /// What this usually takes, when there is enough history to say. Absent during
        /// cold start rather than guessed.
        public var expectedMinutes: Int?

        public init(startedAt: Date, expectedMinutes: Int?) {
            self.startedAt = startedAt
            self.expectedMinutes = expectedMinutes
        }
    }

    public let sessionID: String
    public let title: String
    public let contextTag: String

    public init(sessionID: String, title: String, contextTag: String) {
        self.sessionID = sessionID
        self.title = title
        self.contextTag = contextTag
    }
}
#endif
