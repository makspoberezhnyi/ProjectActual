import SwiftUI
import SwiftData
import CoreLocation
import WidgetKit

// MARK: - LOG TAB
struct LogTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var sessions: [Session]
    @Binding var calibrationScore: Double
    
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var showDateJump: Bool = false
    @State private var targetScrollId: String? = nil
    @State private var dismissedSuggestionIds: Set<String> = []
    @State private var expandedTravelSessionIds: Set<String> = []
    @State private var expandedScheduleItemIds: Set<String> = []
    @State private var expandedActiveSessionIds: Set<String> = []
    
    @Bindable private var eventKit = EventKitManager.shared
    @Bindable private var routineEngine = RoutineEngine.shared
    @Bindable private var travelManager = LocationTravelManager.shared
    
    var groupedSessions: [(Date, [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.timestamp)
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var isConfiguringTask: Bool {
        sessions.contains(where: {
            $0.startedAt == nil &&
            $0.estimatedMinutes == nil &&
            $0.endedAt == nil &&
            !($0.isScheduleQuery ?? false) &&
            !($0.isTravelQuery ?? false) &&
            !($0.isConversational ?? false)
        })
    }
    
    var isRunningSession: Bool {
        sessions.contains(where: { $0.isRunning })
    }
    
    private var currentPopupSuggestion: (id: String, title: String, minutes: Int, prompt: String)? {
        guard !isRunningSession && !isConfiguringTask && !isTyping else { return nil }
        
        let activeRoutines = routineEngine.getActiveSuggestions(sessions: sessions)
        if let top = activeRoutines.first(where: { !dismissedSuggestionIds.contains($0.id) }) {
            return (top.id, top.pattern.taskTitle, top.recommendedMinutes, top.promptMessage)
        }
        
        let patterns = routineEngine.minePatterns(from: sessions)
        if let topPattern = patterns.first(where: { p in
            !dismissedSuggestionIds.contains(p.id) &&
            !sessions.contains(where: {
                Calendar.current.isDateInToday($0.timestamp) &&
                $0.rawText.localizedCaseInsensitiveContains(p.taskTitle)
            })
        }) {
            return (topPattern.id, topPattern.taskTitle, topPattern.typicalMinutes, "Ready to focus on \(topPattern.taskTitle)?")
        }
        
        return nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                VStack(spacing: 0) {
                    // Floating Proactive Suggestion Popup Banner (Top Notification)
                    if let suggestion = currentPopupSuggestion {
                        suggestionPopupBanner(suggestion: suggestion)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 6)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 18) {
                                if sessions.isEmpty {
                                    aiBubble(text: "Ready when you are. Tell me what you're doing, or check your calendar & tasks.")
                                        .padding(.top, 24)
                                } else {
                                    let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.timestamp) }
                                    if todaySessions.isEmpty {
                                        aiBubble(text: "Welcome back. Tell me what you're doing, or check your calendar & tasks.")
                                            .padding(.top, 24)
                                    }
                                }
                                
                                ForEach(Array(groupedSessions.enumerated()), id: \.element.0) { index, group in
                                    let (day, dailySessions) = group
                                    let dayId = "day_\(Int(day.timeIntervalSince1970))"
                                    
                                    VStack(spacing: 12) {
                                        // Inter-Day Glass Border Divider
                                        if index > 0 {
                                            HStack(spacing: 12) {
                                                Rectangle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.clear, Color.primary.opacity(0.18), .clear],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .frame(height: 1)
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        
                                        glassChip(text: dayString(for: day))
                                            .padding(.vertical, 6)
                                            .id(dayId)
                                        
                                        ForEach(dailySessions) { session in
                                            sessionChatSequence(for: session)
                                                .id(session.id)
                                        }
                                    }
                                }
                                
                                if isTyping && !(sessions.last?.isScheduleQuery == true && sessions.last?.schedulePayload == nil) {
                                    typingBubble()
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                        .scrollIndicators(.hidden)
                        .defaultScrollAnchor(.bottom)
                        .onChange(of: sessions.count) { _, _ in
                            if let last = sessions.last {
                                withAnimation(AppMotion.messageScroll) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: sessions.last?.schedulePayload) { _, _ in
                            if let last = sessions.last {
                                withAnimation(AppMotion.messageScroll) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: isTyping) { _, isTypingNow in
                            if isTypingNow {
                                withAnimation(AppMotion.messageScroll) { proxy.scrollTo("typing", anchor: .bottom) }
                            } else if let last = sessions.last {
                                withAnimation(AppMotion.messageScroll) { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: targetScrollId) { _, target in
                            if let target {
                                withAnimation(AppMotion.messageScroll) {
                                    proxy.scrollTo(target, anchor: .top)
                                }
                                targetScrollId = nil
                            }
                        }
                    }
                    
                    // Floating Glass Input Area with Quick Calendar Action
                    inputArea
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("Tempo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showDateJump = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.8))
                    }
                }
            }
            .sheet(isPresented: $showDateJump) {
                DateJumpSheet(loggedDays: groupedSessions.map { $0.0 }) { selectedDate in
                    let cal = Calendar.current
                    let start = cal.startOfDay(for: selectedDate)
                    if let matched = groupedSessions.first(where: { cal.isDate($0.0, inSameDayAs: start) }) {
                        targetScrollId = "day_\(Int(matched.0.timeIntervalSince1970))"
                    } else if let closest = groupedSessions.min(by: { abs($0.0.timeIntervalSince(start)) < abs($1.0.timeIntervalSince(start)) }) {
                        targetScrollId = "day_\(Int(closest.0.timeIntervalSince1970))"
                    }
                }
            }
        }
        .onAppear {
            eventKit.requestAccessAndFetch()
            syncPendingWidgetSessions()
        }
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            syncPendingWidgetSessions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .checkScheduleNotification)) { _ in
            handleScheduleQuery(userText: "Check calendar & reminders")
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncWidgetSessionsNotification)) { _ in
            syncPendingWidgetSessions()
        }
        .onReceive(NotificationCenter.default.publisher(for: .finishSessionFromNotification)) { notif in
            let source = notif.userInfo?["source"] as? String
            let explicitActual = notif.userInfo?["actualMinutes"] as? Int
            let label = source != nil ? "Finished (\(source!))" : "Finished via Notification"
            if let targetId = notif.userInfo?["sessionId"] as? String,
               let targetSession = sessions.first(where: { $0.sessionIdentifier == targetId && $0.isRunning }) {
                stopSession(targetSession, endCommandText: label, explicitActualMinutes: explicitActual)
            } else if let runningSession = sessions.last(where: { $0.isRunning }) {
                stopSession(runningSession, endCommandText: label, explicitActualMinutes: explicitActual)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .extendSessionFromNotification)) { notif in
            let minutesToAdd = notif.userInfo?["minutes"] as? Int ?? 5
            let source = notif.userInfo?["source"] as? String
            let label = source != nil ? "+\(minutesToAdd)m (\(source!))" : "+\(minutesToAdd)m (via Notification)"
            if let targetId = notif.userInfo?["sessionId"] as? String,
               let targetSession = sessions.first(where: { $0.sessionIdentifier == targetId && $0.isRunning }) {
                extendRunningSession(targetSession, by: minutesToAdd, userCommandText: label)
            } else if let runningSession = sessions.last(where: { $0.isRunning }) {
                extendRunningSession(runningSession, by: minutesToAdd, userCommandText: label)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionDestinationReached)) { notif in
            let targetId = notif.userInfo?["sessionId"] as? String
            let destTitle = notif.userInfo?["destinationTitle"] as? String ?? "Destination"
            let label = "Arrived at \(destTitle)"
            if let targetId, let targetSession = sessions.first(where: { $0.sessionIdentifier == targetId && $0.isRunning }) {
                stopSession(targetSession, endCommandText: label)
                TactileFeedback.success()
                withAnimation(AppMotion.messageAIPop) {
                    targetSession.tempoEndResponse = "🎯 You arrived at \(destTitle)! Commute session completed and logged."
                }
            } else if let runningSession = sessions.last(where: { $0.isRunning }) {
                stopSession(runningSession, endCommandText: label)
                TactileFeedback.success()
                withAnimation(AppMotion.messageAIPop) {
                    runningSession.tempoEndResponse = "🎯 You arrived at \(destTitle)! Commute session completed and logged."
                }
            }
        }
    }
    
    private func syncPendingWidgetSessions() {
        let pending = WidgetDataStore.shared.loadPendingSessions()
        guard !pending.isEmpty else { return }
        var remainingPending: [PendingSessionData] = []
        var didModify = false
        
        for item in pending {
            if let existing = sessions.first(where: {
                guard let start = $0.startedAt else { return false }
                return abs(start.timeIntervalSince(item.startedAt)) < 2.0
            }) {
                if let ended = item.endedAt, existing.endedAt == nil {
                    existing.endedAt = ended
                    existing.actualMinutes = item.actualMinutes
                    LiveActivityManager.shared.endLiveActivity(actualMinutes: item.actualMinutes ?? 0)
                    NotificationManager.shared.cancelTimerNotification(sessionId: existing.sessionIdentifier)
                    var syncNote = ""
                    if let eventId = existing.linkedEventIdentifier ?? item.linkedEventIdentifier {
                        let actual = item.actualMinutes ?? max(1, Int(ended.timeIntervalSince(existing.startedAt ?? item.startedAt) / 60))
                        if existing.isLinkedToCalendar == true || item.isLinkedToCalendar == true {
                            let start = existing.startedAt ?? item.startedAt
                            Task {
                                _ = await eventKit.updateCalendarEvent(identifier: eventId, start: start, end: ended, actualMinutes: actual)
                            }
                            syncNote = " (Updated Calendar)"
                        } else if existing.isLinkedToReminders == true || item.isLinkedToReminders == true {
                            Task {
                                _ = await eventKit.completeReminder(identifier: eventId)
                            }
                            syncNote = " (Completed in Reminders)"
                        }
                    }
                    let ratioText = existing.biasRatio != nil ? String(format: "%.1fx", existing.biasRatio!) : "-"
                    existing.tempoEndResponse = "Done. Logged \(item.actualMinutes ?? 0)m.\(syncNote) (Ratio: \(ratioText))"
                    didModify = true
                } else if existing.isRunning && item.endedAt == nil {
                    if existing.estimatedMinutes != item.estimatedMinutes {
                        existing.estimatedMinutes = item.estimatedMinutes
                        didModify = true
                    }
                    // Still running, keep in pending so widget stop can find it
                    remainingPending.append(item)
                }
            } else {
                let session = Session(
                    rawText: item.rawText,
                    estimatedMinutes: item.estimatedMinutes,
                    startedAt: item.startedAt,
                    tempoResponse: "Timer started. Focus.",
                    linkedEventIdentifier: item.linkedEventIdentifier,
                    isLinkedToCalendar: item.isLinkedToCalendar,
                    isLinkedToReminders: item.isLinkedToReminders,
                    createdAt: item.startedAt
                )
                session.endedAt = item.endedAt
                session.actualMinutes = item.actualMinutes
                if let ended = item.endedAt {
                    LiveActivityManager.shared.endLiveActivity(actualMinutes: item.actualMinutes ?? 0)
                    NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
                    var syncNote = ""
                    if let eventId = item.linkedEventIdentifier {
                        let actual = item.actualMinutes ?? max(1, Int(ended.timeIntervalSince(item.startedAt) / 60))
                        if item.isLinkedToCalendar == true {
                            Task {
                                _ = await eventKit.updateCalendarEvent(identifier: eventId, start: item.startedAt, end: ended, actualMinutes: actual)
                            }
                            syncNote = " (Updated Calendar)"
                        } else if item.isLinkedToReminders == true {
                            Task {
                                _ = await eventKit.completeReminder(identifier: eventId)
                            }
                            syncNote = " (Completed in Reminders)"
                        }
                    }
                    session.tempoEndResponse = "Done. Logged \(item.actualMinutes ?? 0)m.\(syncNote)"
                } else {
                    finalizeActiveRunningSessions(except: session, endedAt: item.startedAt)
                    NotificationManager.shared.scheduleTimerCompletion(title: session.rawText, durationMinutes: session.estimatedMinutes ?? 25, sessionId: session.sessionIdentifier)
                    remainingPending.append(item)
                }
                context.insert(session)
                didModify = true
            }
        }
        
        if didModify {
            try? context.save()
        }
        
        if remainingPending.count != pending.count {
            WidgetDataStore.shared.savePendingSessions(remainingPending)
        }
    }
    
    private func dayString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return TempoFormatters.dayHeaderFormatter.string(from: date)
    }
    
    // MARK: - Proactive Suggestion Popup Banner
    @ViewBuilder
    private func suggestionPopupBanner(suggestion: (id: String, title: String, minutes: Int, prompt: String)) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.indigo.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Circle().strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.8))
                
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("SUGGESTED TASK")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.blue)
                        .tracking(0.5)
                }
                
                Text(suggestion.prompt)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dismissedSuggestionIds.insert(suggestion.id)
                    startRoutineSession(taskTitle: suggestion.title, minutes: suggestion.minutes)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    Text("\(suggestion.minutes)m")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.blue, in: Capsule())
            }
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    dismissedSuggestionIds.insert(suggestion.id)
                    routineEngine.dismiss(suggestionId: suggestion.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.45))
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 10, x: 0, y: 4)
    }
    
    private var inputArea: some View {
        HStack(spacing: 8) {
            // Quick Action: Check Calendar & Reminders
            Button {
                handleScheduleQuery(userText: "Check calendar & reminders", target: .both)
            } label: {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
            }
            .pressable(scale: 0.92)
            
            TextField("What are you doing?", text: $inputText)
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
                .foregroundStyle(.primary)
                .onSubmit { submit() }
            
            if !inputText.isEmpty {
                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue, in: Circle())
                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .pressable(scale: 0.90)
                .transition(.asymmetric(
                    insertion: .scale(scale: AppMotion.scaleCard).combined(with: .opacity).animation(AppMotion.pop),
                    removal: .scale(scale: 0.90).combined(with: .opacity).animation(AppMotion.exit)
                ))
            }
        }
        .animation(AppMotion.snappy, value: inputText.isEmpty)
    }
    
    private func finalizeActiveRunningSessions(except currentSession: Session? = nil, endedAt: Date = Date()) {
        let running = sessions.filter { $0.isRunning && $0.persistentModelID != currentSession?.persistentModelID }
        for prior in running {
            prior.endedAt = endedAt
            let actual = max(1, Int(endedAt.timeIntervalSince(prior.startedAt ?? endedAt) / 60))
            prior.actualMinutes = actual
            let ratioText = prior.biasRatio != nil ? String(format: "%.1fx", prior.biasRatio!) : "-"
            prior.tempoEndResponse = "Done. Logged \(actual)m. (Ratio: \(ratioText))"
            
            if let eventId = prior.linkedEventIdentifier {
                if prior.isLinkedToCalendar == true {
                    let start = prior.startedAt ?? endedAt.addingTimeInterval(-Double(actual * 60))
                    Task {
                        _ = await eventKit.updateCalendarEvent(identifier: eventId, start: start, end: endedAt, actualMinutes: actual)
                    }
                } else if prior.isLinkedToReminders == true {
                    Task {
                        _ = await eventKit.completeReminder(identifier: eventId)
                    }
                }
            }
        }
    }
    
    private func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let savedText = trimmed
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()
        
        inputText = ""
        
        withAnimation(AppMotion.messageFly) {
            processSubmittedText(savedText)
        }
    }
    
    private func processSubmittedText(_ savedText: String) {
        // If there is an active session awaiting an estimate, check if input is a duration
        if let pendingSession = sessions.last(where: {
            $0.startedAt == nil &&
            $0.estimatedMinutes == nil &&
            $0.endedAt == nil &&
            !($0.isScheduleQuery ?? false) &&
            !($0.isTravelQuery ?? false) &&
            !($0.isConversational ?? false)
        }) {
            if ChatParser.isDurationOnly(savedText), let mins = ChatParser.extractMinutes(from: savedText) {
                setEstimate(mins, for: pendingSession)
                return
            } else if let mins = ChatParser.extractMinutes(from: savedText), !savedText.contains(" ") {
                setEstimate(mins, for: pendingSession)
                return
            } else {
                // User entered a new activity name instead of a duration; remove the incomplete pending entry
                context.delete(pendingSession)
            }
        }
        
        let intent = ChatParser.parse(savedText, sessions: sessions)
        
        // If a session is already running and user sends a pure duration (e.g. "10m", "45 min"), adjust target directly
        if !intent.isExtendCommand && !intent.isStopCommand && !intent.isScheduleCheck && !intent.isTravelQuery && !intent.isConversational {
            if let runningSession = sessions.last(where: { $0.isRunning }), ChatParser.isDurationOnly(savedText), let newMins = ChatParser.extractMinutes(from: savedText) {
                adjustRunningSessionTarget(runningSession, to: newMins, userCommandText: savedText)
                return
            }
        }
        
        // 1. Conversational Chat & Small Talk
        if intent.isConversational, let reply = intent.conversationalReply {
            let session = Session(
                rawText: savedText,
                startedAt: nil,
                tempoResponse: nil,
                isConversational: true,
                createdAt: Date()
            )
            context.insert(session)
            try? context.save()
            
            withAnimation(AppMotion.messageFly) {
                isTyping = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
                arrivalHaptic.impactOccurred()
                withAnimation(AppMotion.messageAIPop) {
                    session.tempoResponse = reply
                    self.isTyping = false
                }
                try? context.save()
            }
            return
        }
        
        // 2. Travel & Ride ETA Queries
        if intent.isTravelQuery {
            handleTravelQuery(
                userText: savedText,
                destination: intent.destinationQuery,
                isNextMeeting: intent.isNextMeetingTravel,
                transportMode: intent.travelTransportMode
            )
            return
        }
        
        // 3. Calendar & Reminders Schedule Queries
        if intent.isScheduleCheck {
            handleScheduleQuery(userText: savedText, target: intent.integrationTarget ?? .both)
            return
        }
        
        if intent.isSuggestionRequest {
            handleScheduleQuery(userText: savedText, target: intent.integrationTarget ?? .both)
            return
        }
        
        // 4. Extend / Add Time Command
        if intent.isExtendCommand, let extendMins = intent.extendMinutes {
            if let runningSession = sessions.last(where: { $0.isRunning }) {
                extendRunningSession(runningSession, by: extendMins, userCommandText: savedText)
            } else {
                let session = Session(
                    rawText: savedText,
                    startedAt: nil,
                    tempoResponse: nil,
                    isConversational: true,
                    createdAt: Date()
                )
                context.insert(session)
                try? context.save()
                
                withAnimation(AppMotion.messageFly) {
                    isTyping = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
                    arrivalHaptic.impactOccurred()
                    withAnimation(AppMotion.messageAIPop) {
                        session.tempoResponse = "No active session is currently running. You can start one with e.g. '25m Focus'."
                        self.isTyping = false
                    }
                    try? context.save()
                }
            }
            return
        }
        
        // 5. Stop Command
        if intent.isStopCommand {
            if let runningSession = sessions.last(where: { $0.isRunning }) {
                stopSession(runningSession, endCommandText: savedText)
            } else {
                let session = Session(
                    rawText: savedText,
                    startedAt: nil,
                    tempoResponse: nil,
                    isConversational: true,
                    createdAt: Date()
                )
                context.insert(session)
                try? context.save()
                
                withAnimation(AppMotion.messageFly) {
                    isTyping = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(650))
                    let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
                    arrivalHaptic.impactOccurred()
                    withAnimation(AppMotion.messageAIPop) {
                        session.tempoResponse = "No active session is currently running."
                        self.isTyping = false
                    }
                    try? context.save()
                }
            }
            return
        }
        
        // If task started with no time, ask how long it will take
        if intent.estimatedMinutes == nil && !intent.isRetroactive {
            let session = Session(
                rawText: intent.text,
                estimatedMinutes: nil,
                startedAt: nil,
                tempoResponse: nil,
                isConversational: false,
                createdAt: Date()
            )
            context.insert(session)
            try? context.save()
            
            withAnimation(AppMotion.messageFly) {
                isTyping = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
                arrivalHaptic.impactOccurred()
                withAnimation(AppMotion.messageAIPop) {
                    session.tempoResponse = "How long do you expect this to take?"
                    self.isTyping = false
                }
                try? context.save()
            }
            return
        }
        
        let mins = intent.estimatedMinutes ?? 25
        
        let session = Session(
            rawText: intent.text,
            estimatedMinutes: intent.estimatedMinutes,
            startedAt: intent.isRetroactive ? Date().addingTimeInterval(-Double(mins) * 60) : Date(),
            tempoResponse: nil,
            isRetroactive: intent.isRetroactive,
            isConversational: false,
            createdAt: Date()
        )
        
        context.insert(session)
        try? context.save()
        
        if !(intent.isRetroactive) {
            finalizeActiveRunningSessions(except: session, endedAt: session.startedAt ?? Date())
            LiveActivityManager.shared.startLiveActivity(
                taskTitle: intent.text,
                estimatedMinutes: mins,
                startDate: session.startedAt ?? Date()
            )
            WatchConnectivityManager.shared.syncActiveSession(
                title: intent.text,
                estimatedMinutes: mins,
                startDate: session.startedAt ?? Date()
            )
            NotificationManager.shared.scheduleTimerCompletion(
                title: intent.text,
                durationMinutes: mins,
                sessionId: session.sessionIdentifier
            )
        }
        
        withAnimation(AppMotion.messageFly) {
            isTyping = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                if intent.isRetroactive {
                    session.endedAt = Date()
                    session.actualMinutes = mins
                    let actual = mins
                    let ratioText = session.biasRatio != nil ? String(format: "%.1fx", session.biasRatio!) : "-"
                    session.tempoResponse = "Got it."
                    session.tempoEndResponse = "Logged \(actual)m. (Ratio: \(ratioText))"
                } else {
                    session.tempoResponse = "Timer started. Focus."
                }
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    private func handleTravelQuery(userText: String, destination: String?, isNextMeeting: Bool, transportMode: TravelTransportMode? = nil) {
        let mapsEnabled = UserDefaults.standard.object(forKey: "integration_maps_enabled") as? Bool ?? true
        let chosenMode = transportMode ?? .driving
        let session = Session(
            rawText: userText,
            isTravelQuery: true,
            createdAt: Date()
        )
        context.insert(session)
        
        if !mapsEnabled {
            session.tempoResponse = "Apple Maps integration is turned off in Settings."
            session.endedAt = Date()
            try? context.save()
            return
        }
        
        isTyping = true
        
        Task {
            if isNextMeeting {
                if let (item, travel) = await eventKit.nextUpcomingItemWithLocation(mode: chosenMode) {
                    let encoder = JSONEncoder()
                    if let data = try? encoder.encode(travel), let jsonStr = String(data: data, encoding: .utf8) {
                        await MainActor.run {
                            session.travelPayload = jsonStr
                            let iconEmoji: String
                            switch travel.transportMode {
                            case .driving: iconEmoji = "🚗"
                            case .transit: iconEmoji = "🚆"
                            case .walking: iconEmoji = "🚶"
                            case .cycling: iconEmoji = "🚴"
                            }
                            session.tempoResponse = "\(iconEmoji) The \(travel.transportMode.displayName.lowercased()) to \(item.title) will take approximately \(travel.formattedDuration) (\(travel.distanceString))."
                            self.isTyping = false
                            try? context.save()
                        }
                        return
                    }
                }
            }
            
            let dest = destination ?? "Airport"
            if let travel = await LocationTravelManager.shared.calculateTravel(to: dest, mode: chosenMode) {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(travel), let jsonStr = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        session.travelPayload = jsonStr
                        let iconEmoji: String
                        switch travel.transportMode {
                        case .driving: iconEmoji = "🚗"
                        case .transit: iconEmoji = "🚆"
                        case .walking: iconEmoji = "🚶"
                        case .cycling: iconEmoji = "🚴"
                        }
                        session.tempoResponse = "\(iconEmoji) The \(travel.transportMode.displayName.lowercased()) to \(travel.destinationTitle) will take approximately \(travel.formattedDuration) (\(travel.distanceString))."
                        self.isTyping = false
                        try? context.save()
                    }
                    return
                }
            }
            
            await MainActor.run {
                session.tempoResponse = "Could not calculate route to '\(dest)'. Please verify location services."
                self.isTyping = false
            }
        }
    }
    
    private func recalculateTravel(session: Session, newMode: TravelTransportMode) {
        guard let currentResult = session.travelResult else { return }
        if currentResult.transportMode == newMode { return }
        
        // Immediate optimistic UI update with realistic distance-aware fallback
        let existingDist = currentResult.distanceMeters > 0 ? currentResult.distanceMeters : nil
        let estimated = LocationTravelManager.shared.estimateFallbackResult(for: currentResult.destinationTitle, knownDistanceMeters: existingDist, mode: newMode)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(estimated), let jsonStr = String(data: data, encoding: .utf8) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                session.travelPayload = jsonStr
            }
        }
        
        Task {
            let updated: TravelAssessmentResult?
            if let lat = currentResult.latitude, let lon = currentResult.longitude {
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                updated = await LocationTravelManager.shared.calculateTravel(coordinate: coord, title: currentResult.destinationTitle, mode: newMode)
            } else {
                updated = await LocationTravelManager.shared.calculateTravel(to: currentResult.destinationTitle, mode: newMode)
            }
            
            if let result = updated {
                if let data = try? encoder.encode(result), let jsonStr = String(data: data, encoding: .utf8) {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            session.travelPayload = jsonStr
                            let iconEmoji: String
                            switch result.transportMode {
                            case .driving: iconEmoji = "🚗"
                            case .transit: iconEmoji = "🚆"
                            case .walking: iconEmoji = "🚶"
                            case .cycling: iconEmoji = "🚴"
                            }
                            session.tempoResponse = "\(iconEmoji) The \(result.transportMode.displayName.lowercased()) to \(result.destinationTitle) will take approximately \(result.formattedDuration) (\(result.distanceString))."
                            try? context.save()
                        }
                    }
                }
            }
        }
    }
    
    private func startCommuteFocus(
        title: String,
        minutes: Int,
        mode: TravelTransportMode = .driving,
        destLat: Double? = nil,
        destLon: Double? = nil,
        destName: String? = nil,
        trackArrival: Bool = true
    ) {
        let hasCoords = destLat != nil && destLon != nil
        let trackSuffix = (trackArrival && hasCoords) ? " Live arrival tracking active." : ""
        let responseMsg: String
        switch mode {
        case .driving:
            responseMsg = "🚗 Commute timer started. Drive safely!\(trackSuffix)"
        case .transit:
            responseMsg = "🚆 Transit commute timer started. Have a good ride!\(trackSuffix)"
        case .walking:
            responseMsg = "🚶 Walking timer started. Enjoy your walk!\(trackSuffix)"
        case .cycling:
            responseMsg = "🚴 Cycling timer started. Ride safely!\(trackSuffix)"
        }
        
        let radius: Double = (mode == .driving || mode == .transit) ? 120.0 : 70.0
        let session = Session(
            rawText: title,
            estimatedMinutes: minutes,
            startedAt: Date(),
            tempoResponse: responseMsg,
            integrationSource: "maps",
            createdAt: Date(),
            destinationLatitude: destLat,
            destinationLongitude: destLon,
            destinationTitle: destName ?? title,
            destinationRadiusMeters: radius,
            isArrivalTrackingActive: trackArrival && hasCoords
        )
        context.insert(session)
        finalizeActiveRunningSessions(except: session, endedAt: session.startedAt ?? Date())
        try? context.save()
        
        if trackArrival, let lat = destLat, let lon = destLon {
            LocationTravelManager.shared.startMonitoringArrival(
                sessionId: session.sessionIdentifier,
                title: destName ?? title,
                latitude: lat,
                longitude: lon,
                radius: radius
            )
        }
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: title,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        WatchConnectivityManager.shared.syncActiveSession(
            title: title,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        NotificationManager.shared.scheduleTimerCompletion(
            title: title,
            durationMinutes: minutes,
            sessionId: session.sessionIdentifier
        )
    }
    
    private func adjustRunningSessionTarget(_ session: Session, to newMinutes: Int, userCommandText: String) {
        let oldEst = session.estimatedMinutes ?? 25
        session.estimatedMinutes = newMinutes
        
        // Update Live Activity & Widget Store
        LiveActivityManager.shared.updateLiveActivity(estimatedMinutes: newMinutes, statusMessage: "\(newMinutes)m")
        WatchConnectivityManager.shared.syncActiveSession(
            title: session.rawText,
            estimatedMinutes: newMinutes,
            startDate: session.startedAt ?? Date()
        )
        
        // Reschedule local notification
        let remainingMinutes: Int
        if let start = session.startedAt {
            let elapsedMins = max(0, Int(Date().timeIntervalSince(start) / 60))
            remainingMinutes = max(1, newMinutes - elapsedMins)
        } else {
            remainingMinutes = newMinutes
        }
        NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
        NotificationManager.shared.scheduleTimerCompletion(
            title: session.rawText,
            durationMinutes: remainingMinutes,
            sessionId: session.sessionIdentifier
        )
        
        let bubble = Session(
            rawText: userCommandText,
            startedAt: nil,
            tempoResponse: nil,
            isConversational: true,
            createdAt: Date()
        )
        context.insert(bubble)
        try? context.save()
        
        withAnimation(AppMotion.messageFly) {
            isTyping = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .medium)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                bubble.tempoResponse = "Target updated to \(newMinutes)m (was \(oldEst)m)."
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    private func extendRunningSession(_ session: Session, by minutesToAdd: Int, userCommandText: String? = nil) {
        let oldEst = session.estimatedMinutes ?? 25
        let newEst = oldEst + minutesToAdd
        session.estimatedMinutes = newEst
        
        // Update Live Activity & Widget snapshot
        LiveActivityManager.shared.updateLiveActivity(estimatedMinutes: newEst, statusMessage: "+\(minutesToAdd)m")
        WatchConnectivityManager.shared.syncActiveSession(
            title: session.rawText,
            estimatedMinutes: newEst,
            startDate: session.startedAt ?? Date()
        )
        
        // Reschedule local notification
        let remainingMinutes: Int
        if let start = session.startedAt {
            let elapsedMins = max(0, Int(Date().timeIntervalSince(start) / 60))
            remainingMinutes = max(1, newEst - elapsedMins)
        } else {
            remainingMinutes = newEst
        }
        NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
        NotificationManager.shared.scheduleTimerCompletion(
            title: session.rawText,
            durationMinutes: remainingMinutes,
            sessionId: session.sessionIdentifier
        )
        
        let commandText = userCommandText ?? "+\(minutesToAdd)m"
        let bubble = Session(
            rawText: commandText,
            startedAt: nil,
            tempoResponse: nil,
            isConversational: true,
            createdAt: Date()
        )
        context.insert(bubble)
        try? context.save()
        
        withAnimation(AppMotion.messageFly) {
            isTyping = true
        }
        
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .medium)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                bubble.tempoResponse = "Added +\(minutesToAdd)m to your timer (\(oldEst)m → \(newEst)m total)."
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    private func stopSession(_ session: Session, endCommandText: String, explicitActualMinutes: Int? = nil) {
        if LocationTravelManager.shared.activeArrivalTarget?.sessionId == session.sessionIdentifier {
            LocationTravelManager.shared.stopMonitoringArrival()
        }
        session.endedAt = Date()
        let actual = explicitActualMinutes ?? max(1, Int(Date().timeIntervalSince(session.startedAt ?? Date()) / 60))
        session.actualMinutes = actual
        session.endCommandText = endCommandText
        
        LiveActivityManager.shared.endLiveActivity(actualMinutes: actual)
        WatchConnectivityManager.shared.syncSessionStopped(actualMinutes: actual)
        WidgetDataStore.shared.stopActiveSession(actualMinutes: actual)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
        
        // Bidirectional sync with Apple Calendar or Reminders
        var syncNote = ""
        if let eventId = session.linkedEventIdentifier {
            if session.isLinkedToCalendar == true {
                let start = session.startedAt ?? Date().addingTimeInterval(-Double(actual * 60))
                let end = session.endedAt ?? Date()
                Task {
                    _ = await eventKit.updateCalendarEvent(identifier: eventId, start: start, end: end, actualMinutes: actual)
                }
                syncNote = " (Updated Calendar)"
            } else if session.isLinkedToReminders == true {
                Task {
                    _ = await eventKit.completeReminder(identifier: eventId)
                }
                syncNote = " (Completed in Reminders)"
            }
        }
        
        let ratioText = session.biasRatio != nil ? String(format: "%.1fx", session.biasRatio!) : "-"
        session.tempoEndResponse = "Done. Logged \(actual)m.\(syncNote) (Ratio: \(ratioText))"
        self.isTyping = false
        try? context.save()
    }
    
    private func handleScheduleQuery(userText: String = "Check calendar & reminders", target: IntegrationTarget = .both) {
        let calendarEnabled = UserDefaults.standard.object(forKey: "integration_calendar_enabled") as? Bool ?? true
        let remindersEnabled = UserDefaults.standard.object(forKey: "integration_reminders_enabled") as? Bool ?? true
        
        let querySession = Session(
            rawText: userText,
            estimatedMinutes: nil,
            startedAt: nil,
            tempoResponse: nil,
            isScheduleQuery: true,
            createdAt: Date()
        )
        querySession.integrationSource = target.rawValue
        context.insert(querySession)
        
        if target == .calendar && !calendarEnabled {
            querySession.tempoResponse = "Apple Calendar integration is turned off in Settings."
            querySession.endedAt = Date()
            try? context.save()
            return
        }
        if target == .reminders && !remindersEnabled {
            querySession.tempoResponse = "Apple Reminders integration is turned off in Settings."
            querySession.endedAt = Date()
            try? context.save()
            return
        }
        if target == .both && !calendarEnabled && !remindersEnabled {
            querySession.tempoResponse = "Both Apple Calendar and Reminders integrations are turned off in Settings."
            querySession.endedAt = Date()
            try? context.save()
            return
        }
        
        try? context.save()
        isTyping = true
        
        Task {
            let items = await eventKit.fetchItems(for: target)
            let encodedData = try? JSONEncoder().encode(items)
            let jsonString = encodedData != nil ? String(data: encodedData!, encoding: .utf8) : nil
            
            // Brief natural pause
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                querySession.schedulePayload = jsonString
                let calCount = items.filter { $0.isCalendarEvent }.count
                let remCount = items.filter { !$0.isCalendarEvent }.count
                
                switch target {
                case .calendar:
                    if calCount > 0 {
                        querySession.tempoResponse = "Found \(calCount) event\(calCount == 1 ? "" : "s") in Apple Calendar for today:"
                    } else {
                        querySession.tempoResponse = "No upcoming events scheduled in Apple Calendar for today."
                    }
                case .reminders:
                    if remCount > 0 {
                        querySession.tempoResponse = "Found \(remCount) pending task\(remCount == 1 ? "" : "s") in Apple Reminders:"
                    } else {
                        querySession.tempoResponse = "No pending tasks found in Apple Reminders."
                    }
                case .both:
                    if calCount > 0 && remCount > 0 {
                        querySession.tempoResponse = "Here are your upcoming calendar events and reminders for today:"
                    } else if calCount > 0 {
                        querySession.tempoResponse = "Found \(calCount) event\(calCount == 1 ? "" : "s") in Apple Calendar:"
                    } else if remCount > 0 {
                        querySession.tempoResponse = "Found \(remCount) task\(remCount == 1 ? "" : "s") in Apple Reminders:"
                    } else {
                        querySession.tempoResponse = "No scheduled events or reminders found for today."
                    }
                }
                
                querySession.endedAt = Date()
                isTyping = false
                try? context.save()
            }
        }
    }
    
    private func launchSessionFromSchedule(item: ScheduleItem) {
        let session = Session(
            rawText: item.title,
            estimatedMinutes: item.estimatedMinutes,
            startedAt: Date(),
            linkedEventIdentifier: item.id,
            isLinkedToCalendar: item.isCalendarEvent,
            isLinkedToReminders: !item.isCalendarEvent,
            createdAt: Date()
        )
        
        if let lat = item.latitude, let lon = item.longitude {
            session.destinationLatitude = lat
            session.destinationLongitude = lon
            session.destinationTitle = item.location ?? item.title
            session.destinationRadiusMeters = 80.0
            session.isArrivalTrackingActive = true
            LocationTravelManager.shared.startMonitoringArrival(
                sessionId: session.sessionIdentifier,
                title: item.location ?? item.title,
                latitude: lat,
                longitude: lon,
                radius: 80.0
            )
        }
        
        finalizeActiveRunningSessions(except: session, endedAt: session.startedAt ?? Date())
        context.insert(session)
        try? context.save()
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: item.title,
            estimatedMinutes: item.estimatedMinutes,
            startDate: session.startedAt ?? Date(),
            linkedEventIdentifier: item.id,
            isLinkedToCalendar: item.isCalendarEvent,
            isLinkedToReminders: !item.isCalendarEvent
        )
        WatchConnectivityManager.shared.syncActiveSession(
            title: item.title,
            estimatedMinutes: item.estimatedMinutes,
            startDate: session.startedAt ?? Date()
        )
        NotificationManager.shared.scheduleTimerCompletion(
            title: item.title,
            durationMinutes: item.estimatedMinutes,
            sessionId: session.sessionIdentifier
        )
        
        isTyping = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                session.tempoResponse = "Timer started for \(item.title). Focus."
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    private func removeItemFromScheduleQuery(querySession: Session, itemId: String) {
        var items = querySession.scheduleItems
        items.removeAll(where: { $0.id == itemId })
        if let encoded = try? JSONEncoder().encode(items) {
            querySession.schedulePayload = String(data: encoded, encoding: .utf8)
            try? context.save()
        }
    }
    
    private func startRoutineSession(taskTitle: String, minutes: Int) {
        let session = Session(
            rawText: "\(taskTitle) (\(minutes)m)",
            estimatedMinutes: minutes,
            startedAt: Date(),
            tempoResponse: nil,
            createdAt: Date()
        )
        finalizeActiveRunningSessions(except: session, endedAt: session.startedAt ?? Date())
        context.insert(session)
        try? context.save()
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: taskTitle,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        WatchConnectivityManager.shared.syncActiveSession(
            title: taskTitle,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        NotificationManager.shared.scheduleTimerCompletion(
            title: taskTitle,
            durationMinutes: minutes,
            sessionId: session.sessionIdentifier
        )
        
        isTyping = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                session.tempoResponse = "Timer started for \(taskTitle). Focus."
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    private func logRoutineRetroactively(taskTitle: String, minutes: Int) {
        let started = Date().addingTimeInterval(-Double(minutes) * 60)
        let session = Session(
            rawText: "\(taskTitle) (\(minutes)m)",
            estimatedMinutes: minutes,
            startedAt: started,
            tempoResponse: "Got it.",
            tempoEndResponse: "Logged \(taskTitle) (\(minutes)m) as completed.",
            isRetroactive: true,
            createdAt: Date()
        )
        session.endedAt = Date()
        session.actualMinutes = minutes
        context.insert(session)
        try? context.save()
    }
    
    private func setEstimate(_ minutes: Int, for session: Session) {
        finalizeActiveRunningSessions(except: session, endedAt: Date())
        session.estimatedMinutes = minutes
        session.startedAt = Date()
        session.tempoResponse = nil
        try? context.save()
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: session.rawText,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date(),
            linkedEventIdentifier: session.linkedEventIdentifier,
            isLinkedToCalendar: session.isLinkedToCalendar,
            isLinkedToReminders: session.isLinkedToReminders
        )
        WatchConnectivityManager.shared.syncActiveSession(
            title: session.rawText,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        NotificationManager.shared.scheduleTimerCompletion(
            title: session.rawText,
            durationMinutes: minutes,
            sessionId: session.sessionIdentifier
        )
        
        withAnimation(AppMotion.messageFly) {
            isTyping = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            let arrivalHaptic = UIImpactFeedbackGenerator(style: .light)
            arrivalHaptic.impactOccurred()
            withAnimation(AppMotion.messageAIPop) {
                session.tempoResponse = "Estimate set to \(minutes)m. Timer started. Focus."
                self.isTyping = false
            }
            try? context.save()
        }
    }
    
    @ViewBuilder
    private func glassChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.55))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
    }
    
    @ViewBuilder
    private func sessionChatSequence(for session: Session) -> some View {
        Group {
            if session.isScheduleQuery == true {
                scheduleQuerySequence(for: session)
            } else if session.isTravelQuery == true {
                travelQuerySequence(for: session)
            } else {
                standardSessionSequence(for: session)
            }
        }
    }
    
    @ViewBuilder
    private func travelQuerySequence(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            userBubble(text: session.rawText, est: nil)
                .contextMenu { Button("Delete", role: .destructive) { context.delete(session) } }
            
            if session.travelPayload == nil {
                // Live ETA calculation pill
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.brandCoral)
                    Text("Assessing traffic & ride ETA...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                    ProgressView()
                        .scaleEffect(0.65)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8))
                .padding(.leading, 2)
            } else if let travel = session.travelResult {
                travelAssessmentCard(result: travel, session: session)
            } else {
                aiBubble(text: session.tempoResponse ?? "Could not calculate route.")
            }
        }
    }
    
    @ViewBuilder
    private func travelAssessmentCard(result: TravelAssessmentResult, session: Session) -> some View {
        let isCollapsed = expandedTravelSessionIds.contains(session.sessionIdentifier)
        
        VStack(alignment: .leading, spacing: 12) {
            // Destination & Duration Header (Tappable for accordion expand/collapse)
            Button {
                withAnimation(AppMotion.cardExpand) {
                    if isCollapsed {
                        expandedTravelSessionIds.remove(session.sessionIdentifier)
                    } else {
                        expandedTravelSessionIds.insert(session.sessionIdentifier)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(transportModeColor(result.transportMode).opacity(0.18))
                            .frame(width: 36, height: 36)
                        Image(systemName: result.transportMode.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(transportModeColor(result.transportMode))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.destinationTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let addr = result.destinationAddress {
                            Text(addr)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.primary.opacity(0.55))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(result.formattedDuration)
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(transportModeColor(result.transportMode))
                        Text(result.distanceString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.55))
                    }
                    
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                }
            }
            .buttonStyle(.plain)
            
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 12) {
                    // Interactive Mode Selector Pills (Car, City Transport, By Feet, Bicycle)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(TravelTransportMode.allCases) { mode in
                                let isSelected = result.transportMode == mode
                                Button {
                                    recalculateTravel(session: session, newMode: mode)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: mode.iconName)
                                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                        Text(mode.displayName)
                                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                                    }
                                    .foregroundStyle(isSelected ? Color.white : .primary.opacity(0.75))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        isSelected ? transportModeColor(mode) : Color.primary.opacity(0.06),
                                        in: Capsule()
                                    )
                                    .shadow(color: isSelected ? transportModeColor(mode).opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
                                }
                                .pressable(scale: 0.95)
                            }
                        }
                    }
                    
                    // GPS Arrival Detection Badge
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.teal)
                        Text("GPS Arrival Tracking Ready")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.85))
                        Spacer()
                        Text("Auto-ends upon arrival")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    // Action Buttons
                    HStack(spacing: 8) {
                        Button {
                            startCommuteFocus(
                                title: "\(result.transportMode.actionTitle): \(result.destinationTitle)",
                                minutes: result.travelDurationMinutes,
                                mode: result.transportMode,
                                destLat: result.latitude,
                                destLon: result.longitude,
                                destName: result.destinationTitle,
                                trackArrival: true
                            )
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text("Start \(result.transportMode.actionTitle) (\(result.formattedDuration))")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(transportModeColor(result.transportMode), in: Capsule())
                            .shadow(color: transportModeColor(result.transportMode).opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .pressable(scale: 0.96)
                        
                        Button {
                            LocationTravelManager.shared.openInMaps(result: result)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 10))
                                Text("Apple Maps")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                        .pressable(scale: 0.96)
                    }
                }
                .transition(.cardExpandTransition)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, x: 0, y: 3)
        .padding(.trailing, 16)
        .contextMenu {
            Button("Delete", role: .destructive) { context.delete(session) }
        }
    }
    
    private func transportModeColor(_ mode: TravelTransportMode) -> Color {
        switch mode {
        case .driving: return Color.blue
        case .transit: return Color.teal
        case .walking: return Color.teal
        case .cycling: return Color.green
        }
    }
    

    
    @ViewBuilder
    private func scheduleQuerySequence(for session: Session) -> some View {
        let source = session.integrationSource ?? "both"
        let isCalOnly = source == "calendar"
        let isRemOnly = source == "reminders"
        
        VStack(alignment: .leading, spacing: 10) {
            userBubble(text: session.rawText, est: nil)
                .contextMenu { Button("Delete", role: .destructive) { context.delete(session) } }
            
            if session.schedulePayload == nil {
                // Small sleek loading state with REAL app icon
                HStack {
                    HStack(spacing: 8) {
                        if isCalOnly {
                            RealCalendarAppIcon(size: 16)
                            Text("Checking Apple Calendar...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.75))
                        } else if isRemOnly {
                            RealRemindersAppIcon(size: 16)
                            Text("Checking Apple Reminders...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.75))
                        } else {
                            RealUnifiedIntegrationIcon(size: 16)
                            Text("Checking Calendar & Reminders...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.75))
                        }
                        ProgressView()
                            .scaleEffect(0.65)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8))
                    .padding(.leading, 2)
                    
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                let items = session.scheduleItems
                if items.isEmpty {
                    // Clean single message with REAL app icon
                    HStack(spacing: 10) {
                        if isCalOnly {
                            RealCalendarAppIcon(size: 22)
                        } else if isRemOnly {
                            RealRemindersAppIcon(size: 22)
                        } else {
                            RealUnifiedIntegrationIcon(size: 22)
                        }
                        
                        Text(session.tempoResponse ?? "No scheduled items found.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.9))
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8)
                    )
                    .padding(.trailing, 24)
                } else {
                    // Header label with REAL app icon (compact chip)
                    HStack {
                        HStack(spacing: 6) {
                            if isCalOnly {
                                RealCalendarAppIcon(size: 16)
                                Text("Apple Calendar")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.85))
                            } else if isRemOnly {
                                RealRemindersAppIcon(size: 16)
                                Text("Apple Reminders")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.85))
                            } else {
                                RealUnifiedIntegrationIcon(size: 16)
                                Text("Calendar & Reminders")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.85))
                            }
                            
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.primary.opacity(0.35))
                            
                            Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Color.blue)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8))
                        .padding(.leading, 2)
                        
                        Spacer(minLength: 0)
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            let isExpanded = expandedScheduleItemIds.contains(item.id)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    if item.isCalendarEvent {
                                        RealCalendarAppIcon(size: 28)
                                    } else {
                                        RealRemindersAppIcon(size: 28)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 5) {
                                            if let time = item.timeString, !time.isEmpty {
                                                Text(time)
                                                    .font(.system(size: 11, weight: .regular))
                                                    .monospacedDigit()
                                                    .foregroundStyle(.primary.opacity(0.6))
                                                Text("•")
                                                    .font(.system(size: 9))
                                                    .foregroundStyle(.primary.opacity(0.3))
                                            }
                                            Text("\(item.estimatedMinutes)m Focus")
                                                .font(.system(size: 11, weight: .medium))
                                                .monospacedDigit()
                                                .foregroundStyle(item.isCalendarEvent ? Color.red.opacity(0.9) : Color.blue.opacity(0.9))
                                        }
                                        
                                        // Location & Travel ETA Info Badge
                                        if let loc = item.location, !loc.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.primary.opacity(0.5))
                                                Text(loc)
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundStyle(.primary.opacity(0.6))
                                                    .lineLimit(1)
                                                if let eta = item.travelEtaMinutes {
                                                    Text("• 🚗 \(eta)m drive")
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .monospacedDigit()
                                                        .foregroundStyle(Theme.brandCoral)
                                                }
                                            }
                                        }
                                    }
                                    
                                    Spacer(minLength: 8)
                                    
                                    Button {
                                        launchSessionFromSchedule(item: item)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 8))
                                            Text("Start")
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
                                    }
                                    .pressable(scale: 0.94)
                                }
                                
                                if isExpanded {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Divider().opacity(0.15)
                                        
                                        HStack(spacing: 8) {
                                            if let loc = item.location, !loc.isEmpty {
                                                Button {
                                                    let res = TravelAssessmentResult(
                                                        destinationTitle: item.title,
                                                        destinationAddress: loc,
                                                        travelDurationMinutes: item.travelEtaMinutes ?? 20,
                                                        distanceMeters: 0,
                                                        distanceString: item.travelDistanceString ?? "",
                                                        latitude: item.latitude,
                                                        longitude: item.longitude
                                                    )
                                                    LocationTravelManager.shared.openInMaps(result: res)
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "map.fill")
                                                            .font(.system(size: 9))
                                                        Text("Maps")
                                                            .font(.system(size: 11, weight: .medium))
                                                    }
                                                    .foregroundStyle(.primary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color.primary.opacity(0.08), in: Capsule())
                                                }
                                                .pressable(scale: 0.94)
                                            }
                                            
                                            if !item.isCalendarEvent {
                                                Button {
                                                    Task {
                                                        let ok = await eventKit.completeReminder(identifier: item.id)
                                                        if ok {
                                                            removeItemFromScheduleQuery(querySession: session, itemId: item.id)
                                                        }
                                                    }
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: "checkmark.circle")
                                                            .font(.system(size: 9))
                                                        Text("Complete")
                                                            .font(.system(size: 11, weight: .medium))
                                                    }
                                                    .foregroundStyle(Color.green)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 5)
                                                    .background(Color.green.opacity(0.12), in: Capsule())
                                                }
                                                .pressable(scale: 0.94)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(role: .destructive) {
                                                Task {
                                                    let ok = await eventKit.deleteItem(identifier: item.id, isCalendarEvent: item.isCalendarEvent)
                                                    if ok {
                                                        removeItemFromScheduleQuery(querySession: session, itemId: item.id)
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.red.opacity(0.8))
                                                    .padding(6)
                                            }
                                            .pressable(scale: 0.90)
                                        }
                                    }
                                    .transition(.cardExpandTransition)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .onTapGesture {
                                withAnimation(AppMotion.cardExpand) {
                                    if isExpanded {
                                        expandedScheduleItemIds.remove(item.id)
                                    } else {
                                        expandedScheduleItemIds.insert(item.id)
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    launchSessionFromSchedule(item: item)
                                } label: {
                                    Label("Start Focus", systemImage: "play.circle")
                                }
                                
                                if let loc = item.location, !loc.isEmpty {
                                    Button {
                                        let res = TravelAssessmentResult(
                                            destinationTitle: item.title,
                                            destinationAddress: loc,
                                            travelDurationMinutes: item.travelEtaMinutes ?? 20,
                                            distanceMeters: 0,
                                            distanceString: item.travelDistanceString ?? "",
                                            latitude: item.latitude,
                                            longitude: item.longitude
                                        )
                                        LocationTravelManager.shared.openInMaps(result: res)
                                    } label: {
                                        Label("Navigate in Apple Maps", systemImage: "map")
                                    }
                                }
                                
                                if !item.isCalendarEvent {
                                    Button {
                                        Task {
                                            let ok = await eventKit.completeReminder(identifier: item.id)
                                            if ok {
                                                removeItemFromScheduleQuery(querySession: session, itemId: item.id)
                                            }
                                        }
                                    } label: {
                                        Label("Mark Completed", systemImage: "checkmark.circle")
                                    }
                                }
                                
                                Button(role: .destructive) {
                                    Task {
                                        let ok = await eventKit.deleteItem(identifier: item.id, isCalendarEvent: item.isCalendarEvent)
                                        if ok {
                                            removeItemFromScheduleQuery(querySession: session, itemId: item.id)
                                        }
                                    }
                                } label: {
                                    Label(item.isCalendarEvent ? "Delete Event" : "Delete Reminder", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.trailing, 16)
                }
            }
        }
    }
    
    private func revertSession(_ session: Session) {
        if let eventId = session.linkedEventIdentifier {
            if session.isLinkedToReminders == true {
                Task {
                    _ = await eventKit.uncompleteReminder(identifier: eventId)
                }
            } else if session.isLinkedToCalendar == true {
                Task {
                    _ = await eventKit.revertCalendarEvent(identifier: eventId)
                }
            }
        }
        
        context.delete(session)
        try? context.save()
        LiveActivityManager.shared.cancelAllLiveActivities()
        NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
    }
    
    private func cancelRunningSession(_ session: Session) {
        if LocationTravelManager.shared.activeArrivalTarget?.sessionId == session.sessionIdentifier {
            LocationTravelManager.shared.stopMonitoringArrival()
        }
        if let eventId = session.linkedEventIdentifier {
            if session.isLinkedToReminders == true {
                Task {
                    _ = await eventKit.uncompleteReminder(identifier: eventId)
                }
            } else if session.isLinkedToCalendar == true {
                Task {
                    _ = await eventKit.revertCalendarEvent(identifier: eventId)
                }
            }
        }
        
        context.delete(session)
        try? context.save()
        LiveActivityManager.shared.cancelAllLiveActivities()
        NotificationManager.shared.cancelTimerNotification(sessionId: session.sessionIdentifier)
    }
    
    @ViewBuilder
    private func standardSessionSequence(for session: Session) -> some View {
        VStack(spacing: 8) {
            userBubble(text: session.rawText, est: session.estimatedMinutes)
                .contextMenu {
                    Button("Delete", role: .destructive) { context.delete(session) }
                }
            
            if session.isConversational == true {
                // Conversational chat: only render Tempo's response bubble, never duration pills
                if let response = session.tempoResponse {
                    aiBubble(text: response)
                }
            } else if session.startedAt == nil && session.estimatedMinutes == nil {
                // If waiting for duration and Tempo has delivered the prompt:
                if let response = session.tempoResponse {
                    VStack(alignment: .leading, spacing: 10) {
                        aiBubble(text: response)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([15, 25, 45, 60, 90], id: \.self) { mins in
                                    Button {
                                        setEstimate(mins, for: session)
                                    } label: {
                                        Text("\(mins)m")
                                            .font(.system(size: 13, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
                                    }
                                    .pressable(scale: 0.95)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .transition(.iMessageAIPop)
                    }
                    .transition(.iMessageAIPop)
                }
            } else if let response = session.tempoResponse {
                if !(session.isRetroactive ?? false) || session.isRunning {
                    aiBubble(text: response)
                }
            }
            
            if session.isRunning && session.tempoResponse != nil {
                runningFocusCard(for: session)
                    .transition(.iMessageAIPop)
            }
            
            if !session.isRunning, session.actualMinutes != nil {
                if let endCmd = session.endCommandText { userBubble(text: endCmd, est: nil) }
                if let endResponse = session.tempoEndResponse {
                    aiBubble(text: endResponse)
                        .contextMenu {
                            Button("Revert / Restore Task", systemImage: "arrow.uturn.backward") {
                                revertSession(session)
                            }
                            Button("Delete", role: .destructive) {
                                context.delete(session)
                            }
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func userBubble(text: String, est: Int?) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.trailing)
                
                if let est = est {
                    Text("Est: \(est)m")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.52, blue: 1.0),
                        Color(red: 0.0, green: 0.44, blue: 0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 18,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 18,
                    style: .continuous
                )
            )
            .shadow(color: Color.blue.opacity(0.22), radius: 6, x: 0, y: 2)
        }
        .transition(.iMessageUserFly)
    }
    
    @ViewBuilder
    private func aiBubble(text: String) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.indigo.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)
                    .overlay(Circle().strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.8))
                
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)
            }
            .padding(.bottom, 2)
            
            Text(text)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.9))
                .lineSpacing(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.165) : Color(red: 0.91, green: 0.91, blue: 0.93),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            
            Spacer(minLength: 36)
        }
        .transition(.iMessageAIPop)
    }
    
    @ViewBuilder
    private func runningFocusCard(for session: Session) -> some View {
        let isExpanded = expandedActiveSessionIds.contains(session.sessionIdentifier)
        let isArrivalActive = session.isArrivalTrackingActive == true || (travelManager.activeArrivalTarget?.sessionId == session.sessionIdentifier)
        
        VStack(alignment: .leading, spacing: 10) {
            // Main Live Timer Bar (Tappable for expansion)
            HStack(spacing: 8) {
                liveTimerBubble(startDate: session.startedAt ?? Date())
                    .onTapGesture {
                        withAnimation(AppMotion.cardExpand) {
                            if isExpanded {
                                expandedActiveSessionIds.remove(session.sessionIdentifier)
                            } else {
                                expandedActiveSessionIds.insert(session.sessionIdentifier)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Finish & Log", systemImage: "checkmark.circle") {
                            stopSession(session, endCommandText: "Stopped")
                        }
                        Button("Cancel & Discard", systemImage: "xmark.circle", role: .destructive) {
                            cancelRunningSession(session)
                        }
                    }
                
                Spacer()
                
                Button {
                    withAnimation(AppMotion.cardExpand) {
                        if isExpanded {
                            expandedActiveSessionIds.remove(session.sessionIdentifier)
                        } else {
                            expandedActiveSessionIds.insert(session.sessionIdentifier)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary.opacity(0.8))
                }
                .pressable(scale: 0.90)
            }
            
            // Live Real-Time GPS Arrival Tracking Card (if destination tracking is active)
            if isArrivalActive {
                HStack(spacing: 10) {
                    TimelineView(.animation) { timeline in
                        let pulse = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) < 0.6
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(pulse ? 0.35 : 0.15))
                                .frame(width: 28, height: 28)
                                .scaleEffect(pulse ? 1.15 : 0.95)
                                .animation(AppMotion.smoothOut, value: pulse)
                            Image(systemName: "location.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.teal)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(session.destinationTitle ?? "Destination")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            
                            if let dist = travelManager.remainingDistanceMeters {
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                Text(travelManager.formatDistance(meters: dist))
                                    .font(.system(size: 12, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.teal)
                            }
                        }
                        
                        Text("Session auto-completes on arrival")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        travelManager.simulateArrival()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.checkered")
                                .font(.system(size: 10, weight: .bold))
                            Text("Arrived")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(Color.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.teal.opacity(0.14), in: Capsule())
                    }
                    .pressable(scale: 0.92)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.teal.opacity(0.35), lineWidth: 0.9)
                )
                .transition(.cardExpandTransition)
            }
            
            // Expanded Controls (Progress & Extensions)
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Quick Add:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        ForEach([5, 10, 15, 30], id: \.self) { mins in
                            Button {
                                extendRunningSession(session, by: mins, userCommandText: "+\(mins)m")
                            } label: {
                                Text("+\(mins)m")
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.blue)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.12), in: Capsule())
                            }
                            .pressable(scale: 0.92)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Button {
                            stopSession(session, endCommandText: "Done")
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                Text("Finish & Log Session")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.blue.opacity(0.25), radius: 4, x: 0, y: 2)
                        }
                        .pressable(scale: 0.96)
                        
                        Button {
                            cancelRunningSession(session)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.red.opacity(0.85))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .pressable(scale: 0.92)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8)
                )
                .transition(.cardExpandTransition)
            } else if !isArrivalActive {
                // Compact Quick Action Chips in Chat
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach([5, 10, 15, 30], id: \.self) { mins in
                            Button {
                                extendRunningSession(session, by: mins, userCommandText: "+\(mins)m")
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("\(mins)m")
                                        .font(.system(size: 11, weight: .semibold))
                                        .monospacedDigit()
                                }
                                .foregroundStyle(Color.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.10), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.blue.opacity(0.3), lineWidth: 0.8))
                            }
                            .pressable(scale: 0.94)
                        }
                        
                        Button {
                            stopSession(session, endCommandText: "Done")
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Done")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue, in: Capsule())
                        }
                        .pressable(scale: 0.94)
                    }
                    .padding(.leading, 32)
                }
            }
        }
    }
    
    @ViewBuilder
    private func liveTimerBubble(startDate: Date) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            
            HStack(alignment: .bottom, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 24, height: 24)
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.blue)
                }
                .padding(.bottom, 2)
                
                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                        .scaleEffect(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.15 : 0.85)
                        .opacity(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1 : 0.4)
                        .animation(AppMotion.snappy, value: timeline.date)
                    
                    Text(String(format: "%02d:%02d", minutes, seconds))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText(countsDown: false))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.9))
                    
                    Text("Running")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.165) : Color(red: 0.91, green: 0.91, blue: 0.93),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                )
                .shadow(color: Color.blue.opacity(0.12), radius: 6, x: 0, y: 2)
                
                Spacer(minLength: 36)
            }
        }
    }
    
    @ViewBuilder
    private func typingBubble() -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.25), Color.indigo.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(Color.blue.opacity(0.35), lineWidth: 0.8))
                
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
                    .symbolEffectsRemoved(reduceMotion)
            }
            .padding(.bottom, 2)
            
            TypingDotsView()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    colorScheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.165) : Color(red: 0.91, green: 0.91, blue: 0.93),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 4,
                        bottomTrailingRadius: 18,
                        topTrailingRadius: 18,
                        style: .continuous
                    )
                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, x: 0, y: 2)
            
            Spacer(minLength: 36)
        }
        .transition(.iMessageAIPop)
    }
}

// MARK: - REAL APPLE APP ICONS
struct RealCalendarAppIcon: View {
    var size: CGFloat = 24
    
    private var weekdayString: String {
        TempoFormatters.calendarMonthFormatter.string(from: Date()).uppercased()
    }
    
    private var dayString: String {
        TempoFormatters.calendarDayNumberFormatter.string(from: Date())
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
            
            VStack(spacing: 0) {
                // Red top strip
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: size * 0.22,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: size * 0.22,
                        style: .continuous
                    )
                    .fill(Color(red: 0.95, green: 0.23, blue: 0.23))
                    
                    Text(weekdayString)
                        .font(.system(size: max(6, size * 0.28), weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(height: size * 0.38)
                
                // White bottom with day number
                Text(dayString)
                    .font(.system(size: max(8, size * 0.44), weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
    }
}

struct RealRemindersAppIcon: View {
    var size: CGFloat = 24
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.15), radius: 1.5, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: size * 0.09) {
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.98, green: 0.55, blue: 0.14)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.44, height: size * 0.07)
                }
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.18, green: 0.56, blue: 0.98)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.44, height: size * 0.07)
                }
                HStack(spacing: size * 0.08) {
                    Circle().fill(Color(red: 0.38, green: 0.82, blue: 0.38)).frame(width: size * 0.17, height: size * 0.17)
                    Capsule().fill(Color(red: 0.82, green: 0.82, blue: 0.85)).frame(width: size * 0.32, height: size * 0.07)
                }
            }
            .padding(.horizontal, size * 0.13)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

struct RealUnifiedIntegrationIcon: View {
    var size: CGFloat = 24
    
    var body: some View {
        HStack(spacing: -size * 0.28) {
            RealCalendarAppIcon(size: size * 0.88)
            RealRemindersAppIcon(size: size * 0.88)
        }
    }
}

extension Notification.Name {
    static let checkScheduleNotification = Notification.Name("checkScheduleNotification")
    static let syncWidgetSessionsNotification = Notification.Name("syncWidgetSessionsNotification")
}

// MARK: - DATE JUMP SHEET
struct DateJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    let loggedDays: [Date]
    let onSelectDate: (Date) -> Void
    
    @State private var pickedDate = Date()
    
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return TempoFormatters.dayJumpFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                List {
                    Section {
                        DatePicker(
                            "Select Date",
                            selection: $pickedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .tint(Theme.brandMint)
                        .onChange(of: pickedDate) { _, newDate in
                            onSelectDate(newDate)
                            dismiss()
                        }
                    } header: {
                        Text("Jump to Date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                    )
                    .listRowSeparator(.hidden)
                    
                    if !loggedDays.isEmpty {
                        Section {
                            ForEach(loggedDays.sorted(by: >), id: \.self) { day in
                                Button {
                                    onSelectDate(day)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.brandMint)
                                        Text(dayLabel(for: day))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.3))
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            Text("Logged Days")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Locate Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}
