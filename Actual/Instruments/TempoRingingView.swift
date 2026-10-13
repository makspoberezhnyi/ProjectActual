import SwiftUI
import SwiftData

/// Full-screen takeover while an alarm rings or a timer hits zero.
/// The mascot is the alarm: bells shaking for alarms, chime pulse for timers.
struct TempoRingingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var store = TimeOSStore.shared
    @State private var pulse = false

    private var alarm: TempoAlarm? {
        store.alarms.first { $0.id == store.activeRingingAlarmID }
    }

    var body: some View {
        ZStack {
            SharedBackground()

            TempoAura(size: 520)
                .scaleEffect(pulse ? 1.12 : 0.92)
                .opacity(pulse ? 1 : 0.6)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

            VStack(spacing: 0) {
                Text(alarm != nil ? "ALARM" : "TIMER")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Color.tempoAccent)
                    .padding(.top, 24)

                Spacer(minLength: 12)

                TempoInteractiveMascotView(
                    size: 250,
                    onBodyTap: silence,
                    live: { _ in
                        TempoMascotLive(regime: store.activeRingingAlarmID != nil ? .alarmRinging : .timerComplete)
                    }
                )
                .standingOnDesk(mascotSize: 250, depth: 72)
                .frame(height: 270, alignment: .bottom)

                headline
                    .padding(.top, 8)

                Spacer(minLength: 24)

                Group {
                    if let alarm {
                        alarmControls(alarm)
                    } else {
                        timerControls
                    }
                }
                .deskFrontEdge(gap: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear { pulse = true }
        .interactiveDismissDisabled()
    }

    // MARK: - Headline

    @ViewBuilder
    private var headline: some View {
        if let alarm {
            VStack(spacing: 4) {
                TimelineView(.everyMinute) { context in
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.tempoNumerals(76))
                        .foregroundStyle(Color.tempoInk)
                }
                Text(alarm.label)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.tempoMuted)
                if store.ringingIsPreview {
                    Text("Sound check")
                        .font(.footnote)
                        .foregroundStyle(Color.tempoMuted)
                }
            }
        } else {
            VStack(spacing: 4) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let over = max(0, -store.timerRemaining(at: context.date))
                    Text("+" + TempoFormat.clock(over))
                        .font(.tempoNumerals(76))
                        .foregroundStyle(Color.tempoAccent)
                        .contentTransition(.numericText())
                }
                Text("Time's up · \(store.timerLinkedTaskTitle)")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.tempoInk)
                    .lineLimit(1)
                Text("Overtime counts too. It makes your estimates smarter.")
                    .font(.footnote)
                    .foregroundStyle(Color.tempoMuted)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Controls

    private func alarmControls(_ alarm: TempoAlarm) -> some View {
        VStack(spacing: 14) {
            if let chain = alarm.chainedTaskTitle, !store.ringingIsPreview {
                Button {
                    store.dismissAlarmAndStartRoutine(alarm, context: modelContext)
                } label: {
                    Label("Start \(chain) · \(alarm.chainedTaskMinutes ?? 20)m", systemImage: "sunrise.fill")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.tempoAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().strokeBorder(Color.tempoAccent.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(TempoPressStyle())
            }

            HStack(spacing: 14) {
                if !store.ringingIsPreview {
                    pillButton("Snooze", symbol: "zzz", primary: false) {
                        store.snoozeAlarm(alarm.id)
                    }
                }
                pillButton("Stop", symbol: "stop.fill", primary: true) {
                    store.stopAlarm(alarm.id)
                }
            }
        }
    }

    private var timerControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                pillButton("+5 min", symbol: "plus", primary: false) {
                    store.extendTimer(bySeconds: 5 * 60)
                }
                pillButton("Done & log", symbol: "checkmark", primary: true) {
                    store.completeAndCalibrateTimer(context: modelContext)
                }
            }
            Button("Keep going") { store.silenceTimerAlert() }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.tempoMuted)
                .frame(height: 36)
        }
    }

    private func pillButton(_ title: LocalizedStringKey, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(primary ? Color.white : Color.tempoInk)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Capsule().fill(primary ? Color.tempoAccent : Color.tempoInk.opacity(0.08)))
        }
        .buttonStyle(TempoPressStyle())
    }

    private func silence() {
        if let id = store.activeRingingAlarmID {
            if store.ringingIsSystemAlarm || store.ringingIsPreview {
                store.stopAlarm(id)
            } else {
                // Tapping the mascot quiets the bells but keeps the screen up.
                TempoSoundEngine.shared.stopRinging()
            }
        } else {
            store.silenceTimerAlert()
        }
    }
}

#Preview("Ringing") {
    TempoRingingView()
}
