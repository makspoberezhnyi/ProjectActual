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
        
        let todaySessions = sessions.filter {
            guard let start = $0.startedAt else { return false }
            return Calendar.current.isDateInToday(start)
        }
        let todayMins = todaySessions.compactMap { $0.actualMinutes ?? $0.estimatedMinutes }.reduce(0, +)
        let doneCount = todaySessions.filter { $0.endedAt != nil }.count
        let runningSession = sessions.last(where: { $0.isRunning })
        
        let snapshot = WidgetSnapshotData(
            isRunning: runningSession != nil,
            activeTaskTitle: runningSession?.rawText,
            activeTaskEstimatedMinutes: runningSession?.estimatedMinutes,
            activeTaskStartedAt: runningSession?.startedAt,
            todayMinutes: todayMins,
            todayCompletedCount: doneCount,
            calibrationScore: score
        )
        WidgetDataStore.shared.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        
        if runningSession == nil {
            LiveActivityManager.shared.cancelAllLiveActivities()
        }
        
        RoutineEngine.shared.scheduleRoutineNotifications(sessions: sessions)
    }
}
