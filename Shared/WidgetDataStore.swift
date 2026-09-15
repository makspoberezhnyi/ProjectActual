import Foundation

public struct PendingSessionData: Codable {
    public var id: UUID
    public var rawText: String
    public var estimatedMinutes: Int
    public var actualMinutes: Int?
    public var startedAt: Date
    public var endedAt: Date?
    public var linkedEventIdentifier: String?
    public var isLinkedToCalendar: Bool?
    public var isLinkedToReminders: Bool?
    
    public init(
        id: UUID = UUID(),
        rawText: String,
        estimatedMinutes: Int,
        actualMinutes: Int? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        linkedEventIdentifier: String? = nil,
        isLinkedToCalendar: Bool? = nil,
        isLinkedToReminders: Bool? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.linkedEventIdentifier = linkedEventIdentifier
        self.isLinkedToCalendar = isLinkedToCalendar
        self.isLinkedToReminders = isLinkedToReminders
    }
}

public struct WidgetSnapshotData: Codable {
    public var isRunning: Bool
    public var activeTaskTitle: String?
    public var activeTaskEstimatedMinutes: Int?
    public var activeTaskStartedAt: Date?
    
    public var todayMinutes: Int
    public var todayCompletedCount: Int
    public var calibrationScore: Double
    
    public init(
        isRunning: Bool = false,
        activeTaskTitle: String? = nil,
        activeTaskEstimatedMinutes: Int? = nil,
        activeTaskStartedAt: Date? = nil,
        todayMinutes: Int = 0,
        todayCompletedCount: Int = 0,
        calibrationScore: Double = 0.5
    ) {
        self.isRunning = isRunning
        self.activeTaskTitle = activeTaskTitle
        self.activeTaskEstimatedMinutes = activeTaskEstimatedMinutes
        self.activeTaskStartedAt = activeTaskStartedAt
        self.todayMinutes = todayMinutes
        self.todayCompletedCount = todayCompletedCount
        self.calibrationScore = calibrationScore
    }
}

final public class WidgetDataStore: @unchecked Sendable {
    public static let shared = WidgetDataStore()
    private let appGroupID = "group.app.actual.Actual"
    private let snapshotKey = "tempo_widget_snapshot"
    private let pendingQueueKey = "tempo_pending_sessions"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    public func loadSnapshot() -> WidgetSnapshotData {
        guard let data = userDefaults?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshotData.self, from: data) else {
            return WidgetSnapshotData()
        }
        return snapshot
    }
    
    public func saveSnapshot(_ snapshot: WidgetSnapshotData) {
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults?.set(data, forKey: snapshotKey)
        }
    }
    
    public func startSession(
        title: String,
        minutes: Int,
        startDate: Date = Date(),
        linkedEventIdentifier: String? = nil,
        isLinkedToCalendar: Bool? = nil,
        isLinkedToReminders: Bool? = nil,
        id: UUID = UUID()
    ) {
        // Auto-finalize any previously open pending sessions
        var pending = loadPendingSessions()
        let now = startDate
        for i in 0..<pending.count {
            if pending[i].endedAt == nil {
                pending[i].endedAt = now
                let elapsed = max(1, Int(now.timeIntervalSince(pending[i].startedAt) / 60))
                pending[i].actualMinutes = elapsed
            }
        }
        
        var current = loadSnapshot()
        current.isRunning = true
        current.activeTaskTitle = title
        current.activeTaskEstimatedMinutes = minutes
        current.activeTaskStartedAt = startDate
        saveSnapshot(current)
        
        let newSession = PendingSessionData(
            id: id,
            rawText: title,
            estimatedMinutes: minutes,
            startedAt: startDate,
            linkedEventIdentifier: linkedEventIdentifier,
            isLinkedToCalendar: isLinkedToCalendar,
            isLinkedToReminders: isLinkedToReminders
        )
        pending.append(newSession)
        savePendingSessions(pending)
    }
    
    public func updateActiveSessionEstimate(to newEstimatedMinutes: Int) {
        var current = loadSnapshot()
        current.activeTaskEstimatedMinutes = newEstimatedMinutes
        saveSnapshot(current)
        
        var pending = loadPendingSessions()
        var didModify = false
        if let lastIndex = pending.indices.last(where: { pending[$0].endedAt == nil }) {
            pending[lastIndex].estimatedMinutes = newEstimatedMinutes
            didModify = true
        }
        if didModify {
            savePendingSessions(pending)
        }
    }
    
    public func extendActiveSession(by minutesToAdd: Int) {
        var current = loadSnapshot()
        let updatedEst = (current.activeTaskEstimatedMinutes ?? 25) + minutesToAdd
        current.activeTaskEstimatedMinutes = updatedEst
        saveSnapshot(current)
        
        var pending = loadPendingSessions()
        var didModify = false
        if let lastIndex = pending.indices.last(where: { pending[$0].endedAt == nil }) {
            pending[lastIndex].estimatedMinutes += minutesToAdd
            didModify = true
        }
        if didModify {
            savePendingSessions(pending)
        }
    }
    
    public func stopActiveSession() {
        var current = loadSnapshot()
        var elapsed = 0
        let now = Date()
        if let start = current.activeTaskStartedAt {
            elapsed = max(1, Int(now.timeIntervalSince(start) / 60))
            current.todayMinutes += elapsed
            current.todayCompletedCount += 1
        }
        
        current.isRunning = false
        current.activeTaskTitle = nil
        current.activeTaskEstimatedMinutes = nil
        current.activeTaskStartedAt = nil
        saveSnapshot(current)
        
        // Close all unended pending sessions in queue
        var pending = loadPendingSessions()
        var modified = false
        for i in 0..<pending.count {
            if pending[i].endedAt == nil {
                pending[i].endedAt = now
                let itemElapsed = max(1, Int(now.timeIntervalSince(pending[i].startedAt) / 60))
                pending[i].actualMinutes = itemElapsed
                modified = true
            }
        }
        if modified {
            savePendingSessions(pending)
        }
    }
    
    public func loadPendingSessions() -> [PendingSessionData] {
        guard let data = userDefaults?.data(forKey: pendingQueueKey),
              let list = try? JSONDecoder().decode([PendingSessionData].self, from: data) else {
            return []
        }
        return list
    }
    
    public func savePendingSessions(_ list: [PendingSessionData]) {
        if let data = try? JSONEncoder().encode(list) {
            userDefaults?.set(data, forKey: pendingQueueKey)
        }
    }
    
    public func clearPendingSessions() {
        userDefaults?.removeObject(forKey: pendingQueueKey)
    }
}
