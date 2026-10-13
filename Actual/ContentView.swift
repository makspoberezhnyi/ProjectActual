import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Session.createdAt, order: .forward) private var sessions: [Session]
    
    @State private var calibrationScore: Double = 0.5
    @Bindable private var timeStore = TimeOSStore.shared
    
    private var isRingingPresented: Binding<Bool> {
        Binding(
            get: { timeStore.activeRingingAlarmID != nil || timeStore.timerAlertActive },
            set: { _ in }
        )
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
        .fullScreenCover(isPresented: isRingingPresented) {
            TempoRingingView()
        }
        .task {
            timeStore.modelContext = context
            timeStore.closeOrphanedSessions(context: context)
            timeStore.reconcileExternalSessions(context: context)
            await timeStore.refreshCalendarSuggestions()
            timeStore.greet(force: true)
            await TempoAlarmScheduler.shared.requestPermissions()
            TempoAlarmScheduler.shared.sync(timeStore.alarms)
        }
        // The watch and Live Activity buttons leave notes in the shared store; read them right away.
        .onReceive(NotificationCenter.default.publisher(for: .syncWidgetSessionsNotification)) { _ in
            timeStore.reconcileExternalSessions(context: context)
        }
        .onChange(of: timeStore.selectedMainTab) { _, tab in
            timeStore.greetTab(tab)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDestinationReached)) { _ in
            timeStore.commuteArrived(context: context)
        }
        .onOpenURL { url in
            if url.scheme == "tempo" || url.scheme == "actual" {
                if url.host == "timers" || url.host == "timer" || url.host == "focus" || url.host == "log" || url.host == "chat" || url.host == "today" {
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
                timeStore.reconcileExternalSessions(context: context)
                updateCalibrationAndWidget()
                Task {
                    await timeStore.refreshCalendarSuggestions()
                    // Says hi again only if you've been away a while.
                    timeStore.greet()
                }
                // Roll the notification fallback forward so the next two days are always covered.
                TempoAlarmScheduler.shared.sync(timeStore.alarms)
            } else if newPhase == .background {
                timeStore.persistRuntimeState()
            }
        }
    }
    
    /// Today's numbers and the calibration score come from the logbook only.
    /// Whether something is running is published by TimeOSStore through TempoFocusBridge.
    private func updateCalibrationAndWidget() {
        let score = BiasEngine.calculateOverallCalibration(sessions: sessions)
        calibrationScore = score
        
        let finishedToday = sessions.filter {
            $0.isActualTask && $0.endedAt != nil && Calendar.current.isDateInToday($0.startedAt ?? .distantPast)
        }
        var snapshot = WidgetDataStore.shared.loadSnapshot()
        snapshot.todayMinutes = finishedToday.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes ?? 0) }
        snapshot.todayCompletedCount = finishedToday.count
        snapshot.calibrationScore = score
        WidgetDataStore.shared.saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        
        if TempoFocusBridge.watchSyncEnabled {
            WatchConnectivityManager.shared.syncDailySnapshot(
                todayMinutes: snapshot.todayMinutes,
                completedCount: snapshot.todayCompletedCount,
                calibrationScore: score
            )
        }
        
        RoutineEngine.shared.scheduleRoutineNotifications(sessions: sessions)
    }
}
