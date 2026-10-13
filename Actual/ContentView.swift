import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Session.createdAt, order: .forward) private var sessions: [Session]
    
    @State private var calibrationScore: Double = 0.5
    @Bindable private var timeStore = TimeOSStore.shared
    
    var isRunning: Bool {
        sessions.contains(where: { $0.isRunning }) || timeStore.timerIsRunning || timeStore.chronoIsRunning
    }
    
    var body: some View {
        TabView(selection: $timeStore.selectedMainTab) {
            FocusInstrumentView(sessions: sessions)
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
                .tag(0)
            
            AlarmsInstrumentView()
                .tabItem {
                    Label("Alarms", systemImage: "bell.badge.fill")
                }
                .tag(1)
            
            StopwatchInstrumentView()
                .tabItem {
                    Label("Stopwatch", systemImage: "stopwatch.fill")
                }
                .tag(2)
            
            WorldClockInstrumentView()
                .tabItem {
                    Label("World", systemImage: "globe")
                }
                .tag(3)
            
            LogbookInstrumentView(sessions: sessions, calibrationScore: calibrationScore)
                .tabItem {
                    Label("Logbook", systemImage: "chart.bar.doc.horizontal.fill")
                }
                .tag(4)
        }
        .tint(TempoMascotPalette.orange)
        .onOpenURL { url in
            if url.scheme == "tempo" || url.scheme == "actual" {
                if url.host == "timers" || url.host == "timer" || url.host == "focus" || url.host == "log" || url.host == "chat" {
                    timeStore.selectedMainTab = 0
                } else if url.host == "alarms" || url.host == "alarm" {
                    timeStore.selectedMainTab = 1
                } else if url.host == "chrono" || url.host == "stopwatch" {
                    timeStore.selectedMainTab = 2
                } else if url.host == "world" {
                    timeStore.selectedMainTab = 3
                } else if url.host == "history" || url.host == "insights" || url.host == "profile" || url.host == "logbook" {
                    timeStore.selectedMainTab = 4
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
