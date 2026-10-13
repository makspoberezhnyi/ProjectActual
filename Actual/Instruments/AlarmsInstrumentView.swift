import SwiftUI
import SwiftData

struct AlarmsInstrumentView: View {
    @Environment(\.modelContext) private var modelContext
    private let store = TimeOSStore.shared
    @State private var showAdd = false

    init() {}

    private var ringing: TempoAlarm? {
        store.alarms.first { $0.id == store.activeRingingAlarmID }
    }

    var body: some View {
        NavigationStack {
            List {
                hero
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(store.alarms) { alarm in
                    AlarmRow(alarm: alarm) { store.toggleAlarm(alarm.id) }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.tempoInk.opacity(0.1))
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.deleteAlarm(alarm.id)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SharedBackground())
            .navigationTitle("Alarms")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New alarm", systemImage: "plus") { showAdd = true }
                        .tint(Color.tempoAccent)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddTempoAlarmSheet(store: store)
                    .presentationDetents([.large])
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                TempoAura(size: 300)
                TempoInteractiveMascotView(
                    size: 170,
                    onBodyTap: {
                        if ringing == nil, let first = store.alarms.first(where: { $0.isEnabled }) ?? store.alarms.first {
                            store.triggerAlarmPreview(first.id)
                        }
                    },
                    live: { _ in
                        if store.activeRingingAlarmID != nil {
                            return TempoMascotLive(regime: .alarmRinging)
                        }
                        if store.alarms.contains(where: { $0.snoozedUntil != nil }) {
                            return TempoMascotLive(regime: .alarmSnoozing)
                        }
                        if store.alarms.contains(where: { $0.isEnabled }) {
                            return TempoMascotLive(regime: .alarmArmed)
                        }
                        return TempoMascotLive(regime: .alarmBedtimeMoody)
                    }
                )
            }
            .frame(height: 200)

            if let alarm = ringing {
                HStack(spacing: 24) {
                    TempoRoundButton(symbol: "zzz", label: "Snooze") { store.snoozeAlarm(alarm.id) }
                    TempoRoundButton(symbol: "sunrise.fill", label: "Wake up", isPrimary: true) {
                        store.dismissAlarmAndStartRoutine(alarm, context: modelContext)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                NextAlarmCaption(alarms: store.alarms)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.4, bounce: 0.2), value: store.activeRingingAlarmID)
    }
}

private struct AlarmRow: View {
    let alarm: TempoAlarm
    let toggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(alarm.formattedTime)
                    .font(.tempoNumerals(44))
                    .foregroundStyle(alarm.isEnabled ? Color.tempoInk : Color.tempoMuted)
                HStack(spacing: 6) {
                    if alarm.isBedtimeWindDown {
                        Image(systemName: "moon.fill")
                    }
                    if alarm.chainedTaskTitle != nil {
                        Image(systemName: "link")
                    }
                    Text(alarm.label)
                }
                .font(.footnote)
                .foregroundStyle(Color.tempoMuted)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(get: { alarm.isEnabled }, set: { _ in toggle() }))
                .labelsHidden()
                .tint(Color.tempoAccent)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct NextAlarmCaption: View {
    let alarms: [TempoAlarm]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(caption(at: context.date))
                .font(.subheadline)
                .foregroundStyle(Color.tempoMuted)
        }
    }

    private func caption(at now: Date) -> String {
        let cal = Calendar.current
        let next = alarms
            .filter(\.isEnabled)
            .compactMap { cal.nextDate(after: now, matching: DateComponents(hour: $0.hour, minute: $0.minute), matchingPolicy: .nextTime) }
            .min()
        guard let next else { return "No alarms set" }
        let mins = max(1, Int(next.timeIntervalSince(now) / 60))
        return mins >= 60 ? "In \(mins / 60)h \(mins % 60)m" : "In \(mins)m"
    }
}

#Preview("Alarms") {
    AlarmsInstrumentView()
}

#Preview("Alarms · Dark") {
    AlarmsInstrumentView()
        .preferredColorScheme(.dark)
}
