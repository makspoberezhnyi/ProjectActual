import Foundation

public struct PendingSessionData: Codable {
    public var id: UUID
    public var rawText: String
    public var estimatedMinutes: Int
    public var actualMinutes: Int?
    public var startedAt: Date
    public var endedAt: Date?
    
    public init(id: UUID = UUID(), rawText: String, estimatedMinutes: Int, actualMinutes: Int? = nil, startedAt: Date = Date(), endedAt: Date? = nil) {
        self.id = id
        self.rawText = rawText
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.startedAt = startedAt
        self.endedAt = endedAt
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
    
    public func startSession(title: String, minutes: Int) {
        var current = loadSnapshot()
        current.isRunning = true
        current.activeTaskTitle = title
        current.activeTaskEstimatedMinutes = minutes
        current.activeTaskStartedAt = Date()
        saveSnapshot(current)
        
        // Add to pending queue
        var pending = loadPendingSessions()
        let newSession = PendingSessionData(
            rawText: title,
            estimatedMinutes: minutes,
            startedAt: Date()
        )
        pending.append(newSession)
        savePendingSessions(pending)
    }
    
    public func stopActiveSession() {
        var current = loadSnapshot()
        var elapsed = 0
        if let start = current.activeTaskStartedAt {
            elapsed = Int(Date().timeIntervalSince(start) / 60)
            current.todayMinutes += max(1, elapsed)
            current.todayCompletedCount += 1
        }
        
        current.isRunning = false
        current.activeTaskTitle = nil
        current.activeTaskEstimatedMinutes = nil
        current.activeTaskStartedAt = nil
        saveSnapshot(current)
        
        // Close pending session in queue
        var pending = loadPendingSessions()
        if var last = pending.last(where: { $0.endedAt == nil }) {
            last.endedAt = Date()
            last.actualMinutes = max(1, elapsed)
            if let idx = pending.firstIndex(where: { $0.id == last.id }) {
                pending[idx] = last
            }
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
