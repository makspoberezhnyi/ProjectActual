import ActivityKit
import Foundation

public struct TempoActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var estimatedMinutes: Int
        public var actualMinutes: Int
        public var isRunning: Bool
        public var statusMessage: String?
        
        public init(
            estimatedMinutes: Int = 25,
            actualMinutes: Int = 0,
            isRunning: Bool = true,
            statusMessage: String? = nil
        ) {
            self.estimatedMinutes = estimatedMinutes
            self.actualMinutes = actualMinutes
            self.isRunning = isRunning
            self.statusMessage = statusMessage
        }
    }
    
    public var taskTitle: String
    public var startDate: Date
    public var isLinkedToCalendar: Bool?
    public var isLinkedToReminders: Bool?
    
    public init(
        taskTitle: String,
        startDate: Date,
        isLinkedToCalendar: Bool? = nil,
        isLinkedToReminders: Bool? = nil
    ) {
        self.taskTitle = taskTitle
        self.startDate = startDate
        self.isLinkedToCalendar = isLinkedToCalendar
        self.isLinkedToReminders = isLinkedToReminders
    }
}

