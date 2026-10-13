import SwiftUI
import SwiftData

/// The five things the clock can be. Swiping the desk changes the mode; nothing else moves.
enum DeskMode: Int, CaseIterable, Identifiable {
    case focus, alarms, stopwatch, world, logbook

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .alarms: return "Alarms"
        case .stopwatch: return "Stopwatch"
        case .world: return "World"
        case .logbook: return "Logbook"
        }
    }
}

/// One fixed room for the whole app. Wall, desk, clock, wall display and speech bubble never move;
/// only the objects on the desk slide when you change mode, and the clock morphs into its new job.
struct DeskLayout {
    let width: CGFloat
    let height: CGFloat
    let insets: UIEdgeInsets

    var clockSize: CGFloat { min(196, width * 0.5) }
    var displayTop: CGFloat { insets.top + 4 }
    var displayHeight: CGFloat { 96 }
    var clockTop: CGFloat { displayTop + displayHeight }
    var feetY: CGFloat { clockTop + clockSize * mascotFootFraction }
    var horizonY: CGFloat { feetY - clockSize * 0.30 }
    var bubbleCenterY: CGFloat { clockTop + clockSize + 32 }
    var composerHeight: CGFloat { 52 }
    var bandHeight: CGFloat { 30 }
    var frontEdgeY: CGFloat { height - insets.bottom - composerHeight - 18 - bandHeight }
    var propsTop: CGFloat { bubbleCenterY + 40 }
    var propsHeight: CGFloat { max(150, frontEdgeY - 6 - propsTop) }
}

struct TempoDeskScene: View {
    var sessions: [Session]
    var calibrationScore: Double

    @Environment(\.modelContext) private var modelContext
    @Bindable private var store = TimeOSStore.shared
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var dialRemainder: CGFloat = 0

    private var mode: DeskMode { DeskMode(rawValue: store.selectedMainTab) ?? .focus }
    private var isRinging: Bool { store.activeRingingAlarmID != nil || store.timerAlertActive }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let layout = DeskLayout(width: geo.size.width, height: geo.size.height, insets: DeviceInsets.current)
                room(layout)
            }
            .ignoresSafeArea()

            composerLayer
        }
        .onTapGesture { typing = false }
        .onChange(of: typing) { _, isTyping in
            if isTyping && draft.isEmpty { store.say(TempoVoice.typingPrompt) }
        }
    }

    // MARK: - The room

    @ViewBuilder
    private func room(_ L: DeskLayout) -> some View {
        ZStack(alignment: .topLeading) {
            DeskPalette.wall

            // Desk top, from its back edge behind the clock to the front edge.
            DeskSurface()
                .frame(width: L.width, height: L.frontEdgeY - L.horizonY)
                .offset(y: L.horizonY)

            // Front edge, the shade under the table, and its legs.
            DeskFront()
                .frame(width: L.width, height: L.height - L.frontEdgeY)
                .offset(y: L.frontEdgeY)

            modeStrip(L)
                .frame(width: L.width, height: L.bandHeight)
                .offset(y: L.frontEdgeY)

            WallDisplay(mode: mode, store: store, isRinging: isRinging, calibrationScore: calibrationScore)
                .frame(width: L.width, height: L.displayHeight)
                .offset(y: L.displayTop)
                .contentShape(Rectangle())
                .gesture(dialGesture)

            // Objects on the desk for the current mode (or the ringing controls).
            Group {
                if isRinging {
                    RingingProps(store: store)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    pager(L)
                        .transition(.opacity)
                }
            }
            .frame(width: L.width, height: L.propsHeight)
            .offset(y: L.propsTop)

            MascotSpeechBubble(text: store.mascotVoiceMessage)
                .frame(width: L.width - 48)
                .position(x: L.width / 2, y: L.bubbleCenterY)

            clock(L)
                .frame(width: L.clockSize, height: L.clockSize)
                .position(x: L.width / 2, y: L.clockTop + L.clockSize / 2)
        }
        .frame(width: L.width, height: L.height)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isRinging)
    }

    // MARK: - Clock (the same clock in every mode, morphing between jobs)

    private func clock(_ L: DeskLayout) -> some View {
        TempoInteractiveMascotView(
            size: L.clockSize,
            providesMinuteAngle: mode == .stopwatch || mode == .world,
            onLeftEarTap: leftEar,
            onRightEarTap: rightEar,
            onBodyTap: bodyTap,
            live: { now in clockPose(at: now) }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                guard !isRinging, abs(value.translation.width) > 70,
                      abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                step(value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func clockPose(at now: Date) -> TempoMascotLive {
        if store.activeRingingAlarmID != nil { return TempoMascotLive(regime: .alarmRinging) }
        if store.timerAlertActive { return TempoMascotLive(regime: .timerComplete) }
        switch mode {
        case .focus:
            let rem = store.timerRemaining(at: now)
            let fraction = min(1, max(0, rem / max(1, Double(store.timerTargetSeconds))))
            let regime: TempoMascotRegime
            if store.timerIsRunning {
                if rem < 0 { regime = .calibOvertime }
                else if rem <= 10 { regime = .timerFinal10s }
                else if store.timerIsRestMode { regime = .timerPomodoroRest }
                else if store.timerIsKitchenUtility { regime = .timerQuickKitchen }
                else { regime = .timerActiveCountdown }
            } else if typing || !draft.isEmpty {
                regime = .calibEstimating
            } else {
                regime = .timerDialing
            }
            return TempoMascotLive(regime: regime, bezelProgress: store.timerIsRunning || store.timerAccumulatedSeconds > 0 ? fraction : nil)
        case .alarms:
            if store.alarms.contains(where: { $0.snoozedUntil != nil }) { return TempoMascotLive(regime: .alarmSnoozing) }
            if let next = store.nextAlarmFire() {
                return TempoMascotLive(regime: next.alarm.isBedtimeWindDown ? .alarmBedtimeMoody : .alarmArmed)
            }
            return TempoMascotLive(regime: .alarmBedtimeMoody)
        case .stopwatch:
            let total = store.chronoTotalElapsed(at: now)
            let regime: TempoMascotRegime = store.chronoIsRunning ? .chronoRunning : (total > 0 ? .chronoPaused : .chronoZeroed)
            return TempoMascotLive(regime: regime, minuteAngle: total.truncatingRemainder(dividingBy: 60) * 6)
        case .world:
            // The clock shows your real local time.
            let c = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
            let m = Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
            let h = Double((c.hour ?? 0) % 12) + m / 60
            let hour = c.hour ?? 12
            return TempoMascotLive(
                regime: (hour >= 22 || hour < 6) ? .worldRemoteNight : .worldLocalDay,
                minuteAngle: m * 6,
                hourAngle: h * 30
            )
        case .logbook:
            return TempoMascotLive(regime: calibrationScore >= 0.85 ? .calibBullseyeJump : .calibEstimating)
        }
    }

    private func leftEar() {
        switch mode {
        case .focus: store.resetTimer()
        case .stopwatch: store.pressChronoLeftEar()
        default: store.pokeMascot()
        }
    }

    private func rightEar() {
        switch mode {
        case .focus: store.toggleTimerPauseResume()
        case .stopwatch: store.toggleChronoStartStop()
        default: store.pokeMascot()
        }
    }

    private func bodyTap() {
        if isRinging {
            if store.timerAlertActive { store.silenceTimerAlert() }
            else { TempoSoundEngine.shared.stopRinging() }
            return
        }
        switch mode {
        case .alarms:
            if let next = store.nextAlarmFire()?.alarm ?? store.alarms.first {
                store.triggerAlarmPreview(next.id)
            }
        default:
            store.pokeMascot()
        }
    }

    // MARK: - Pager (only the desk objects slide)

    private var modeID: Binding<Int?> {
        Binding(
            get: { store.selectedMainTab },
            set: { if let new = $0, new != store.selectedMainTab { store.selectedMainTab = new; TactileFeedback.selection() } }
        )
    }

    private func pager(_ L: DeskLayout) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(DeskMode.allCases) { page in
                    pageContent(page)
                        .frame(width: L.width, height: L.propsHeight)
                        .id(page.rawValue)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: modeID)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func pageContent(_ page: DeskMode) -> some View {
        switch page {
        case .focus: FocusDeskObjects(store: store)
        case .alarms: AlarmDeskObjects(store: store)
        case .stopwatch: StopwatchDeskObjects(store: store)
        case .world: WorldDeskObjects(store: store)
        case .logbook: LogbookDeskObjects(sessions: sessions, calibrationScore: calibrationScore)
        }
    }

    private func step(_ delta: Int) {
        let next = min(DeskMode.allCases.count - 1, max(0, store.selectedMainTab + delta))
        guard next != store.selectedMainTab else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.1)) { store.selectedMainTab = next }
        TactileFeedback.selection()
    }

    // MARK: - Mode names engraved on the desk's front edge

    private func modeStrip(_ L: DeskLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(DeskMode.allCases) { item in
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.1)) { store.selectedMainTab = item.rawValue }
                    TactileFeedback.selection()
                } label: {
                    Text(item.title.uppercased())
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(item == mode ? TempoMascotPalette.orange : DeskPalette.lip.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.25), radius: 0, x: 0, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == mode ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .disabled(isRinging)
    }

    // MARK: - Drag the wall display up or down to set the timer

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard mode == .focus, !store.timerIsRunning, store.timerAccumulatedSeconds == 0 else { return }
                let steps = Int((-value.translation.height - dialRemainder) / 14)
                if steps != 0 {
                    dialRemainder += CGFloat(steps) * 14
                    let minutes = min(180, max(1, store.timerTargetSeconds / 60 + steps))
                    store.timerTargetSeconds = minutes * 60
                    TactileFeedback.selection()
                }
            }
            .onEnded { _ in dialRemainder = 0 }
    }

    // MARK: - Chat with the clock

    private var composerLayer: some View {
        VStack(spacing: 8) {
            Spacer()
            if typing {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { chip in
                            Button {
                                draft = chip
                                submit()
                            } label: {
                                Text(chip)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.tempoInk)
                                    .padding(.horizontal, 14)
                                    .frame(height: 34)
                                    .deskPaper(cornerRadius: 17)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                Image(systemName: store.isCalculatingTravel ? "location.fill" : "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TempoMascotPalette.orange)
                    .symbolEffect(.pulse, isActive: store.isCalculatingTravel)
                TextField("Tell Tempo what you're doing…", text: $draft)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.tempoInk)
                    .focused($typing)
                    .submitLabel(.send)
                    .onSubmit(submit)
                if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: submit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(TempoMascotPalette.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .frame(height: 52)
            .deskPaper(cornerRadius: 26)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: typing)
    }

    private var suggestions: [String] {
        if store.timerIsRunning { return ["+5m", "+15m", "Done", "How am I doing?"] }
        return Array(store.calendarSuggestions.prefix(3)) + ["Deep work 45m", "Email 15m", "What's on my calendar?", "How am I doing?"]
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let wasRunning = store.timerIsRunning
        store.parseAndStartQuickInput(text, sessions: sessions, context: modelContext)
        draft = ""
        typing = false
        // A task typed from any mode lands on the Focus desk, where its timer lives.
        if store.timerIsRunning && !wasRunning && store.selectedMainTab != DeskMode.focus.rawValue {
            withAnimation(.spring(duration: 0.45, bounce: 0.1)) { store.selectedMainTab = DeskMode.focus.rawValue }
        }
    }
}

// MARK: - The wall display: one big readout above the clock, changing with the mode

struct WallDisplay: View {
    let mode: DeskMode
    var store: TimeOSStore
    let isRinging: Bool
    let calibrationScore: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: mode == .stopwatch && store.chronoIsRunning ? 0.05 : 0.5)) { context in
            let reading = readout(at: context.date)
            VStack(spacing: 0) {
                Text(reading.caption.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(TempoMascotPalette.orange)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                Text(reading.value)
                    .font(.tempoNumerals(66))
                    .foregroundStyle(Color.tempoInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
        .animation(.spring(duration: 0.35, bounce: 0.1), value: mode)
        .padding(.horizontal, 24)
    }

    private func readout(at now: Date) -> (caption: String, value: String) {
        if let id = store.activeRingingAlarmID {
            let label = store.alarms.first { $0.id == id }?.label ?? "Alarm"
            return (label, now.formatted(date: .omitted, time: .shortened))
        }
        if store.timerAlertActive {
            return ("Time's up · \(store.timerLinkedTaskTitle)", "+" + TempoFormat.clock(max(0, -store.timerRemaining(at: now))))
        }
        switch mode {
        case .focus:
            let rem = store.timerRemaining(at: now)
            let idle = !store.timerIsRunning && store.timerAccumulatedSeconds == 0
            let caption = idle ? "\(store.timerLinkedTaskTitle) · drag to set" : store.timerLinkedTaskTitle
            return (caption, (rem < 0 ? "+" : "") + TempoFormat.clock(abs(rem)))
        case .alarms:
            guard let next = store.nextAlarmFire(after: now) else { return ("No alarms on", "--:--") }
            let left = TempoFormat.minutes(Int(next.date.timeIntervalSince(now)))
            return ("\(next.alarm.label) · in \(left)", next.date.formatted(date: .omitted, time: .shortened))
        case .stopwatch:
            let caption = store.chronoLaps.isEmpty ? "Stopwatch" : "Lap \(store.chronoLaps.count + 1)"
            return (caption, TempoFormat.stopwatch(store.chronoTotalElapsed(at: now)))
        case .world:
            let city = TimeZone.current.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "Here"
            return (city, now.formatted(date: .omitted, time: .shortened))
        case .logbook:
            return ("Estimates on target", "\(Int((calibrationScore * 100).rounded()))%")
        }
    }
}
