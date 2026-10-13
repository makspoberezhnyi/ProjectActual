import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents
#if canImport(AlarmKit)
import AlarmKit
#endif

@main
struct ActualWidgetBundle: WidgetBundle {
    var body: some Widget {
        TempoFocusWidget()
        TempoAlarmWidget()
        TempoLockScreenWidget()
        TempoLiveActivity()
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            TempoAlarmLiveActivity()
        }
        #endif
    }
}

// MARK: - Shared look

/// The clock lives on a desk everywhere: same oak, same ink, same orange as the app.
private enum Look {
    static let orange = TempoMascotPalette.orange
    static let ink = DeskPalette.ink
    static let muted = DeskPalette.muted

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func numerals(_ size: CGFloat) -> Font { .system(size: size, weight: .light, design: .rounded).monospacedDigit() }
    static func caption(_ size: CGFloat = 10) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

private extension WidgetSnapshotData {
    var activeEnd: Date? {
        guard isRunning, let start = activeTaskStartedAt else { return nil }
        return start.addingTimeInterval(TimeInterval(max(1, activeTaskEstimatedMinutes ?? 25) * 60))
    }

    func remainingFraction(at date: Date) -> Double {
        guard let start = activeTaskStartedAt, let end = activeEnd else { return 0 }
        let total = end.timeIntervalSince(start)
        return min(1, max(0, end.timeIntervalSince(date) / max(1, total)))
    }

    var todayLine: String {
        let h = todayMinutes / 60, m = todayMinutes % 60
        let time = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return todayMinutes > 0 ? "\(time) logged today" : "Nothing logged yet"
    }
}

// MARK: - Timeline

struct TempoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotData
    var isCelebration: Bool = false
}

struct TempoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TempoWidgetEntry {
        TempoWidgetEntry(
            date: Date(),
            snapshot: WidgetSnapshotData(
                todayMinutes: 85,
                todayCompletedCount: 3,
                calibrationScore: 0.82,
                nextAlarmLabel: "Wake up",
                nextAlarmDate: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date().addingTimeInterval(86_400))
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TempoWidgetEntry) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let now = Date()
        let celebrating = snapshot.lastCompletedAt.map { now.timeIntervalSince($0) < 6 } ?? false
        completion(TempoWidgetEntry(date: now, snapshot: snapshot, isCelebration: celebrating))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TempoWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let now = Date()
        var entries: [TempoWidgetEntry] = []

        if let done = snapshot.lastCompletedAt, now.timeIntervalSince(done) < 6 {
            // A quick "done!" moment, then back to normal.
            entries.append(TempoWidgetEntry(date: now, snapshot: snapshot, isCelebration: true))
            entries.append(TempoWidgetEntry(date: now.addingTimeInterval(3.2), snapshot: snapshot))
        } else if let end = snapshot.activeEnd, end > now {
            // The bezel drains every few minutes, and the mascot switches to overtime at the end.
            var t = now
            while t < end && entries.count < 30 {
                entries.append(TempoWidgetEntry(date: t, snapshot: snapshot))
                t = t.addingTimeInterval(120)
            }
            entries.append(TempoWidgetEntry(date: end, snapshot: snapshot))
        } else {
            entries.append(TempoWidgetEntry(date: now, snapshot: snapshot))
        }

        // Refresh after the next alarm rings so it moves on to the one after.
        let refresh = snapshot.nextAlarmDate.map { max($0.addingTimeInterval(60), now.addingTimeInterval(900)) }
            ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - HOME SCREEN: FOCUS (clock on the desk + your quick tasks)

struct TempoFocusWidget: Widget {
    let kind: String = "TempoFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            FocusWidgetView(entry: entry)
                .containerBackground(for: .widget) { DeskBackdrop(horizon: 0.64) }
        }
        .configurationDisplayName("Focus")
        .description("Your clock on its desk. Start a task you do often, or see the one that's running.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct FocusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TempoWidgetEntry

    private var snap: WidgetSnapshotData { entry.snapshot }

    private var regime: TempoMascotRegime {
        if entry.isCelebration { return .calibBullseyeJump }
        guard let end = snap.activeEnd else { return .timerDialing }
        return entry.date >= end ? .calibOvertime : .timerActiveCountdown
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                if family == .systemMedium {
                    MascotStanding(
                        regime: regime,
                        size: h * 0.7,
                        x: w * 0.2,
                        feetY: h * 0.88,
                        bezelProgress: snap.isRunning ? snap.remainingFraction(at: entry.date) : nil
                    )
                    mediumContent
                        .frame(width: w * 0.6, alignment: .leading)
                        .padding(.vertical, 14)
                        .offset(x: w * 0.38)
                } else {
                    MascotStanding(
                        regime: regime,
                        size: h * 0.5,
                        x: w * 0.27,
                        feetY: h * 0.9,
                        bezelProgress: snap.isRunning ? snap.remainingFraction(at: entry.date) : nil
                    )
                    smallContent
                        .padding(14)
                        .frame(width: w, height: h, alignment: .topLeading)
                }
            }
        }
        .widgetURL(URL(string: "tempo://focus"))
    }

    // Small: what's happening on top, one big button bottom right.
    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if entry.isCelebration {
                Text("DONE!").font(Look.caption()).foregroundStyle(Look.orange)
                Text("+\(snap.lastCompletedMinutes ?? 0)m").font(Look.numerals(28)).foregroundStyle(Look.ink)
            } else if let end = snap.activeEnd {
                Text((snap.activeTaskTitle ?? "Focus").uppercased())
                    .font(Look.caption()).foregroundStyle(Look.orange).lineLimit(1)
                Text(end, style: .timer)
                    .font(Look.numerals(28)).foregroundStyle(Look.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("WHAT'S NEXT?").font(Look.caption()).foregroundStyle(Look.orange)
                Text(snap.todayLine).font(Look.title(12)).foregroundStyle(Look.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                if snap.isRunning {
                    Button(intent: StopFocusIntent()) {
                        roundIcon("checkmark", filled: true)
                    }
                    .buttonStyle(.plain)
                } else if let task = snap.effectiveQuickTasks.first {
                    Button(intent: StartFocusIntent(taskTitle: task.title, minutes: task.minutes)) {
                        VStack(spacing: 2) {
                            roundIcon("play.fill", filled: true)
                            Text("\(task.minutes)m").font(Look.caption(9)).foregroundStyle(Look.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // Medium: the clock on the left, the work on the right.
    @ViewBuilder
    private var mediumContent: some View {
        if entry.isCelebration {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOGGED!").font(Look.caption()).foregroundStyle(Look.orange)
                Text(snap.lastCompletedTitle ?? "Nice work").font(Look.title(16)).foregroundStyle(Look.ink).lineLimit(1)
                Text("+\(snap.lastCompletedMinutes ?? 0)m · \(snap.todayLine)").font(Look.title(11)).foregroundStyle(Look.muted)
            }
        } else if let end = snap.activeEnd, let start = snap.activeTaskStartedAt {
            VStack(alignment: .leading, spacing: 4) {
                Text((snap.activeTaskTitle ?? "Focus").uppercased())
                    .font(Look.caption()).foregroundStyle(Look.orange).lineLimit(1)
                Text(end, style: .timer)
                    .font(Look.numerals(34)).foregroundStyle(Look.ink).lineLimit(1)
                ProgressView(timerInterval: start...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                    .tint(Look.orange)
                HStack(spacing: 8) {
                    Button(intent: ExtendFocusIntent(minutesToAdd: 5)) {
                        pill("+5 min", filled: false)
                    }
                    .buttonStyle(.plain)
                    Button(intent: StopFocusIntent()) {
                        pill("Done", filled: true)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(.trailing, 14)
        } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("QUICK START").font(Look.caption()).foregroundStyle(Look.orange)
                    Spacer()
                    Text("\(Int(snap.calibrationScore * 100))% on target")
                        .font(Look.caption(9)).foregroundStyle(Look.muted)
                }
                .padding(.trailing, 14)
                ForEach(snap.effectiveQuickTasks.prefix(3), id: \.self) { task in
                    Button(intent: StartFocusIntent(taskTitle: task.title, minutes: task.minutes)) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(Look.orange)
                            Text(task.title).font(Look.title(13)).foregroundStyle(Look.ink).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(task.minutes)m").font(Look.title(12)).monospacedDigit().foregroundStyle(Look.muted)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Capsule().fill(Color.white.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 14)
            }
        }
    }

    private func roundIcon(_ symbol: String, filled: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(filled ? Color.white : Look.ink)
            .frame(width: 40, height: 40)
            .background(Circle().fill(filled ? Look.orange : Color.white.opacity(0.6)))
    }

    private func pill(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(Look.title(12))
            .foregroundStyle(filled ? Color.white : Look.ink)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(filled ? Look.orange : Color.white.opacity(0.6)))
    }
}

// MARK: - HOME SCREEN: ALARM (stack it with Focus and swipe between them)

struct TempoAlarmWidget: Widget {
    let kind: String = "TempoAlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            AlarmWidgetView(entry: entry)
                .containerBackground(for: .widget) { DeskBackdrop(horizon: 0.64) }
        }
        .configurationDisplayName("Next Alarm")
        .description("The twin-bell clock with your next alarm. Stack it on top of Focus and swipe.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct AlarmWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TempoWidgetEntry

    private var date: Date? { entry.snapshot.nextAlarmDate.flatMap { $0 > entry.date ? $0 : nil } }
    private var regime: TempoMascotRegime {
        guard date != nil else { return .alarmBedtimeMoody }
        return entry.snapshot.nextAlarmIsBedtime == true ? .alarmBedtimeMoody : .alarmArmed
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let medium = family == .systemMedium
            ZStack(alignment: .topLeading) {
                MascotStanding(
                    regime: regime,
                    size: medium ? h * 0.7 : h * 0.5,
                    x: medium ? w * 0.2 : w * 0.72,
                    feetY: h * (medium ? 0.88 : 0.9)
                )
                VStack(alignment: .leading, spacing: 2) {
                    if let date {
                        Text((entry.snapshot.nextAlarmLabel ?? "Alarm").uppercased())
                            .font(Look.caption()).foregroundStyle(Look.orange).lineLimit(1)
                        Text(date, style: .time)
                            .font(Look.numerals(medium ? 40 : 30)).foregroundStyle(Look.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text(date, style: .relative)
                            .font(Look.title(11)).foregroundStyle(Look.muted)
                    } else {
                        Text("ALARMS").font(Look.caption()).foregroundStyle(Look.orange)
                        Text("None set").font(Look.title(16)).foregroundStyle(Look.ink)
                        Text("Tap to set one").font(Look.title(11)).foregroundStyle(Look.muted)
                    }
                }
                .padding(14)
                .frame(width: medium ? w * 0.6 : w, alignment: .leading)
                .offset(x: medium ? w * 0.38 : 0)
            }
        }
        .widgetURL(URL(string: "tempo://alarms"))
    }
}

// MARK: - LOCK SCREEN

struct TempoLockScreenWidget: Widget {
    let kind: String = "TempoLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            AccessoryView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Tempo")
        .description("The running timer, or your next alarm and today's time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct AccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TempoWidgetEntry
    private var snap: WidgetSnapshotData { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if let end = snap.activeEnd, let start = snap.activeTaskStartedAt {
                    ProgressView(timerInterval: start...end, countsDown: true, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                        .progressViewStyle(.circular)
                        .widgetAccentable()
                    Text(end, style: .timer)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .frame(width: 40)
                } else {
                    TempoWatchMascotView(regime: snap.nextAlarmDate != nil ? .alarmArmed : .timerDialing, size: 44, animated: false)
                        .widgetAccentable()
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let end = snap.activeEnd, let start = snap.activeTaskStartedAt {
                    Text(snap.activeTaskTitle ?? "Focus").font(.headline).lineLimit(1).widgetAccentable()
                    Text(end, style: .timer).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                    ProgressView(timerInterval: start...end, countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() })
                } else if let alarm = snap.nextAlarmDate, alarm > entry.date {
                    Label {
                        Text(alarm, style: .time)
                    } icon: {
                        Image(systemName: "alarm.fill")
                    }
                    .font(.headline)
                    .widgetAccentable()
                    Text(snap.nextAlarmLabel ?? "Alarm").font(.caption).lineLimit(1)
                    Text(snap.todayLine).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Tempo").font(.headline).widgetAccentable()
                    Text(snap.todayLine).font(.caption)
                    Text("\(Int(snap.calibrationScore * 100))% on target").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            if let end = snap.activeEnd {
                Text(Image(systemName: "timer")) + Text(" \(snap.activeTaskTitle ?? "Focus") ") + Text(end, style: .timer)
            } else if let alarm = snap.nextAlarmDate, alarm > entry.date {
                Text(Image(systemName: "alarm")) + Text(" ") + Text(alarm, style: .time) + Text(" \(snap.nextAlarmLabel ?? "")")
            } else {
                Text("Tempo · \(snap.todayLine)")
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - LIVE ACTIVITY & DYNAMIC ISLAND

private extension ActivityViewContext where Attributes == TempoActivityAttributes {
    var isComplete: Bool {
        !state.isRunning
            || state.statusMessage?.contains("Complete") == true
            || state.statusMessage?.contains("Done") == true
    }

    var end: Date {
        attributes.startDate.addingTimeInterval(TimeInterval(max(1, state.estimatedMinutes) * 60))
    }
}

struct TempoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            LiveActivityBanner(context: context)
                .activityBackgroundTint(DeskPalette.wall)
                .activitySystemActionForegroundColor(Look.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // The clock on a little strip of desk, even in the island.
                    ZStack(alignment: .bottom) {
                        Capsule()
                            .fill(DeskPalette.surface)
                            .frame(width: 58, height: 7)
                        TempoWatchMascotView(
                            regime: context.isComplete ? .calibBullseyeJump : .timerActiveCountdown,
                            size: 54,
                            animated: false
                        )
                        .padding(.bottom, 1)
                    }
                    .frame(width: 62, height: 60)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        if context.isComplete {
                            Text("Logged").font(Look.title(16)).foregroundStyle(Look.orange)
                            Text("\(context.state.actualMinutes)m").font(Look.numerals(24)).foregroundStyle(.white)
                        } else {
                            Text(context.end, style: .timer)
                                .font(Look.numerals(30))
                                .foregroundStyle(Look.orange)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110, alignment: .trailing)
                            Text("ends \(context.end, style: .time)")
                                .font(Look.title(11)).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.taskTitle)
                        .font(Look.title(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isComplete {
                        Text("Nice! That's in your logbook now.")
                            .font(Look.title(13))
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        HStack(spacing: 10) {
                            ProgressView(
                                timerInterval: context.attributes.startDate...context.end,
                                countsDown: false,
                                label: { EmptyView() },
                                currentValueLabel: { EmptyView() }
                            )
                            .tint(Look.orange)
                            Button(intent: ExtendFocusIntent(minutesToAdd: 5)) {
                                Text("+5").font(Look.title(13)).foregroundStyle(.white)
                                    .frame(width: 44, height: 30)
                                    .background(Capsule().fill(Color.white.opacity(0.16)))
                            }
                            .buttonStyle(.plain)
                            Button(intent: StopFocusIntent(activityId: context.activityID)) {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 44, height: 30)
                                    .background(Capsule().fill(Look.orange))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                }
            } compactLeading: {
                TempoWatchMascotView(
                    regime: context.isComplete ? .calibBullseyeJump : .timerActiveCountdown,
                    size: 24,
                    animated: false
                )
            } compactTrailing: {
                if context.isComplete {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Look.orange)
                } else {
                    Text(context.end, style: .timer)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Look.orange)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 46, alignment: .trailing)
                }
            } minimal: {
                TempoWatchMascotView(regime: .timerActiveCountdown, size: 22, animated: false)
            }
            .keylineTint(Look.orange)
            .widgetURL(URL(string: "tempo://focus"))
        }
    }
}

/// Lock screen banner: the clock standing on its desk, the countdown, and two buttons.
struct LiveActivityBanner: View {
    let context: ActivityViewContext<TempoActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                DeskBackdrop(horizon: 0.6)
                MascotStanding(
                    regime: context.isComplete ? .calibBullseyeJump : .timerActiveCountdown,
                    size: 66,
                    x: 39,
                    feetY: 76
                )
            }
            .frame(width: 78, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.taskTitle)
                    .font(Look.title(16))
                    .foregroundStyle(Look.ink)
                    .lineLimit(1)
                if context.isComplete {
                    Text("Logged \(context.state.actualMinutes)m. Nice work!")
                        .font(Look.title(12))
                        .foregroundStyle(Look.orange)
                } else {
                    Text("Ends at \(context.end, style: .time)")
                        .font(Look.title(12))
                        .foregroundStyle(Look.muted)
                    ProgressView(
                        timerInterval: context.attributes.startDate...context.end,
                        countsDown: false,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(Look.orange)
                }
            }

            Spacer(minLength: 4)

            if !context.isComplete {
                VStack(alignment: .trailing, spacing: 8) {
                    // Counts down, then keeps counting up as honest overtime.
                    Text(context.end, style: .timer)
                        .font(Look.numerals(28))
                        .foregroundStyle(Look.ink)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                    HStack(spacing: 6) {
                        Button(intent: ExtendFocusIntent(minutesToAdd: 5)) {
                            Text("+5").font(Look.title(12)).foregroundStyle(Look.ink)
                                .frame(width: 38, height: 30)
                                .background(Capsule().fill(Look.ink.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        Button(intent: StopFocusIntent(activityId: context.activityID)) {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 38, height: 30)
                                .background(Capsule().fill(Look.orange))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
    }
}

// MARK: - ALARM SNOOZE (AlarmKit Live Activity)

#if canImport(AlarmKit)
/// What an AlarmKit alarm is doing right now, flattened for the views below.
@available(iOS 26.0, *)
private struct AlarmActivityState {
    var fireDate: Date?
    var pausedRemaining: TimeInterval?
    var isRinging = false

    init(_ state: AlarmPresentationState) {
        switch state.mode {
        case .countdown(let countdown):
            fireDate = countdown.fireDate
        case .paused(let paused):
            pausedRemaining = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
        default:
            isRinging = true
        }
    }

    var regime: TempoMascotRegime { isRinging ? .alarmRinging : .alarmSnoozing }
}

/// Snoozed alarms count down on the lock screen and in the Dynamic Island with the sleepy twin-bell clock.
@available(iOS 26.0, *)
struct TempoAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TempoAlarmMetadata>.self) { context in
            AlarmActivityBanner(
                title: context.attributes.presentation.alert.title,
                state: AlarmActivityState(context.state),
                alarmID: context.state.alarmID.uuidString
            )
            .activityBackgroundTint(DeskPalette.wall)
            .activitySystemActionForegroundColor(Look.ink)
        } dynamicIsland: { context in
            let state = AlarmActivityState(context.state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZStack(alignment: .bottom) {
                        Capsule().fill(DeskPalette.surface).frame(width: 58, height: 7)
                        TempoWatchMascotView(regime: state.regime, size: 54, animated: false)
                            .padding(.bottom, 1)
                    }
                    .frame(width: 62, height: 60)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmCountdownText(state: state, size: 30)
                        .foregroundStyle(Look.orange)
                        .frame(maxWidth: 110, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.presentation.alert.title)
                        .font(Look.title(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(state.isRinging ? "Ringing!" : "Snoozing. I'll ring again soon.")
                            .font(Look.title(12))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Button(intent: StopTempoAlarmIntent(alarmID: context.state.alarmID.uuidString)) {
                            Text("I'm up").font(Look.title(13)).foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 30)
                                .background(Capsule().fill(Look.orange))
                        }
                        .buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                TempoWatchMascotView(regime: state.regime, size: 24, animated: false)
            } compactTrailing: {
                AlarmCountdownText(state: state, size: 13)
                    .foregroundStyle(Look.orange)
                    .frame(width: 46, alignment: .trailing)
            } minimal: {
                TempoWatchMascotView(regime: state.regime, size: 22, animated: false)
            }
            .keylineTint(Look.orange)
            .widgetURL(URL(string: "tempo://alarms"))
        }
    }
}

@available(iOS 26.0, *)
private struct AlarmCountdownText: View {
    let state: AlarmActivityState
    let size: CGFloat

    var body: some View {
        Group {
            if let fire = state.fireDate {
                Text(timerInterval: Date.now...max(Date.now, fire), countsDown: true)
            } else if let left = state.pausedRemaining {
                Text(Duration.seconds(left), format: .time(pattern: .minuteSecond))
            } else {
                Text("Now")
            }
        }
        .font(size > 20 ? Look.numerals(size) : .system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

@available(iOS 26.0, *)
private struct AlarmActivityBanner: View {
    let title: LocalizedStringResource
    let state: AlarmActivityState
    let alarmID: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                DeskBackdrop(horizon: 0.6)
                MascotStanding(regime: state.regime, size: 66, x: 39, feetY: 76)
            }
            .frame(width: 78, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Look.title(16))
                    .foregroundStyle(Look.ink)
                    .lineLimit(1)
                Text(state.isRinging ? "Ringing! Time to get up." : "Snoozing. A few more minutes of dreams.")
                    .font(Look.title(12))
                    .foregroundStyle(Look.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 8) {
                AlarmCountdownText(state: state, size: 28)
                    .foregroundStyle(Look.ink)
                    .frame(maxWidth: 96, alignment: .trailing)
                Button(intent: StopTempoAlarmIntent(alarmID: alarmID)) {
                    Text("I'm up").font(Look.title(12)).foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(Look.orange))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }
}
#endif
