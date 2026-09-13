import ActivityKit
import Foundation

public struct TempoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var actualMinutes: Int
        public var isRunning: Bool
        
        public init(actualMinutes: Int = 0, isRunning: Bool = true) {
            self.actualMinutes = actualMinutes
            self.isRunning = isRunning
        }
    }
    
    public var taskTitle: String
    public var estimatedMinutes: Int
    public var startDate: Date
    
    public init(taskTitle: String, estimatedMinutes: Int, startDate: Date) {
        self.taskTitle = taskTitle
        self.estimatedMinutes = estimatedMinutes
        self.startDate = startDate
    }
}
