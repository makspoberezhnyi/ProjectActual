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
            
            ProfileTabView(sessions: sessions, calibrationScore: calibrationScore)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(3)
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
                } else if url.host == "profile" {
                    selectedTab = 3
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
                NotificationCenter.default.post(name: .syncWidgetSessionsNotification, object: nil)
                updateCalibrationAndWidget()
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
        let pending = WidgetDataStore.shared.loadPendingSessions()
        let hasActivePending = pending.contains(where: { $0.endedAt == nil })
        
        let isActuallyRunning: Bool
        if let running = runningSession {
            if !storeSnapshot.isRunning && !hasActivePending {
                // Stopped from Watch, Widget, or notification
                running.endedAt = storeSnapshot.lastCompletedAt ?? Date()
                running.actualMinutes = storeSnapshot.lastCompletedMinutes ?? running.estimatedMinutes ?? 25
                try? context.save()
                isActuallyRunning = false
            } else if let pendingItem = pending.first(where: { abs($0.startedAt.timeIntervalSince(running.startedAt ?? Date.distantPast)) < 2.0 }) {
                isActuallyRunning = pendingItem.endedAt == nil
            } else {
                isActuallyRunning = storeSnapshot.isRunning
            }
        } else {
            isActuallyRunning = storeSnapshot.isRunning || hasActivePending
        }
        
        let snapshot = WidgetSnapshotData(
            isRunning: isActuallyRunning,
            activeTaskTitle: isActuallyRunning ? (runningSession?.rawText ?? storeSnapshot.activeTaskTitle) : nil,
            activeTaskEstimatedMinutes: isActuallyRunning ? (runningSession?.estimatedMinutes ?? storeSnapshot.activeTaskEstimatedMinutes) : nil,
            activeTaskStartedAt: isActuallyRunning ? (runningSession?.startedAt ?? storeSnapshot.activeTaskStartedAt) : nil,
            todayMinutes: max(todayMins, storeSnapshot.todayMinutes),
            todayCompletedCount: max(doneCount, storeSnapshot.todayCompletedCount),
            calibrationScore: score,
            lastCompletedAt: storeSnapshot.lastCompletedAt,
            lastCompletedMinutes: storeSnapshot.lastCompletedMinutes,
            lastCompletedTitle: storeSnapshot.lastCompletedTitle
        )
        WidgetDataStore.shared.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        
        // Sync full updated state to Apple Watch
        if isActuallyRunning {
            WatchConnectivityManager.shared.syncActiveSession(
                title: snapshot.activeTaskTitle ?? "Focus Session",
                estimatedMinutes: snapshot.activeTaskEstimatedMinutes ?? 25,
                startDate: snapshot.activeTaskStartedAt ?? Date()
            )
        } else {
            WatchConnectivityManager.shared.syncSessionStopped(actualMinutes: snapshot.lastCompletedMinutes ?? 0)
        }
        WatchConnectivityManager.shared.syncDailySnapshot(
            todayMinutes: snapshot.todayMinutes,
            completedCount: snapshot.todayCompletedCount,
            calibrationScore: score
        )
        
        RoutineEngine.shared.scheduleRoutineNotifications(sessions: sessions)
    }
}
