import SwiftUI
import WatchKit

// Tempo on the wrist: the same desk clock as the phone, one page per mode.
// Scroll the Digital Crown (or swipe up) to move between Focus, Stopwatch, Alarms and World.

private enum WatchLook {
    static let orange = TempoMascotPalette.orange
    static let wall = Color(red: 0.067, green: 0.094, blue: 0.169)          // #11182B, like the phone in dark mode
    static let desk = Color(red: 0.227, green: 0.184, blue: 0.153)          // walnut #3A2F27
    static let deskFar = Color(red: 0.173, green: 0.141, blue: 0.118)       // #2C241E
    static let deskEdge = Color(red: 0.118, green: 0.094, blue: 0.078)      // #1E1814
    static let deskLip = Color(red: 0.318, green: 0.267, blue: 0.227)       // #51443A
    static let muted = Color(red: 0.62, green: 0.68, blue: 0.79)

    static func numerals(_ size: CGFloat) -> Font { .system(size: size, weight: .light, design: .rounded).monospacedDigit() }
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

struct WatchRootView: View {
    @State private var store = WatchSessionStore.shared
    @State private var page = 0
    @State private var showCustomSheet = false
    @State private var countdownTitle: String?
    @State private var countdownMinutes = 25

    var body: some View {
        NavigationStack {
            ZStack {
                if let title = countdownTitle {
                    FitnessCountdownView(
                        title: title,
                        minutes: countdownMinutes,
                        onComplete: {
                            let mins = countdownMinutes
                            countdownTitle = nil
                            store.startSession(title: title, minutes: mins)
                        },
                        onCancel: { countdownTitle = nil }
                    )
                    .transition(.opacity)
                } else {
                    TabView(selection: $page) {
                        WatchFocusPage(store: store, onStart: startWithCountdown, onCustom: { showCustomSheet = true })
                            .tag(0)
                        WatchStopwatchPage(store: store)
                            .tag(1)
                        WatchAlarmsPage(store: store)
                            .tag(2)
                        WatchWorldPage(store: store)
                            .tag(3)
                    }
                    .tabViewStyle(.verticalPage)
                }
            }
            .sheet(isPresented: $showCustomSheet) {
                CustomFocusSheet { title, minutes in
                    showCustomSheet = false
                    startWithCountdown(title: title, minutes: minutes)
                }
            }
        }
        .onAppear { store.activate() }
    }

    private func startWithCountdown(title: String, minutes: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            countdownMinutes = minutes
            countdownTitle = title
        }
    }
}

// MARK: - The desk

/// The clock standing on a strip of walnut desk with a rounded front edge.
struct WatchClockOnDesk: View {
    let regime: TempoMascotRegime
    var size: CGFloat = 76
    var bezel: Double? = nil
    var minuteAngle: Double? = nil
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        let footFromTop = size * 254.0 / 268.0
        let deskTop = footFromTop - size * 0.22
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                LinearGradient(colors: [WatchLook.deskFar, WatchLook.desk], startPoint: .top, endPoint: .bottom)
                    .frame(height: size + 10 - deskTop)
                Rectangle().fill(WatchLook.deskLip).frame(height: 1.5)
                Rectangle().fill(WatchLook.deskEdge).frame(height: 7)
            }
            .offset(y: deskTop)
            .opacity(dimmed ? 0.35 : 1)

            TempoWatchMascotView(
                regime: regime,
                size: size,
                animated: !dimmed,
                overrideMinuteAngle: minuteAngle,
                overrideBezelProgress: bezel
            )
        }
        .frame(height: size + 18.5, alignment: .top)
        .frame(maxWidth: .infinity)
    }
}

private struct WatchPageBackground: View {
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        (dimmed ? Color.black : WatchLook.wall).ignoresSafeArea()
    }
}

private struct WatchPageTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(WatchLook.orange)
    }
}

// MARK: - 1. Focus

struct WatchFocusPage: View {
    var store: WatchSessionStore
    let onStart: (String, Int) -> Void
    let onCustom: () -> Void
    @Environment(\.isLuminanceReduced) private var dimmed

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if let end = store.timerEnd, let start = store.startDate {
                    running(start: start, end: end)
                } else {
                    idle
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .containerBackground(for: .tabView) { WatchPageBackground() }
        .navigationTitle("Focus")
    }

    private func running(start: Date, end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let total = max(1, end.timeIntervalSince(start))
            let left = end.timeIntervalSince(context.date)
            VStack(spacing: 6) {
                WatchClockOnDesk(
                    regime: left < 0 ? .calibOvertime : .timerActiveCountdown,
                    bezel: left < 0 ? 1 : max(0.04, left / total)
                )
                Text(store.taskTitle)
                    .font(WatchLook.title(13))
                    .foregroundStyle(dimmed ? .secondary : .primary)
                    .lineLimit(1)
                // Counts down, then up: honest overtime.
                Text(end, style: .timer)
                    .font(WatchLook.numerals(34))
                    .foregroundStyle(left < 0 ? WatchLook.orange : .white)
                if !dimmed {
                    HStack(spacing: 8) {
                        Button("+5") { store.extendSession(by: 5) }
                            .tint(.gray)
                        Button {
                            store.stopSession()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .tint(WatchLook.orange)
                    }
                    .font(WatchLook.title(15))
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var idle: some View {
        VStack(spacing: 6) {
            WatchClockOnDesk(regime: .timerDialing)
            WatchPageTitle(text: "What's next?")
            if store.todayMinutes > 0 {
                Text("\(store.todayMinutes)m logged today")
                    .font(.footnote)
                    .foregroundStyle(WatchLook.muted)
            }
            ForEach(store.quickTasks, id: \.self) { task in
                Button {
                    onStart(task.title, task.minutes)
                } label: {
                    HStack {
                        Image(systemName: "play.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(WatchLook.orange)
                        Text(task.title).font(WatchLook.title(14)).lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(task.minutes)m").font(WatchLook.title(13)).foregroundStyle(WatchLook.muted)
                    }
                }
            }
            Button(action: onCustom) {
                Label("Something else", systemImage: "plus")
                    .font(WatchLook.title(14))
            }
            .tint(WatchLook.orange)
        }
    }
}

// MARK: - 2. Stopwatch

struct WatchStopwatchPage: View {
    var store: WatchSessionStore
    @Environment(\.isLuminanceReduced) private var dimmed
    @State private var showSave = false
    @State private var runTitle = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: dimmed || !store.chronoRunning ? 1 : 0.05)) { context in
            let elapsed = store.chronoElapsed(at: context.date)
            VStack(spacing: 6) {
                WatchClockOnDesk(
                    regime: store.chronoRunning ? .chronoRunning : (elapsed > 0 ? .chronoPaused : .chronoZeroed),
                    size: 70,
                    minuteAngle: elapsed.truncatingRemainder(dividingBy: 60) * 6
                )
                Text(format(elapsed))
                    .font(WatchLook.numerals(30))
                    .foregroundStyle(.white)
                if !dimmed {
                    // Same layout as the mascot's ears: black on the left, orange on the right.
                    HStack(spacing: 8) {
                        Button {
                            store.lapOrResetChrono()
                        } label: {
                            Image(systemName: store.chronoRunning ? "flag.fill" : "arrow.counterclockwise")
                        }
                        .tint(.gray)
                        .disabled(!store.chronoRunning && elapsed == 0)
                        Button {
                            store.toggleChrono()
                        } label: {
                            Image(systemName: store.chronoRunning ? "pause.fill" : "play.fill")
                        }
                        .tint(WatchLook.orange)
                    }
                    .buttonStyle(.borderedProminent)
                }
                if !dimmed && !store.chronoRunning && elapsed >= 1 {
                    Button {
                        runTitle = ""
                        showSave = true
                    } label: {
                        Label("Save", systemImage: "tray.and.arrow.down.fill")
                            .font(WatchLook.title(13))
                    }
                    .tint(WatchLook.orange)
                } else if let last = store.chronoLaps.first {
                    Text("Lap \(store.chronoLaps.count) · \(format(last))")
                        .font(.footnote)
                        .foregroundStyle(WatchLook.muted)
                }
            }
            .padding(.horizontal, 6)
        }
        .sheet(isPresented: $showSave) {
            VStack(spacing: 8) {
                Text("What was this?")
                    .font(WatchLook.title(14))
                TextField("Run, study, cooking…", text: $runTitle)
                Button {
                    store.saveStopwatchRun(title: runTitle)
                    showSave = false
                } label: {
                    Label("Save to logbook", systemImage: "checkmark")
                        .font(WatchLook.title(13))
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchLook.orange)
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(for: .tabView) { WatchPageBackground() }
        .navigationTitle("Stopwatch")
    }

    private func format(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60, c = Int((t - floor(t)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, c)
    }
}

// MARK: - 3. Alarms

struct WatchAlarmsPage: View {
    var store: WatchSessionStore

    private var regime: TempoMascotRegime {
        guard store.nextAlarmDate != nil else { return .alarmBedtimeMoody }
        return store.nextAlarmBedtime ? .alarmBedtimeMoody : .alarmArmed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                WatchClockOnDesk(regime: regime)
                if let date = store.nextAlarmDate, date > Date() {
                    WatchPageTitle(text: store.nextAlarmLabel ?? "Next alarm")
                    Text(date, style: .time)
                        .font(WatchLook.numerals(34))
                        .foregroundStyle(.white)
                    Text(date, style: .relative)
                        .font(.footnote)
                        .foregroundStyle(WatchLook.muted)
                } else {
                    WatchPageTitle(text: "Alarms")
                    Text("No alarms on")
                        .font(WatchLook.title(15))
                }
                ForEach(store.alarms) { alarm in
                    HStack(spacing: 6) {
                        NavigationLink(value: alarm) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(alarm.time).font(WatchLook.numerals(20))
                                Text("\(alarm.label) · \(alarm.repeatText)")
                                    .font(.caption2)
                                    .foregroundStyle(WatchLook.muted)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Toggle("", isOn: Binding(
                            get: { alarm.enabled },
                            set: { store.setAlarmEnabled(alarm, $0) }
                        ))
                        .labelsHidden()
                        .tint(WatchLook.orange)
                        .frame(width: 44)
                    }
                    .opacity(alarm.enabled ? 1 : 0.6)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                }
                NavigationLink {
                    WatchAlarmEditor(store: store, alarm: nil)
                } label: {
                    Label("New alarm", systemImage: "plus")
                        .font(WatchLook.title(14))
                }
                .tint(WatchLook.orange)
                .padding(.top, 2)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .containerBackground(for: .tabView) { WatchPageBackground() }
        .navigationTitle("Alarms")
        .navigationDestination(for: WatchAlarm.self) { alarm in
            WatchAlarmEditor(store: store, alarm: alarm)
        }
    }
}

/// Set the time with the crown, rename, switch off or delete. The iPhone schedules the real alarm.
struct WatchAlarmEditor: View {
    var store: WatchSessionStore
    let alarm: WatchAlarm?
    @Environment(\.dismiss) private var dismiss

    @State private var hour = 7
    @State private var minute = 0
    @State private var label = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    Text(":").font(WatchLook.numerals(24))
                    Picker("Minute", selection: $minute) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 70)

                TextField("Label", text: $label)
                    .font(WatchLook.title(13))

                Button {
                    store.saveAlarm(id: alarm?.id, hour: hour, minute: minute, label: label)
                    dismiss()
                } label: {
                    Label(alarm == nil ? "Add alarm" : "Save", systemImage: "checkmark")
                        .font(WatchLook.title(14))
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchLook.orange)

                if let alarm {
                    Button(role: .destructive) {
                        store.deleteAlarm(id: alarm.id)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(WatchLook.title(13))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(alarm == nil ? "New alarm" : "Edit alarm")
        .onAppear {
            if let alarm {
                hour = alarm.hour
                minute = alarm.minute
                label = alarm.label
            }
        }
    }
}

// MARK: - 4. World

struct WatchWorldPage: View {
    var store: WatchSessionStore

    var body: some View {
        ScrollView {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 6) {
                    WatchClockOnDesk(regime: .worldDualGMT)
                    WatchPageTitle(text: "World")
                    if store.cities.isEmpty {
                        Text("Add cities on your iPhone")
                            .font(.footnote)
                            .foregroundStyle(WatchLook.muted)
                    }
                    ForEach(store.cities) { city in
                        cityRow(city, at: context.date)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
        .containerBackground(for: .tabView) { WatchPageBackground() }
        .navigationTitle("World")
    }

    private func cityRow(_ city: WatchCity, at now: Date) -> some View {
        var cal = Calendar.current
        cal.timeZone = city.timeZone
        let c = cal.dateComponents([.hour, .minute], from: now)
        let h = Double(c.hour ?? 0), m = Double(c.minute ?? 0)
        let night = (c.hour ?? 12) >= 22 || (c.hour ?? 12) < 6
        return HStack(spacing: 8) {
            // A tiny clock showing that city's hour, sleepy at night.
            TempoWatchMascotView(
                regime: night ? .worldRemoteNight : .worldLocalDay,
                size: 30,
                animated: false,
                overrideMinuteAngle: m * 6,
                overrideHourAngle: h.truncatingRemainder(dividingBy: 12) * 30 + m * 0.5
            )
            Text(city.name).font(WatchLook.title(14)).lineLimit(1)
            Spacer(minLength: 2)
            Text(now, format: Date.FormatStyle(date: .omitted, time: .shortened, timeZone: city.timeZone))
                .font(WatchLook.numerals(16))
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
    }
}

// MARK: - 3-2-1 countdown before a block

struct FitnessCountdownView: View {
    let title: String
    let minutes: Int
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var count = 3
    @State private var scale: CGFloat = 0.6
    @State private var ringTrim: CGFloat = 0

    var body: some View {
        ZStack {
            WatchLook.wall.ignoresSafeArea()
            VStack(spacing: 8) {
                Text(title)
                    .font(WatchLook.title(13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                ZStack {
                    Circle()
                        .stroke(WatchLook.orange.opacity(0.2), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(WatchLook.orange, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(count)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchLook.orange)
                        .scaleEffect(scale)
                }
                .frame(width: 96, height: 96)
                .padding(.vertical, 4)
                Text("Tap to skip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            WKInterfaceDevice.current().play(.start)
            onComplete()
        }
        .task { await runCountdown() }
    }

    private func runCountdown() async {
        for step in 0..<3 {
            count = 3 - step
            scale = 0.6
            WKInterfaceDevice.current().play(.click)
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.1
                ringTrim = CGFloat(step + 1) / 3
            }
            withAnimation(.easeInOut(duration: 0.7).delay(0.3)) { scale = 1.0 }
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }
        WKInterfaceDevice.current().play(.start)
        onComplete()
    }
}

// MARK: - Custom block

struct CustomFocusSheet: View {
    let onStart: (String, Int) -> Void

    @State private var taskTitle = ""
    @State private var minutes = 25

    private let presetDurations = [15, 25, 30, 45, 60, 90]
    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                TextField("What is it?", text: $taskTitle)
                    .font(WatchLook.title(13))

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(presetDurations, id: \.self) { duration in
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            minutes = duration
                        } label: {
                            Text("\(duration)m")
                                .font(WatchLook.title(13))
                                .foregroundStyle(minutes == duration ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(minutes == duration ? WatchLook.orange : Color.white.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    let clean = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStart(clean.isEmpty ? "Focus" : clean, minutes)
                } label: {
                    Label("Start \(minutes)m", systemImage: "play.fill")
                        .font(WatchLook.title(14))
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchLook.orange)
            }
            .padding(.horizontal, 4)
        }
    }
}
