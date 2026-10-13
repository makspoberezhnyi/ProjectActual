import SwiftUI
import SwiftData
import UIKit

struct AlarmsInstrumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    private let store = TimeOSStore.shared
    @State private var showAdd = false
    @State private var editing: TempoAlarm?
    @State private var canRing = true

    init() {}

    var body: some View {
        NavigationStack {
            List {
                hero
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if !canRing {
                    permissionHint
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                ForEach(store.alarms) { alarm in
                    AlarmRow(
                        alarm: alarm,
                        toggle: { store.toggleAlarm(alarm.id) },
                        edit: { editing = alarm }
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.tempoInk.opacity(0.1))
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.deleteAlarm(alarm.id)
                        }
                    }
                }

                if store.alarms.isEmpty {
                    Text("No alarms yet. Tap + to set one.")
                        .font(.subheadline)
                        .foregroundStyle(Color.tempoMuted)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
            .sheet(item: $editing) { alarm in
                AddTempoAlarmSheet(store: store, editing: alarm)
                    .presentationDetents([.large])
            }
            .task { await refreshPermission() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshPermission() } }
            }
        }
    }

    private func refreshPermission() async {
        await NotificationManager.shared.checkAuthorizationStatus()
        canRing = TempoAlarmScheduler.shared.usesSystemAlarms || NotificationManager.shared.isAuthorized
    }

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                TempoInteractiveMascotView(
                    size: 170,
                    onBodyTap: {
                        if let first = store.nextAlarmFire()?.alarm ?? store.alarms.first {
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
                .standingOnDesk(mascotSize: 170, depth: 56, reach: 600)
            }
            .frame(height: 200, alignment: .bottom)

            MascotSpeechBubble(text: store.mascotVoiceMessage)
                .padding(.horizontal, 28)
            NextAlarmCaption()
                .padding(.top, 2)
            // The desk's front edge closes the hero; the alarm list sits below the table.
            DeskFront()
                .frame(height: 30)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var permissionHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.tempoAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Alarms can't ring yet")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.tempoInk)
                Text("Allow alarms and notifications for Tempo in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Color.tempoMuted)
            }
            Spacer(minLength: 4)
            Button("Open") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .tint(Color.tempoAccent)
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.tempoAccent.opacity(0.1)))
    }
}

private struct AlarmRow: View {
    let alarm: TempoAlarm
    let toggle: () -> Void
    let edit: () -> Void

    var body: some View {
        HStack {
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
                        Text("\(alarm.label) · \(alarm.repeatSummary)")
                            .lineLimit(1)
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.tempoMuted)

                    if let until = alarm.snoozedUntil, until > Date() {
                        Label {
                            Text("Snoozed until \(until, format: .dateTime.hour().minute())")
                        } icon: {
                            Image(systemName: "zzz")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.tempoAccent)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: edit)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Double tap to edit")

            Toggle("Enabled", isOn: Binding(get: { alarm.isEnabled }, set: { _ in toggle() }))
                .labelsHidden()
                .tint(Color.tempoAccent)
        }
        .padding(.vertical, 6)
    }
}

private struct NextAlarmCaption: View {
    private let store = TimeOSStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(caption(at: context.date))
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Color.tempoInk.opacity(0.8))
        }
    }

    private func caption(at now: Date) -> String {
        guard let next = store.nextAlarmFire(after: now) else { return "No alarms set" }
        let mins = max(1, Int(ceil(next.date.timeIntervalSince(now) / 60)))
        let span: String
        if mins >= 24 * 60 {
            span = "\(mins / (24 * 60))d \((mins % (24 * 60)) / 60)h"
        } else if mins >= 60 {
            span = "\(mins / 60)h \(mins % 60)m"
        } else {
            span = "\(mins)m"
        }
        return "\(next.alarm.label) rings in \(span)"
    }
}

#Preview("Alarms") {
    AlarmsInstrumentView()
}

#Preview("Alarms · Dark") {
    AlarmsInstrumentView()
        .preferredColorScheme(.dark)
}
