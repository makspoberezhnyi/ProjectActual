import SwiftUI
import SwiftData

struct FocusInstrumentView: View {
    var sessions: [Session]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Bindable private var store = TimeOSStore.shared

    @State private var draft = ""
    @State private var dragRemainder: CGFloat = 0
    @FocusState private var inputFocused: Bool

    init(sessions: [Session] = []) {
        self.sessions = sessions
    }

    private var isIdle: Bool { !store.timerIsRunning && store.timerAccumulatedSeconds == 0 }

    var body: some View {
        ZStack {
            SharedBackground()
                .onTapGesture {
                    inputFocused = false
                }

            VStack(spacing: 0) {
                // 1. Always-visible Natural Language Task & Chat Bar
                taskInputBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // 2. Mascot Voice / Travel ETA Pill
                voiceResponsePill
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Spacer(minLength: 6)

                // 3. Hero Mascot
                ZStack {
                    TempoAura()
                    mascot
                }
                .frame(height: 240)

                // 4. Active Task Label + Big Numerals
                VStack(spacing: 2) {
                    Text(store.timerLinkedTaskTitle.isEmpty ? "Focus" : store.timerLinkedTaskTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.tempoAccent)
                        .lineLimit(1)

                    numerals
                }
                .padding(.top, 4)

                Spacer(minLength: 6)

                // 5. Presets (when idle)
                presets
                    .frame(height: 50)
                    .opacity(isIdle ? 1 : 0)
                    .allowsHitTesting(isIdle)
                    .padding(.bottom, 16)

                // 6. Primary & Contextual Controls
                controls
                    .padding(.bottom, 22)
            }
            .animation(.spring(duration: 0.4, bounce: 0.15), value: isIdle)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: store.timerIsRunning)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: store.latestTravelResult)
        }
    }

    // MARK: - 1. Always-Visible Task & Chat Input Bar

    private var taskInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: store.isCalculatingTravel ? "location.fill" : "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tempoAccent)
                .symbolEffect(.pulse, isActive: store.isCalculatingTravel)

            TextField("Type a task (\"Design 30m\") or ask \"Ride to…\"", text: $draft)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.tempoInk)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit {
                    submitInput()
                }

            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    submitInput()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.tempoAccent)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Send")
            } else if inputFocused {
                Button {
                    inputFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.tempoMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss keyboard")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(TempoSurface.card(colorScheme))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            inputFocused ? Color.tempoAccent.opacity(0.65) : TempoSurface.border(colorScheme),
                            lineWidth: inputFocused ? 1.5 : 1
                        )
                )
        )
    }

    private func submitInput() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.parseAndStartQuickInput(text, sessions: sessions, context: modelContext)
        draft = ""
        inputFocused = false
    }

    // MARK: - 2. Voice & Live Travel Pill

    @ViewBuilder
    private var voiceResponsePill: some View {
        if let travel = store.latestTravelResult {
            HStack(spacing: 10) {
                Image(systemName: travel.transportMode.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.tempoAccent)

                Text("\(travel.destinationTitle) · \(travel.formattedDuration) (\(travel.distanceString))")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.tempoInk)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    store.startTimer(
                        title: "Commute to \(travel.destinationTitle)",
                        seconds: max(1, travel.travelDurationMinutes) * 60
                    )
                    store.latestTravelResult = nil
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.tempoAccent))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start commute timer")

                Button {
                    LocationTravelManager.shared.openInMaps(result: travel)
                } label: {
                    Image(systemName: "map.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tempoMuted)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.tempoInk.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open in Maps")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(TempoSurface.card(colorScheme))
                    .overlay(Capsule().strokeBorder(TempoSurface.border(colorScheme), lineWidth: 1))
            )
        } else {
            Text(store.mascotVoiceMessage)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.tempoMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - 3. Mascot (reads live state per frame, the page does not re-render)

    private var mascot: some View {
        TempoInteractiveMascotView(
            size: 215,
            onLeftEarTap: { store.resetTimer() },
            onRightEarTap: { store.toggleTimerPauseResume() },
            live: { now in
                let rem = store.timerRemaining(at: now)
                let target = max(1, Double(store.timerTargetSeconds))
                let fraction = min(1, max(0, rem / target))
                let regime: TempoMascotRegime
                if store.timerIsRunning {
                    if rem < 0 { regime = .calibOvertime }
                    else if rem <= 10 { regime = .timerFinal10s }
                    else if store.timerIsRestMode { regime = .timerPomodoroRest }
                    else if store.timerIsKitchenUtility { regime = .timerQuickKitchen }
                    else { regime = .timerActiveCountdown }
                } else {
                    regime = .timerDialing
                }
                return TempoMascotLive(regime: regime, bezelProgress: fraction)
            }
        )
    }

    // MARK: - 4. Numerals (own timeline, drag vertically to dial minutes)

    private var numerals: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let rem = store.timerRemaining(at: context.date)
            let over = rem < 0
            Text((over ? "+" : "") + TempoFormat.clock(abs(rem)))
                .font(.tempoNumerals(72))
                .foregroundStyle(over ? Color.tempoAccent : Color.tempoInk)
                .contentTransition(.numericText())
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    guard isIdle else { return }
                    let steps = Int((-value.translation.height - dragRemainder) / 14)
                    if steps != 0 {
                        dragRemainder += CGFloat(steps) * 14
                        let new = min(180, max(1, store.timerTargetSeconds / 60 + steps))
                        store.timerTargetSeconds = new * 60
                        TactileFeedback.selection()
                    }
                }
                .onEnded { _ in dragRemainder = 0 }
        )
        .contextMenu {
            Button("Add 5 min", systemImage: "plus") { store.extendTimer(bySeconds: 300) }
            Button("Reset", systemImage: "arrow.counterclockwise") { store.resetTimer() }
        }
        .accessibilityElement()
        .accessibilityLabel("Time remaining")
        .accessibilityValue(TempoFormat.clock(max(0, store.timerRemaining())))
        .accessibilityAdjustableAction { direction in
            guard isIdle else { return }
            let delta = direction == .increment ? 60 : -60
            store.timerTargetSeconds = min(180 * 60, max(60, store.timerTargetSeconds + delta))
        }
    }

    // MARK: - 5. Presets (icon only)

    private var presets: some View {
        HStack(spacing: 14) {
            ForEach(store.timerPresets) { preset in
                let selected = store.timerTargetSeconds == preset.durationSeconds
                    && store.timerLinkedTaskTitle == preset.title
                Button {
                    store.selectTimerPreset(
                        title: preset.title,
                        seconds: preset.durationSeconds,
                        isRest: preset.isRestInterval,
                        isKitchen: preset.isKitchenUtility
                    )
                } label: {
                    Image(systemName: preset.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(selected ? Color.tempoAccent : Color.tempoMuted)
                        .frame(width: 46, height: 46)
                        .background(
                            Circle().fill(selected ? Color.tempoAccent.opacity(0.16) : Color.clear)
                        )
                }
                .buttonStyle(TempoPressStyle())
                .accessibilityLabel(preset.title)
            }
        }
    }

    // MARK: - 6. Controls

    private var controls: some View {
        HStack(spacing: 28) {
            ghost("arrow.counterclockwise", "Reset") { store.resetTimer() }
            TempoRoundButton(
                symbol: store.timerIsRunning ? "pause.fill" : "play.fill",
                label: store.timerIsRunning ? "Pause" : "Start",
                isPrimary: true
            ) { store.toggleTimerPauseResume() }
            ghost("checkmark", "Done") { store.completeAndCalibrateTimer(context: modelContext) }
        }
        .frame(height: 76)
    }

    private func ghost(_ symbol: String, _ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        TempoRoundButton(symbol: symbol, label: label, action: action)
            .opacity(isIdle ? 0 : 1)
            .scaleEffect(isIdle ? 0.6 : 1)
            .allowsHitTesting(!isIdle)
    }
}

#Preview("Focus") {
    FocusInstrumentView()
}

#Preview("Focus · Dark") {
    FocusInstrumentView()
        .preferredColorScheme(.dark)
}
