import SwiftUI
import SwiftData

struct StopwatchInstrumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var store = TimeOSStore.shared
    @State private var showSave = false
    @State private var saveTitle = ""

    init() {}

    private var canSave: Bool { !store.chronoIsRunning && store.chronoTotalElapsed() >= 1 }

    private var hasTime: Bool { store.chronoIsRunning || store.chronoTotalElapsed() > 0 }

    var body: some View {
        ZStack {
            SharedBackground()
            VStack(spacing: 0) {
                ZStack {
                    TempoAura()
                    mascot
                }
                .frame(height: 245)
                .padding(.top, 16)

                readout
                    .padding(.top, 4)

                controls
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                if canSave {
                    Button {
                        saveTitle = ""
                        showSave = true
                    } label: {
                        Label("Save to logbook", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.tempoAccent)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Capsule().fill(Color.tempoAccent.opacity(0.12)))
                    }
                    .buttonStyle(TempoPressStyle())
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }

                laps
            }
            .animation(.spring(duration: 0.35, bounce: 0.15), value: hasTime)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: store.chronoIsRunning)
        }
        .alert("What was this?", isPresented: $showSave) {
            TextField("Task name", text: $saveTitle)
            Button("Save") {
                let total = store.chronoTotalElapsed()
                store.claimChronoAsCalibratedTask(
                    title: saveTitle.isEmpty ? "Stopwatch run" : saveTitle,
                    estimatedMinutes: max(1, Int((total / 60).rounded())),
                    actualSeconds: total,
                    context: modelContext
                )
                store.pressChronoLeftEar()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tempo logs it so it learns how long this really takes.")
        }
    }

    private var mascot: some View {
        TempoInteractiveMascotView(
            size: 210,
            providesMinuteAngle: true,
            onLeftEarTap: { store.pressChronoLeftEar() },
            onRightEarTap: { store.toggleChronoStartStop() },
            live: { now in
                let total = store.chronoTotalElapsed(at: now)
                let regime: TempoMascotRegime = store.chronoIsRunning ? .chronoRunning
                    : (total > 0 ? .chronoPaused : .chronoZeroed)
                return TempoMascotLive(
                    regime: regime,
                    minuteAngle: total.truncatingRemainder(dividingBy: 60) * 6
                )
            }
        )
    }

    private var readout: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !store.chronoIsRunning)) { context in
            VStack(spacing: 2) {
                Text(TempoFormat.stopwatch(store.chronoTotalElapsed(at: context.date)))
                    .font(.tempoNumerals(64))
                    .foregroundStyle(Color.tempoInk)
                Text(TempoFormat.stopwatch(store.chronoCurrentLapElapsed(at: context.date)))
                    .font(.tempoNumerals(20))
                    .foregroundStyle(Color.tempoMuted)
                    .opacity(store.chronoLaps.isEmpty ? 0 : 1)
            }
        }
        .contextMenu {
            Button("Save as session", systemImage: "tray.and.arrow.down") {
                let total = store.chronoTotalElapsed()
                store.claimChronoAsCalibratedTask(
                    title: "Stopwatch run",
                    estimatedMinutes: max(1, Int((total / 60).rounded())),
                    actualSeconds: total,
                    context: modelContext
                )
            }
            .disabled(store.chronoTotalElapsed() < 1)
        }
        .accessibilityElement()
        .accessibilityLabel("Elapsed time")
        .accessibilityValue(TempoFormat.stopwatch(store.chronoTotalElapsed()))
    }

    private var controls: some View {
        HStack(spacing: 28) {
            if hasTime {
                TempoRoundButton(
                    symbol: store.chronoIsRunning ? "flag.fill" : "arrow.counterclockwise",
                    label: store.chronoIsRunning ? "Lap" : "Reset"
                ) { store.pressChronoLeftEar() }
                    .transition(.scale.combined(with: .opacity))
            }

            TempoRoundButton(
                symbol: store.chronoIsRunning ? "pause.fill" : "play.fill",
                label: store.chronoIsRunning ? "Stop" : "Start",
                isPrimary: true
            ) { store.toggleChronoStartStop() }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
    }

    private var laps: some View {
        List(store.chronoLaps) { lap in
            HStack {
                Text("Lap \(lap.lapNumber)")
                    .foregroundStyle(Color.tempoMuted)
                    .frame(width: 68, alignment: .leading)
                Text(TempoFormat.stopwatch(lap.splitSeconds))
                    .foregroundStyle(Color.tempoInk)
                Spacer()
                Text(TempoFormat.stopwatch(lap.totalSeconds))
                    .foregroundStyle(Color.tempoMuted)
            }
            .font(.system(.body, design: .rounded).monospacedDigit())
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Color.tempoInk.opacity(0.1))
            .swipeActions {
                Button("Save", systemImage: "tray.and.arrow.down") {
                    store.claimChronoAsCalibratedTask(
                        title: "Lap \(lap.lapNumber)",
                        estimatedMinutes: max(1, Int((lap.splitSeconds / 60).rounded())),
                        actualSeconds: lap.splitSeconds,
                        lapID: lap.id,
                        context: modelContext
                    )
                }
                .tint(Color.tempoAccent)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview("Stopwatch") {
    StopwatchInstrumentView()
}

#Preview("Stopwatch · Dark") {
    StopwatchInstrumentView()
        .preferredColorScheme(.dark)
}
