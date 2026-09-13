import SwiftUI
import SwiftData

// MARK: - LOG TAB
struct LogTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    @Binding var calibrationScore: Double
    
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    
    @Bindable private var eventKit = EventKitManager.shared
    
    var groupedSessions: [(Date, [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.timestamp)
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var isConfiguringTask: Bool {
        sessions.contains(where: { $0.startedAt == nil && $0.estimatedMinutes == nil && $0.endedAt == nil && !($0.isScheduleQuery ?? false) })
    }
    
    var isRunningSession: Bool {
        sessions.contains(where: { $0.isRunning })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                VStack(spacing: 0) {
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
                                
                                ForEach(groupedSessions, id: \.0) { (day, dailySessions) in
                                    VStack(spacing: 12) {
                                        glassChip(text: dayString(for: day))
                                            .padding(.vertical, 6)
                                        
                                        ForEach(dailySessions) { session in
                                            sessionChatSequence(for: session)
                                                .id(session.id)
                                        }
                                    }
                                }
                                
                                // Interactive In-Chat Suggestions: Only show when idle (before a task starts or after completion)
                                if !isRunningSession && !isConfiguringTask && !isTyping {
                                    suggestionChatBubble()
                                        .id("suggestions")
                                }
                                
                                if isTyping {
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
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: sessions.last?.schedulePayload) { _, _ in
                            if let last = sessions.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: isTyping) { _, isTypingNow in
                            if isTypingNow {
                                withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
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
                    existing.tempoEndResponse = "Done. Logged \(item.actualMinutes ?? 0)m."
                    didModify = true
                } else if existing.isRunning && item.endedAt == nil {
                    // Still running, keep in pending so widget stop can find it
                    remainingPending.append(item)
                }
            } else {
                let session = Session(
                    rawText: item.rawText,
                    estimatedMinutes: item.estimatedMinutes,
                    startedAt: item.startedAt,
                    tempoResponse: "Timer started. Focus."
                )
                session.endedAt = item.endedAt
                session.actualMinutes = item.actualMinutes
                if item.endedAt != nil {
                    session.tempoEndResponse = "Done. Logged \(item.actualMinutes ?? 0)m."
                } else {
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    // Suggestion bubble with 2-column grid for zero clipping
    @ViewBuilder
    private func suggestionChatBubble() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.brandMint)
                    Text("SUGGESTED TASKS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                
                if !eventKit.suggestions.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(eventKit.suggestions.prefix(4), id: \.self) { suggestion in
                            Button {
                                inputText = suggestion
                                submit()
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 9)
                                    .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
            )
            .padding(.trailing, 16)
            
            Spacer(minLength: 0)
        }
    }
    
    private var inputArea: some View {
        HStack(spacing: 8) {
            // Quick Action: Check Calendar & Reminders
            Button {
                handleScheduleQuery(userText: "Check calendar & reminders")
            } label: {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.brandMint)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
            }
            
            TextField("What are you doing?", text: $inputText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
                .foregroundStyle(.primary)
                .onSubmit { submit() }
            
            if inputText.isEmpty {
                Button {
                    inputText = "Quick Focus (15m)"
                    submit()
                } label: {
                    Image(systemName: "dial.low.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
                }
            } else {
                Button { submit() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                        .frame(width: 44, height: 44)
                        .background(colorScheme == .dark ? Color.white : Color.black, in: Circle())
                }
            }
        }
    }
    
    private func submit() {
        guard !inputText.isEmpty else { return }
        let savedText = inputText
        
        // If there is an active session awaiting an estimate, check if input is a duration
        if let pendingSession = sessions.last(where: { $0.startedAt == nil && $0.estimatedMinutes == nil && $0.endedAt == nil && !($0.isScheduleQuery ?? false) }) {
            if ChatParser.isDurationOnly(savedText), let mins = ChatParser.extractMinutes(from: savedText) {
                inputText = ""
                setEstimate(mins, for: pendingSession)
                return
            } else if let mins = ChatParser.extractMinutes(from: savedText), !savedText.contains(" ") {
                inputText = ""
                setEstimate(mins, for: pendingSession)
                return
            } else {
                // User entered a new activity name instead of a duration; remove the incomplete pending entry
                context.delete(pendingSession)
            }
        }
        
        let intent = ChatParser.parse(inputText)
        inputText = ""
        
        if intent.isScheduleCheck {
            handleScheduleQuery(userText: savedText)
            return
        }
        
        if intent.isSuggestionRequest {
            handleScheduleQuery(userText: savedText)
            return
        }
        
        if intent.isStopCommand {
            if let runningSession = sessions.last(where: { $0.isRunning }) {
                runningSession.endedAt = Date()
                let actual = Int(Date().timeIntervalSince(runningSession.startedAt ?? Date()) / 60)
                runningSession.actualMinutes = actual
                runningSession.endCommandText = savedText
                
                LiveActivityManager.shared.endLiveActivity(actualMinutes: actual)
                
                isTyping = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let ratioText = runningSession.biasRatio != nil ? String(format: "%.1fx", runningSession.biasRatio!) : "-"
                    runningSession.tempoEndResponse = "Done. Logged \(actual)m. (Ratio: \(ratioText))"
                    isTyping = false
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
                tempoResponse: "How long do you expect this to take?"
            )
            context.insert(session)
            return
        }
        
        let session = Session(
            rawText: intent.text,
            estimatedMinutes: intent.estimatedMinutes,
            startedAt: intent.isRetroactive ? Date().addingTimeInterval(-Double(intent.estimatedMinutes ?? 0) * 60) : Date(),
            isRetroactive: intent.isRetroactive
        )
        
        context.insert(session)
        
        if !(intent.isRetroactive) {
            LiveActivityManager.shared.startLiveActivity(
                taskTitle: intent.text,
                estimatedMinutes: intent.estimatedMinutes ?? 25,
                startDate: session.startedAt ?? Date()
            )
        }
        
        isTyping = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if intent.isRetroactive {
                session.endedAt = Date()
                session.actualMinutes = intent.estimatedMinutes
                let actual = session.actualMinutes ?? 0
                let ratioText = session.biasRatio != nil ? String(format: "%.1fx", session.biasRatio!) : "-"
                session.tempoResponse = "Got it."
                session.tempoEndResponse = "Logged \(actual)m. (Ratio: \(ratioText))"
            } else {
                session.tempoResponse = "Timer started. Focus."
            }
            isTyping = false
        }
    }
    
    private func handleScheduleQuery(userText: String = "Check calendar & reminders") {
        let querySession = Session(
            rawText: userText,
            estimatedMinutes: nil,
            startedAt: nil,
            tempoResponse: nil,
            isScheduleQuery: true,
            createdAt: Date()
        )
        context.insert(querySession)
        try? context.save()
        isTyping = true
        
        Task {
            let items = await eventKit.fetchScheduleDetails()
            let encodedData = try? JSONEncoder().encode(items)
            let jsonString = encodedData != nil ? String(data: encodedData!, encoding: .utf8) : nil
            
            // Brief natural pause
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                querySession.schedulePayload = jsonString
                let calCount = items.filter { $0.isCalendarEvent }.count
                let remCount = items.filter { !$0.isCalendarEvent }.count
                
                if calCount > 0 && remCount > 0 {
                    querySession.tempoResponse = "Here are your upcoming calendar events and reminders for today:"
                } else if calCount > 0 {
                    querySession.tempoResponse = "Here are your upcoming calendar events for today:"
                } else if remCount > 0 {
                    querySession.tempoResponse = "Here are your pending tasks from Reminders:"
                } else {
                    querySession.tempoResponse = "No upcoming calendar events found for today. Here are suggested focus sessions:"
                }
                querySession.endedAt = Date()
                isTyping = false
                try? context.save()
            }
        }
    }
    
    private func launchSessionFromSchedule(title: String, minutes: Int) {
        let session = Session(
            rawText: title,
            estimatedMinutes: minutes,
            startedAt: Date(),
            createdAt: Date()
        )
        context.insert(session)
        try? context.save()
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: title,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            session.tempoResponse = "Timer started for \(title). Focus."
            isTyping = false
            try? context.save()
        }
    }
    
    private func setEstimate(_ minutes: Int, for session: Session) {
        session.estimatedMinutes = minutes
        session.startedAt = Date()
        
        LiveActivityManager.shared.startLiveActivity(
            taskTitle: session.rawText,
            estimatedMinutes: minutes,
            startDate: session.startedAt ?? Date()
        )
        
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            session.tempoResponse = "Estimate set to \(minutes)m. Timer started. Focus."
            isTyping = false
        }
    }
    
    @ViewBuilder
    private func glassChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
    }
    
    @ViewBuilder
    private func sessionChatSequence(for session: Session) -> some View {
        if session.isScheduleQuery == true {
            scheduleQuerySequence(for: session)
        } else {
            standardSessionSequence(for: session)
        }
    }
    
    @ViewBuilder
    private func scheduleQuerySequence(for session: Session) -> some View {
        VStack(spacing: 8) {
            userBubble(text: session.rawText, est: nil)
                .contextMenu { Button("Delete", role: .destructive) { context.delete(session) } }
            
            if let response = session.tempoResponse {
                aiBubble(text: response)
                
                let items = session.scheduleItems
                if !items.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(item.isCalendarEvent ? Theme.brandMint.opacity(0.18) : Color.cyan.opacity(0.18))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: item.isCalendarEvent ? "calendar" : "checklist")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(item.isCalendarEvent ? Theme.brandMint : Color.cyan)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 5) {
                                        if let time = item.timeString, !time.isEmpty {
                                            Text(time)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.primary.opacity(0.55))
                                            Text("•")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.primary.opacity(0.3))
                                        }
                                        Text("\(item.estimatedMinutes)m Focus")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(Theme.brandMint)
                                    }
                                }
                                
                                Spacer(minLength: 8)
                                
                                Button {
                                    launchSessionFromSchedule(title: item.title, minutes: item.estimatedMinutes)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 8))
                                        Text("Start")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 2)
                }
            }
        }
    }
    
    @ViewBuilder
    private func standardSessionSequence(for session: Session) -> some View {
        VStack(spacing: 8) {
            userBubble(text: session.rawText, est: session.estimatedMinutes)
                .contextMenu { Button("Delete", role: .destructive) { context.delete(session) } }
            
            // If waiting for duration
            if session.startedAt == nil && session.estimatedMinutes == nil {
                VStack(alignment: .leading, spacing: 10) {
                    aiBubble(text: session.tempoResponse ?? "How long do you expect this to take?")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([15, 25, 45, 60, 90], id: \.self) { mins in
                                Button {
                                    setEstimate(mins, for: session)
                                } label: {
                                    Text("\(mins)m")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(colorScheme == .dark ? Color.white : Color.black, in: Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } else if let response = session.tempoResponse {
                if !(session.isRetroactive ?? false) || session.isRunning { aiBubble(text: response) }
            }
            
            if session.isRunning && session.tempoResponse != nil {
                HStack {
                    liveTimerBubble(startDate: session.startedAt ?? Date())
                        .onTapGesture {
                            session.endedAt = Date()
                            let actual = Int(Date().timeIntervalSince(session.startedAt ?? Date()) / 60)
                            session.actualMinutes = actual
                            session.endCommandText = "Stopped"
                            
                            LiveActivityManager.shared.endLiveActivity(actualMinutes: actual)
                            
                            isTyping = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                let ratioText = session.biasRatio != nil ? String(format: "%.1fx", session.biasRatio!) : "-"
                                session.tempoEndResponse = "Done. Logged \(actual)m. (Ratio: \(ratioText))"
                                isTyping = false
                            }
                        }
                    Spacer()
                }
            }
            
            if !session.isRunning, let actual = session.actualMinutes {
                if let endCmd = session.endCommandText { userBubble(text: endCmd, est: nil) }
                if let endResponse = session.tempoEndResponse { aiBubble(text: endResponse) }
            }
        }
    }
    
    @ViewBuilder
    private func userBubble(text: String, est: Int?) -> some View {
        HStack {
            Spacer(minLength: 40)
            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.95))
                if let est = est {
                    Text("Est: \(est)m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
        }
    }
    
    @ViewBuilder
    private func aiBubble(text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
            Spacer(minLength: 40)
        }
    }
    
    @ViewBuilder
    private func liveTimerBubble(startDate: Date) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            
            HStack(spacing: 8) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                    .opacity(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1 : 0.3)
                
                Text(String(format: "%02d:%02d", minutes, seconds))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.95))
                
                Text("Running")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
        }
    }
    
    @ViewBuilder
    private func typingBubble() -> some View {
        HStack {
            HStack(spacing: 4) {
                Circle().frame(width: 6, height: 6).opacity(0.3)
                Circle().frame(width: 6, height: 6).opacity(0.5)
                Circle().frame(width: 6, height: 6).opacity(0.7)
            }
            .foregroundStyle(.primary)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0))
            Spacer()
        }
    }
}

// MARK: - CORE TAB (The "Pet" Companion)
struct CoreTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var context
    
    var isRunning: Bool
    var calibrationScore: Double
    
    @State private var petTaps: Int = 0
    @State private var isPulsing: Bool = false
    
    var tierTitle: String {
        if calibrationScore >= 0.85 { return "Tier 3: Ethereal Prism" }
        if calibrationScore >= 0.65 { return "Tier 2: Resonant Crystal" }
        return "Tier 1: Lumina Seed"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                VStack(spacing: 24) {
                    // Pet Level & Status Header
                    VStack(spacing: 6) {
                        Text(tierTitle)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isRunning ? Theme.brandMint : Color.primary.opacity(0.3))
                                .frame(width: 7, height: 7)
                            Text(isRunning ? "Transmuting Time..." : "Attuned & Resting")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.55))
                        }
                    }
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    // Central Interactive Gem Pet
                    ZStack {
                        // Interactive tap ripple ring
                        if isPulsing {
                            Circle()
                                .stroke(Theme.brandMint.opacity(0.6), lineWidth: 2)
                                .frame(width: 220, height: 220)
                                .scaleEffect(1.4)
                                .opacity(0)
                                .animation(.easeOut(duration: 0.8), value: isPulsing)
                        }
                        
                        CoreObjectView(calibrationScore: calibrationScore, isRunning: isRunning)
                            .scaleEffect(isPulsing ? 1.08 : 1.0)
                    }
                    .contentShape(Circle())
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isPulsing = true
                            petTaps += 1
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isPulsing = false
                        }
                    }
                    
                    Spacer()
                    
                    // Companion Status & Resonance Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("CORE RESONANCE")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                
                                Text("\(Int(calibrationScore * 100))%")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("HARMONY STATE")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.4))
                                
                                Text(calibrationScore >= 0.8 ? "Optimal" : "Calibrating")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(calibrationScore >= 0.8 ? Theme.brandMint : Color.orange)
                            }
                        }
                        
                        // Resonance Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Theme.brandMint],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(min(1.0, max(0.05, calibrationScore))), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text("Tap your Core to interact. Keep accurate logs to evolve to higher crystal forms.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Core")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

extension Notification.Name {
    static let checkScheduleNotification = Notification.Name("checkScheduleNotification")
}
