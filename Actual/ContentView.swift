import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Session.createdAt, order: .forward) private var sessions: [Session]
    
    @State private var calibrationScore: Double = 0.5
    @State private var selectedTab: Int = 0
    
    var isRunning: Bool {
        sessions.contains(where: { $0.isRunning })
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LogTabView(sessions: sessions, calibrationScore: $calibrationScore)
                .tabItem {
                    Label("Log", systemImage: "message.fill")
                }
                .tag(0)
            
            HistoryTabView(sessions: sessions)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)
            
            InsightsTabView(sessions: sessions, calibrationScore: calibrationScore)
                .tabItem {
                    Label("Insights", systemImage: "chart.pie.fill")
                }
                .tag(2)
        }
        .tint(.primary)
        .onOpenURL { url in
            if url.scheme == "tempo" || url.scheme == "actual" {
                if url.host == "calendar" || url.host == "schedule" || url.host == "reminders" {
                    selectedTab = 0
                    NotificationCenter.default.post(name: .checkScheduleNotification, object: nil)
                } else if url.host == "log" || url.host == "chat" {
                    selectedTab = 0
                } else if url.host == "history" {
                    selectedTab = 1
                } else if url.host == "insights" {
                    selectedTab = 2
                }
            }
        }
        .onAppear {
            updateCalibrationAndWidget()
        }
        .onChange(of: sessions) { _, _ in
            updateCalibrationAndWidget()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                updateCalibrationAndWidget()
                NotificationCenter.default.post(name: .syncWidgetSessionsNotification, object: nil)
            }
        }
    }
    
    private func updateCalibrationAndWidget() {
        let score = BiasEngine.calculateOverallCalibration(sessions: sessions)
        calibrationScore = score
        
        let storeSnapshot = WidgetDataStore.shared.loadSnapshot()
        
        let todaySessions = sessions.filter {
            guard let start = $0.startedAt else { return false }
            return Calendar.current.isDateInToday(start)
        }
        let todayMins = todaySessions.compactMap { $0.actualMinutes ?? $0.estimatedMinutes }.reduce(0, +)
        let doneCount = todaySessions.filter { $0.endedAt != nil }.count
        let runningSession = sessions.last(where: { $0.isRunning })
        
        // If WidgetDataStore explicitly marked the session as stopped, don't resurrect it
        let isActuallyRunning: Bool
        if let running = runningSession {
            let pending = WidgetDataStore.shared.loadPendingSessions()
            if let pendingItem = pending.first(where: { abs($0.startedAt.timeIntervalSince(running.startedAt ?? Date.distantPast)) < 2.0 }) {
                isActuallyRunning = pendingItem.endedAt == nil && storeSnapshot.isRunning
            } else {
                isActuallyRunning = storeSnapshot.isRunning
            }
        } else {
            isActuallyRunning = storeSnapshot.isRunning
        }
        
        let snapshot = WidgetSnapshotData(
            isRunning: isActuallyRunning,
            activeTaskTitle: isActuallyRunning ? (runningSession?.rawText ?? storeSnapshot.activeTaskTitle) : nil,
            activeTaskEstimatedMinutes: isActuallyRunning ? (runningSession?.estimatedMinutes ?? storeSnapshot.activeTaskEstimatedMinutes) : nil,
            activeTaskStartedAt: isActuallyRunning ? (runningSession?.startedAt ?? storeSnapshot.activeTaskStartedAt) : nil,
            todayMinutes: max(todayMins, storeSnapshot.todayMinutes),
            todayCompletedCount: max(doneCount, storeSnapshot.todayCompletedCount),
            calibrationScore: score
        )
        WidgetDataStore.shared.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        
        if !isActuallyRunning {
            LiveActivityManager.shared.cancelAllLiveActivities()
        }
        
        RoutineEngine.shared.scheduleRoutineNotifications(sessions: sessions)
    }
}
