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
                Spacer(minLength: 4)

                // 1. Hero mascot. It shrinks a little while you type so the keyboard has room.
                ZStack {
                    TempoAura()
                    mascot
                        .scaleEffect(inputFocused ? 0.72 : 1)
                }
                .frame(height: inputFocused ? 170 : 236)

                // 2. The mascot talks back right under itself.
                speechBubble
                    .padding(.horizontal, 28)
                    .padding(.top, inputFocused ? 0 : 2)

                if !inputFocused {
                    // 3. Active task label + big numerals
                    VStack(spacing: 0) {
                        Text(store.timerLinkedTaskTitle.isEmpty ? "Focus" : store.timerLinkedTaskTitle)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.tempoAccent)
                            .lineLimit(1)
                        numerals
                    }
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    Spacer(minLength: 6)

                    // 4. Presets (when idle)
                    presets
                        .frame(height: 50)
                        .opacity(isIdle ? 1 : 0)
                        .allowsHitTesting(isIdle)
                        .padding(.bottom, 12)

                    // 5. Primary & contextual controls
                    controls
                        .padding(.bottom, 14)
                        .transition(.opacity)
                } else {
                    Spacer(minLength: 6)
                    suggestions
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.15), value: isIdle)
            .animation(.spring(duration: 0.4, bounce: 0.15), value: store.timerIsRunning)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: store.latestTravelResult)
            .animation(.spring(duration: 0.4, bounce: 0.12), value: inputFocused)
        }
        // 6. Chat composer docked at the bottom, it rides up with the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            taskInputBar
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
    }

    // MARK: - 1. Chat composer

    private var taskInputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: store.isCalculatingTravel ? "location.fill" : "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tempoAccent)
                .symbolEffect(.pulse, isActive: store.isCalculatingTravel)

            TextField("Tell Tempo what you're doing…", text: $draft)
                .font(.system(size: 16, weight: .medium, design: .rounded))
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
                        .font(.system(size: 28, weight: .semibold))
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
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(minHeight: 50)
        .background(
            Capsule()
                .fill(TempoSurface.card(colorScheme))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 12, y: 4)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            inputFocused ? Color.tempoAccent.opacity(0.65) : TempoSurface.border(colorScheme),
                            lineWidth: inputFocused ? 1.5 : 1
                        )
                )
        )
        .animation(.spring(duration: 0.25), value: draft.isEmpty)
    }

    /// Quick starters shown above the keyboard so a blank field is never a dead end.
    private var suggestions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestionChips, id: \.self) { chip in
                    Button {
                        draft = chip
                        submitInput()
                    } label: {
                        Text(chip)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.tempoInk)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Capsule().fill(Color.tempoInk.opacity(0.07)))
                    }
                    .buttonStyle(TempoPressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var suggestionChips: [String] {
        if store.timerIsRunning {
            return ["+5m", "+15m", "Done", "How am I doing?"]
        }
        return ["Deep work 45m", "Email 15m", "Coffee 4m", "Ride to the airport", "How am I doing?"]
    }

    private func submitInput() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.parseAndStartQuickInput(text, sessions: sessions, context: modelContext)
        draft = ""
        inputFocused = false
    }

    // MARK: - 2. Speech bubble (mascot voice + live travel)

    private var speechBubble: some View {
        Group {
            if let travel = store.latestTravelResult {
                HStack(spacing: 10) {
                    Image(systemName: travel.transportMode.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.tempoAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(travel.destinationTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.tempoInk)
                            .lineLimit(1)
                        Text("\(travel.formattedDuration) · \(travel.distanceString)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.tempoMuted)
                    }

                    Spacer(minLength: 4)

                    Button {
                        store.startTimer(
                            title: "Commute to \(travel.destinationTitle)",
                            seconds: max(1, travel.travelDurationMinutes) * 60
                        )
                        store.latestTravelResult = nil
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
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
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.tempoInk.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open in Maps")
                }
            } else {
                Text(store.mascotVoiceMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.tempoInk.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(store.mascotVoiceMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .padding(.top, SpeechBubbleShape.tailHeight)
        .background(
            SpeechBubbleShape()
                .fill(TempoSurface.card(colorScheme))
                .overlay(SpeechBubbleShape().stroke(TempoSurface.border(colorScheme), lineWidth: 1))
        )
        .animation(.spring(duration: 0.35, bounce: 0.2), value: store.mascotVoiceMessage)
    }

    // MARK: - 3. Mascot (reads live state per frame, the page does not re-render)

    private var mascot: some View {
        let typing = inputFocused || !draft.isEmpty
        return TempoInteractiveMascotView(
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
                } else if typing {
                    regime = .calibEstimating
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

/// Rounded bubble with a small tail pointing up at the mascot.
struct SpeechBubbleShape: Shape {
    static let tailHeight: CGFloat = 8
    private let radius: CGFloat = 18
    private let tailWidth: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY + Self.tailHeight, width: rect.width, height: rect.height - Self.tailHeight)
        let r = min(radius, body.height / 2, body.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        p.addLine(to: CGPoint(x: rect.midX - tailWidth / 2, y: body.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - 3, y: body.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX + tailWidth / 2, y: body.minY), control: CGPoint(x: rect.midX + 3, y: body.minY))
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

#Preview("Focus") {
    FocusInstrumentView()
}

#Preview("Focus · Dark") {
    FocusInstrumentView()
        .preferredColorScheme(.dark)
}
