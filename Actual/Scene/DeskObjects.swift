import SwiftUI
import SwiftData
import CoreLocation

// What lies on the desk in each mode. Keys you press, paper you read. Nothing floats.

private struct KeyLabel: View {
    let symbol: String
    var title: String? = nil
    var symbolSize: CGFloat = 18

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
            if let title {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Focus: five preset keys, and one big orange key in the middle

struct FocusDeskObjects: View {
    var store: TimeOSStore
    @Environment(\.modelContext) private var modelContext

    private var isIdle: Bool { !store.timerIsRunning && store.timerAccumulatedSeconds == 0 }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                ForEach(store.timerPresets) { preset in
                    let selected = store.timerTargetSeconds == preset.durationSeconds && store.timerLinkedTaskTitle == preset.title
                    Button {
                        store.selectTimerPreset(
                            title: preset.title,
                            seconds: preset.durationSeconds,
                            isRest: preset.isRestInterval,
                            isKitchen: preset.isKitchenUtility
                        )
                    } label: {
                        KeyLabel(symbol: preset.icon, title: TempoFormat.minutes(preset.durationSeconds), symbolSize: 17)
                            .foregroundStyle(selected ? TempoMascotPalette.orange : DeskKeyTone.paper.ink)
                    }
                    .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 13, latched: selected))
                    .frame(width: 56, height: 58)
                    .accessibilityLabel("\(preset.title), \(TempoFormat.minutes(preset.durationSeconds))")
                }
            }
            .opacity(isIdle ? 1 : 0.35)
            .disabled(!isIdle)

            HStack(spacing: 26) {
                Button { store.resetTimer() } label: { KeyLabel(symbol: "arrow.counterclockwise", title: "Reset") }
                    .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 30))
                    .frame(width: 60, height: 60)
                    .opacity(isIdle ? 0 : 1)
                    .disabled(isIdle)

                Button { store.toggleTimerPauseResume() } label: {
                    KeyLabel(symbol: store.timerIsRunning ? "pause.fill" : "play.fill", symbolSize: 30)
                }
                .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 44))
                .frame(width: 88, height: 88)
                .accessibilityLabel(store.timerIsRunning ? "Pause" : "Start")

                Button { store.completeAndCalibrateTimer(context: modelContext) } label: { KeyLabel(symbol: "checkmark", title: "Done") }
                    .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 30))
                    .frame(width: 60, height: 60)
                    .opacity(isIdle ? 0 : 1)
                    .disabled(isIdle)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: isIdle)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Alarms: a stack of alarm cards and two keys

struct AlarmDeskObjects: View {
    var store: TimeOSStore
    @State private var showAdd = false
    @State private var editing: TempoAlarm?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { showAdd = true } label: { KeyLabel(symbol: "plus", title: "New") }
                    .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 14))
                    .frame(width: 64, height: 54)
                Button {
                    if let next = store.nextAlarmFire()?.alarm ?? store.alarms.first { store.triggerAlarmPreview(next.id) }
                } label: { KeyLabel(symbol: "bell.and.waves.left.and.right", title: "Hear it") }
                    .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 14))
                    .frame(width: 64, height: 54)
                    .disabled(store.alarms.isEmpty)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(store.alarms) { alarm in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(alarm.formattedTime)
                                    .font(.tempoNumerals(28))
                                    .foregroundStyle(alarm.isEnabled ? Color.tempoInk : Color.tempoMuted)
                                HStack(spacing: 5) {
                                    if alarm.isBedtimeWindDown { Image(systemName: "moon.fill") }
                                    if alarm.chainedTaskTitle != nil { Image(systemName: "link") }
                                    Text("\(alarm.label) · \(alarm.repeatSummary)").lineLimit(1)
                                }
                                .font(.caption)
                                .foregroundStyle(Color.tempoMuted)
                                if let until = alarm.snoozedUntil, until > Date() {
                                    Text("Snoozed until \(until, format: .dateTime.hour().minute())")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(TempoMascotPalette.orange)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = alarm }
                            Toggle("On", isOn: Binding(get: { alarm.isEnabled }, set: { _ in store.toggleAlarm(alarm.id) }))
                                .labelsHidden()
                                .tint(TempoMascotPalette.orange)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .deskPaper()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 6)
        .sheet(isPresented: $showAdd) {
            AddTempoAlarmSheet(store: store)
        }
        .sheet(item: $editing) { alarm in
            AddTempoAlarmSheet(store: store, editing: alarm)
        }
    }
}

// MARK: - Stopwatch: black key and orange key, just like the clock's ears, and a paper strip of laps

struct StopwatchDeskObjects: View {
    var store: TimeOSStore
    @Environment(\.modelContext) private var modelContext
    @State private var showSave = false
    @State private var saveTitle = ""

    var body: some View {
        let elapsed = store.chronoTotalElapsed()
        VStack(spacing: 16) {
            HStack(spacing: 30) {
                Button { store.pressChronoLeftEar() } label: {
                    KeyLabel(symbol: store.chronoIsRunning ? "flag.fill" : "arrow.counterclockwise",
                             title: store.chronoIsRunning ? "Lap" : "Reset")
                }
                .buttonStyle(DeskKeyStyle(tone: .carbon, cornerRadius: 34))
                .frame(width: 68, height: 68)
                .disabled(!store.chronoIsRunning && elapsed == 0)

                Button { store.toggleChronoStartStop() } label: {
                    KeyLabel(symbol: store.chronoIsRunning ? "pause.fill" : "play.fill", symbolSize: 30)
                }
                .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 44))
                .frame(width: 88, height: 88)

                Button {
                    saveTitle = ""
                    showSave = true
                } label: { KeyLabel(symbol: "tray.and.arrow.down.fill", title: "Save") }
                .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 34))
                .frame(width: 68, height: 68)
                .opacity(!store.chronoIsRunning && elapsed >= 1 ? 1 : 0)
                .disabled(store.chronoIsRunning || elapsed < 1)
            }

            if !store.chronoLaps.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.chronoLaps) { lap in
                            HStack {
                                Text("Lap \(lap.lapNumber)").foregroundStyle(Color.tempoMuted)
                                Spacer()
                                Text(TempoFormat.stopwatch(lap.splitSeconds)).foregroundStyle(Color.tempoInk)
                            }
                            .font(.system(.subheadline, design: .monospaced))
                            .padding(.vertical, 5)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .deskPaper(cornerRadius: 6)
                    .padding(.horizontal, 60)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: store.chronoIsRunning)
        .alert("What was this?", isPresented: $showSave) {
            TextField("Task name", text: $saveTitle)
            Button("Save") {
                let total = store.chronoTotalElapsed()
                store.pressChronoLeftEar()
                store.claimChronoAsCalibratedTask(
                    title: saveTitle.isEmpty ? "Stopwatch run" : saveTitle,
                    estimatedMinutes: max(1, Int((total / 60).rounded())),
                    actualSeconds: total,
                    context: modelContext
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Tempo logs it so it learns how long this really takes.")
        }
    }
}

// MARK: - World: a postcard per city, each with a tiny clock showing its hour

struct WorldDeskObjects: View {
    var store: TimeOSStore
    @State private var showAdd = false
    @State private var locating = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { showAdd = true } label: { KeyLabel(symbol: "plus", title: "City") }
                    .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 14))
                    .frame(width: 64, height: 54)
                Button(action: addCurrentCity) {
                    KeyLabel(symbol: locating ? "location.circle" : "location.fill", title: "Here")
                }
                .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 14))
                .frame(width: 64, height: 54)
            }

            ScrollView {
                TimelineView(.everyMinute) { context in
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(store.worldCities) { city in
                            postcard(city, at: context.date)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 6)
        .sheet(isPresented: $showAdd) {
            AddWorldCitySheet(store: store)
        }
    }

    private func postcard(_ city: TempoWorldCity, at now: Date) -> some View {
        let c = city.localComponents(at: now)
        let h = Double(c.hour ?? 12), m = Double(c.minute ?? 0)
        return HStack(spacing: 8) {
            TempoWatchMascotView(
                regime: city.isMoodyNight(at: now) ? .worldRemoteNight : .worldLocalDay,
                size: 40,
                animated: false,
                overrideMinuteAngle: m * 6,
                overrideHourAngle: h.truncatingRemainder(dividingBy: 12) * 30 + m * 0.5
            )
            VStack(alignment: .leading, spacing: 0) {
                Text(city.cityName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.tempoInk)
                    .lineLimit(1)
                Text(city.formattedLocalTime(at: now))
                    .font(.system(size: 15, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.tempoInk)
                Text(city.hoursOffsetString(at: now))
                    .font(.caption2)
                    .foregroundStyle(Color.tempoMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .deskPaper(cornerRadius: 10)
        .contextMenu {
            Button("Timer until their 9 AM", systemImage: "timer") { store.startOverlapCountdown(for: city) }
            Button("Remove", systemImage: "trash", role: .destructive) { store.removeWorldCity(city.id) }
        }
    }

    private func addCurrentCity() {
        locating = true
        LocationTravelManager.shared.requestAuthorization()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            let loc = LocationTravelManager.shared.effectiveLocation
            if let place = try? await CLGeocoder().reverseGeocodeLocation(loc).first {
                let name = place.locality ?? place.subAdministrativeArea ?? place.name ?? "My Location"
                let tz = place.timeZone?.identifier ?? TimeZone.current.identifier
                if !store.worldCities.contains(where: { $0.cityName.lowercased() == name.lowercased() }) {
                    store.addWorldCity(name: name, tzIdentifier: tz, note: place.country ?? "")
                }
            } else {
                let tz = TimeZone.current.identifier
                let name = tz.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "Local Time"
                if !store.worldCities.contains(where: { $0.cityName.lowercased() == name.lowercased() }) {
                    store.addWorldCity(name: name, tzIdentifier: tz, note: "Current Time Zone")
                }
            }
            locating = false
        }
    }
}

// MARK: - Logbook: three notes on the desk and the notebook itself

struct LogbookDeskObjects: View {
    var sessions: [Session]
    var calibrationScore: Double
    @State private var open = false

    private var finishedToday: [Session] {
        sessions.filter { $0.isActualTask && $0.endedAt != nil && Calendar.current.isDateInToday($0.startedAt ?? .distantPast) }
    }

    var body: some View {
        let minutes = finishedToday.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                note("Today", TempoFormat.minutes(minutes * 60))
                note("Blocks", "\(finishedToday.count)")
                note("On target", "\(Int((calibrationScore * 100).rounded()))%")
            }
            .padding(.horizontal, 24)

            Button { open = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill").font(.system(size: 22, weight: .semibold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open logbook").font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("History, insights, settings").font(.system(size: 11, weight: .medium, design: .rounded)).opacity(0.75)
                    }
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 16))
            .frame(width: 250, height: 66)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $open) {
            LogbookInstrumentView(sessions: sessions, calibrationScore: calibrationScore)
        }
    }

    private func note(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.tempoInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1)
                .foregroundStyle(TempoMascotPalette.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .deskPaper(cornerRadius: 8)
    }
}

// MARK: - Ringing: the keys that replace the desk objects while an alarm or timer rings

struct RingingProps: View {
    var store: TimeOSStore
    @Environment(\.modelContext) private var modelContext

    private var alarm: TempoAlarm? { store.alarms.first { $0.id == store.activeRingingAlarmID } }

    var body: some View {
        VStack(spacing: 18) {
            if let alarm {
                HStack(spacing: 24) {
                    if !store.ringingIsPreview {
                        Button { store.snoozeAlarm(alarm.id) } label: { KeyLabel(symbol: "zzz", title: "Snooze", symbolSize: 22) }
                            .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 40))
                            .frame(width: 80, height: 80)
                    }
                    Button { store.stopAlarm(alarm.id) } label: { KeyLabel(symbol: "stop.fill", title: "Stop", symbolSize: 28) }
                        .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 48))
                        .frame(width: 96, height: 96)
                }
                if let chain = alarm.chainedTaskTitle, !store.ringingIsPreview {
                    Button { store.dismissAlarmAndStartRoutine(alarm, context: modelContext) } label: {
                        Label("Start \(chain) · \(alarm.chainedTaskMinutes ?? 20)m", systemImage: "sunrise.fill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 14))
                    .frame(height: 50)
                }
            } else {
                HStack(spacing: 24) {
                    Button { store.extendTimer(bySeconds: 5 * 60) } label: { KeyLabel(symbol: "plus", title: "5 min", symbolSize: 22) }
                        .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 40))
                        .frame(width: 80, height: 80)
                    Button { store.completeAndCalibrateTimer(context: modelContext) } label: { KeyLabel(symbol: "checkmark", title: "Done", symbolSize: 28) }
                        .buttonStyle(DeskKeyStyle(tone: .orange, cornerRadius: 48))
                        .frame(width: 96, height: 96)
                }
                Button { store.silenceTimerAlert() } label: {
                    Text("Keep going").font(.system(size: 15, weight: .semibold, design: .rounded)).padding(.horizontal, 18)
                }
                .buttonStyle(DeskKeyStyle(tone: .paper, cornerRadius: 14))
                .frame(height: 46)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
