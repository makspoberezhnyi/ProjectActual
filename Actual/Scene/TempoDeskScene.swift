import SwiftUI
import SwiftData

/// The five things the clock can be. Swiping the desk changes the mode; nothing else moves.
enum DeskMode: Int, CaseIterable, Identifiable {
    case focus, alarms, stopwatch, world, logbook

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .focus: return "timer"
        case .alarms: return "alarm.fill"
        case .stopwatch: return "stopwatch.fill"
        case .world: return "globe.europe.africa.fill"
        case .logbook: return "book.closed.fill"
        }
    }

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

/// One fixed room for the whole app. Wall, desk, clock, wall display and speech bubble never move
/// sideways; only the objects on the desk slide when you change mode, and the clock morphs into its new job.
///
/// `camera` is how high we look from: 0 is near eye level (big clock, thin steep desk, legs showing),
/// 1 is a bit higher (smaller clock, more desk for cards). Each mode picks its own height, and the whole
/// room glides between them, which gives the parallax when you switch.
struct DeskLayout {
    let width: CGFloat
    let height: CGFloat
    let insets: UIEdgeInsets
    var camera: CGFloat = 0

    private func lerp(_ low: CGFloat, _ high: CGFloat) -> CGFloat { low + (high - low) * camera }

    var dialTop: CGFloat { insets.top + 2 }
    var dialHeight: CGFloat { 44 }
    var displayTop: CGFloat { dialTop + dialHeight }
    var displayHeight: CGFloat { lerp(80, 84) }
    var clockTop: CGFloat { displayTop + displayHeight + lerp(0, 4) }
    var composerHeight: CGFloat { 52 }
    var bandHeight: CGFloat { lerp(30, 24) }
    /// From low down you see more of the legs under the desk.
    var legsShown: CGFloat { lerp(34, 6) }
    var frontEdgeY: CGFloat { height - insets.bottom - composerHeight - 14 - legsShown - bandHeight }

    /// Largest the clock can be while the desk keys still fit (small iPhones get a smaller clock).
    /// Measured at the lowest camera and kept fixed, so the clock glides instead of jumping when the
    /// camera moves (it is scaled toward this size, never re-drawn at a new one).
    var maxClockSize: CGFloat {
        let roomForKeys: CGFloat = 180
        let lowFrontEdge = height - insets.bottom - composerHeight - 14 - 34 - 30
        let lowClockTop = displayTop + 80
        let fit = (lowFrontEdge - 6 - lowClockTop - 76 - roomForKeys) / mascotFootFraction
        return max(130, min(272, width * 0.66, fit))
    }
    var clockSize: CGFloat { lerp(maxClockSize, min(196, width * 0.5, maxClockSize)) }
    var feetY: CGFloat { clockTop + clockSize * mascotFootFraction }
    /// Low camera: the desk's back edge sits just behind the feet. Higher: more desk shows behind it.
    var horizonY: CGFloat { feetY - clockSize * lerp(0.08, 0.30) }
    var bubbleCenterY: CGFloat { feetY + 38 }
    var propsTop: CGFloat { bubbleCenterY + 38 }
    var propsHeight: CGFloat { max(120, frontEdgeY - 6 - propsTop) }
    /// How far above the desk the grain lines meet: close means a steep, low-angle desk.
    var vanishingLift: CGFloat { lerp(0.15, 1.6) }
}

struct TempoDeskScene: View {
    var sessions: [Session]
    var calibrationScore: Double

    @Environment(\.modelContext) private var modelContext
    @Bindable private var store = TimeOSStore.shared
    @State private var draft = ""
    @FocusState private var typing: Bool
    @State private var dialRemainder: CGFloat = 0
    @State private var camera: CGFloat = 0

    private var mode: DeskMode { DeskMode(rawValue: store.selectedMainTab) ?? .focus }
    private var isRinging: Bool { store.activeRingingAlarmID != nil || store.timerAlertActive }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let layout = DeskLayout(width: geo.size.width, height: geo.size.height, insets: DeviceInsets.current, camera: camera)
                room(layout)
            }
            .ignoresSafeArea()

            composerLayer
        }
        .onTapGesture { typing = false }
        .onAppear { camera = cameraTarget }
        .onChange(of: cameraTarget) { _, target in
            withAnimation(.spring(duration: 0.7, bounce: 0.12)) { camera = target }
        }
        .onChange(of: typing) { _, isTyping in
            if isTyping && draft.isEmpty { store.say(TempoVoice.typingPrompt) }
        }
    }

    // MARK: - The room

    @ViewBuilder
    private func room(_ L: DeskLayout) -> some View {
        ZStack(alignment: .topLeading) {
            DeskPalette.wall

            // World mode: the wall gets a window onto the city you're looking at.
            CityWindow(store: store)
                .frame(width: L.width - 36, height: L.horizonY - L.displayTop)
                .offset(x: 18, y: L.displayTop)
                .opacity(showsWindow ? 1 : 0)
                .scaleEffect(showsWindow ? 1 : 0.96)
                .allowsHitTesting(showsWindow)

            // Desk top, from its back edge behind the clock to the front edge.
            DeskSurface(vanishingLift: L.vanishingLift)
                .frame(width: L.width, height: L.frontEdgeY - L.horizonY)
                .offset(y: L.horizonY)

            // Front edge, the shade under the table, and its legs.
            DeskFront()
                .frame(width: L.width, height: L.height - L.frontEdgeY)
                .offset(y: L.frontEdgeY)

            ModeDial(selected: mode, select: select, step: step)
                .frame(width: L.width, height: L.dialHeight)
                .offset(y: L.dialTop)
                .disabled(isRinging)
                .opacity(isRinging ? 0.3 : 1)

            WallDisplay(mode: mode, store: store, isRinging: isRinging, calibrationScore: calibrationScore)
                .frame(width: L.width, height: L.displayHeight)
                .offset(y: L.displayTop)
                .contentShape(Rectangle())
                .gesture(dialGesture)
                .opacity(showsWindow ? 0 : 1)
                .allowsHitTesting(!showsWindow)

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
                .frame(width: L.maxClockSize, height: L.maxClockSize)
                .scaleEffect(L.clockSize / L.maxClockSize, anchor: .bottom)
                .position(x: L.width / 2, y: L.clockTop + L.clockSize - L.maxClockSize / 2)
        }
        .frame(width: L.width, height: L.height)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: isRinging)
        .animation(.spring(duration: 0.45, bounce: 0.1), value: showsWindow)
    }

    private var showsWindow: Bool { mode == .world && !isRinging }

    /// How high the camera sits for each mode. Low for the clock-first modes, higher where cards need desk.
    private var cameraTarget: CGFloat {
        if isRinging { return 0 }
        switch mode {
        case .focus: return 0
        case .stopwatch: return 0.1
        case .world: return 0.45
        case .logbook: return 0.6
        case .alarms: return 0.9
        }
    }

    // MARK: - Clock (the same clock in every mode, morphing between jobs)

    private func clock(_ L: DeskLayout) -> some View {
        TempoInteractiveMascotView(
            size: L.maxClockSize,
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
            // The clock shows the time of the city in the window (or yours, with no cities).
            var cal = Calendar.current
            cal.timeZone = store.focusedCity?.timeZone ?? .current
            let c = cal.dateComponents([.hour, .minute, .second], from: now)
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

    private func select(_ item: DeskMode) {
        guard item != mode else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.1)) { store.selectedMainTab = item.rawValue }
        TactileFeedback.selection()
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

// MARK: - Mode dial: like the camera app's mode switcher, under the Dynamic Island

/// Five icons on a strip that slides so the current mode sits in the middle, its name showing
/// in an orange capsule. Tap an icon or swipe the strip.
struct ModeDial: View {
    let selected: DeskMode
    let select: (DeskMode) -> Void
    let step: (Int) -> Void

    private let itemWidth: CGFloat = 58
    private let selectedWidth: CGFloat = 132

    var body: some View {
        GeometryReader { geo in
            let index = CGFloat(selected.rawValue)
            let centerOffset = index * itemWidth + selectedWidth / 2
            HStack(spacing: 0) {
                ForEach(DeskMode.allCases) { item in
                    let on = item == selected
                    Button { select(item) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.system(size: on ? 15 : 18, weight: .semibold))
                            if on {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .fixedSize()
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .foregroundStyle(on ? Color.white : Color.tempoMuted)
                        .padding(.horizontal, on ? 14 : 0)
                        .frame(height: 34)
                        .background(Capsule().fill(on ? TempoMascotPalette.orange : Color.clear))
                        .frame(width: on ? selectedWidth : itemWidth, height: geo.size.height)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .offset(x: geo.size.width / 2 - centerOffset)
            .animation(.spring(duration: 0.45, bounce: 0.15), value: selected)
        }
        // Icons fade out toward the screen edges, like the camera dial.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.18),
                    .init(color: .black, location: 0.82),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 16).onEnded { value in
                if value.translation.width < -30 { step(1) } else if value.translation.width > 30 { step(-1) }
            }
        )
    }
}
