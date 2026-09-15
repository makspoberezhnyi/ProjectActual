import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct ActualWidgetBundle: WidgetBundle {
    var body: some Widget {
        TempoFocusWidget()
        TempoLockScreenWidget()
        TempoLiveActivity()
    }
}

// MARK: - THEME COLORS FOR WIDGETS
struct WidgetTheme {
    static let blue = Color(red: 0.05, green: 0.52, blue: 1.0)
    static let indigo = Color(red: 0.35, green: 0.40, blue: 0.95)
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.40)
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    
    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.08, green: 0.09, blue: 0.12) : .white
    }
    
    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.42, green: 0.44, blue: 0.50) : Color.white.opacity(0.60)
    }
    
    static func tertiaryText(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.58, green: 0.60, blue: 0.66) : Color.white.opacity(0.45)
    }
    
    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.04) : Color.white.opacity(0.10)
    }
    
    static func actionButtonBackground(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.18)
    }
    
    static func glassStroke(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .light {
            return LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.white.opacity(0.24), .white.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    @ViewBuilder
    static func widgetBackground(for scheme: ColorScheme) -> some View {
        ZStack {
            if scheme == .light {
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 1.0),
                        Color(red: 0.92, green: 0.94, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [WidgetTheme.blue.opacity(0.12), Color.clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 140
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.12, blue: 0.16),
                        Color(red: 0.05, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [WidgetTheme.blue.opacity(0.18), Color.clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 120
                )
            }
        }
    }
}

// MARK: - LIVE ACTIVITY & DYNAMIC ISLAND
struct TempoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            // Lock Screen Banner
            TempoLiveActivityLockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Island Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(WidgetTheme.blue)
                        
                        Text(context.attributes.taskTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 6)
                }
                
                // Expanded Island Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(spacing: 4) {
                        Text("\(context.state.estimatedMinutes)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.blue)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(WidgetTheme.blue.opacity(0.18), in: Capsule())
                            .overlay(Capsule().strokeBorder(WidgetTheme.blue.opacity(0.35), lineWidth: 0.8))
                    }
                    .padding(.trailing, 6)
                }
                
                // Expanded Island Center / Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(alignment: .center) {
                            // Live Elapsed Timer
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(WidgetTheme.blue)
                                    .frame(width: 6, height: 6)
                                
                                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                            
                            Spacer()
                            
                            // Interactive Done Action Button
                            Button(intent: StopFocusIntent(activityId: context.activityID)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Done")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(WidgetTheme.blue, in: Capsule())
                                .shadow(color: WidgetTheme.blue.opacity(0.35), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        
                        // Live Progress Bar towards Target Duration
                        ProgressView(
                            timerInterval: context.attributes.startDate...context.attributes.startDate.addingTimeInterval(Double(max(1, context.state.estimatedMinutes) * 60)),
                            countsDown: false,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .tint(WidgetTheme.blue)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                }
                .padding(.leading, 3)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.blue)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .frame(width: 34, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.blue)
            }
        }
    }
}

// Lock Screen Live Activity Banner View
struct TempoLiveActivityLockScreenBanner: View {
    @Environment(\.colorScheme) var colorScheme
    var context: ActivityViewContext<TempoActivityAttributes>
    
    private var bannerBackground: Color {
        colorScheme == .light
            ? Color(red: 0.96, green: 0.97, blue: 0.99).opacity(0.96)
            : Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.96)
    }
    
    private var buttonBorder: Color {
        colorScheme == .light
            ? Color.black.opacity(0.12)
            : Color.white.opacity(0.25)
    }
    
    private var buttonBackground: Color {
        colorScheme == .light
            ? Color.black.opacity(0.06)
            : Color.white.opacity(0.14)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Glass Icon Orb
                ZStack {
                    Circle()
                        .fill(WidgetTheme.blue.opacity(colorScheme == .light ? 0.14 : 0.28))
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.taskTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text("Target: \(context.state.estimatedMinutes)m Focus")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetTheme.secondaryText(for: colorScheme))
                        
                        if let status = context.state.statusMessage {
                            Text("• \(status)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetTheme.blue)
                        } else if context.attributes.isLinkedToCalendar == true {
                            Text("• Calendar")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetTheme.blue)
                        } else if context.attributes.isLinkedToReminders == true {
                            Text("• Reminders")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetTheme.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Live Timer Display
                VStack(alignment: .trailing, spacing: 1) {
                    Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                    
                    Text("ELAPSED")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetTheme.blue)
                }
            }
            
            // Progress Bar & Action Row
            HStack(spacing: 12) {
                ProgressView(
                    timerInterval: context.attributes.startDate...context.attributes.startDate.addingTimeInterval(Double(max(1, context.state.estimatedMinutes) * 60)),
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .tint(WidgetTheme.blue)
                
                Button(intent: StopFocusIntent(activityId: context.activityID)) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                        Text("Done")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(WidgetTheme.blue, in: Capsule())
                    .shadow(color: WidgetTheme.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(bannerBackground)
        )
        .activityBackgroundTint(bannerBackground)
        .activitySystemActionForegroundColor(WidgetTheme.primaryText(for: colorScheme))
    }
}

// MARK: - HOME SCREEN WIDGET (Small & Medium)
struct TempoFocusWidget: Widget {
    let kind: String = "TempoFocusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            TempoWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    TempoWidgetBackground()
                }
        }
        .configurationDisplayName("Tempo Focus")
        .description("Track your focus sessions and launch quick timers directly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TempoWidgetBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WidgetTheme.widgetBackground(for: colorScheme)
    }
}

struct TempoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshotData
}

struct TempoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TempoWidgetEntry {
        TempoWidgetEntry(date: Date(), snapshot: WidgetSnapshotData(todayMinutes: 45, todayCompletedCount: 2, calibrationScore: 0.85))
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TempoWidgetEntry) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        completion(TempoWidgetEntry(date: Date(), snapshot: snapshot))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TempoWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        let entry = TempoWidgetEntry(date: Date(), snapshot: snapshot)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30)))
        completion(timeline)
    }
}

struct TempoWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    var entry: TempoWidgetEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        default:
            smallWidgetView
        }
    }
    
    // Small Widget
    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WidgetTheme.blue)
                Text("TEMPO")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetTheme.tertiaryText(for: colorScheme))
                Spacer()
                
                let score = Int(entry.snapshot.calibrationScore * 100)
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                    Text("\(score)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WidgetTheme.blue)
            }
            
            Spacer()
            
            if entry.snapshot.isRunning, let title = entry.snapshot.activeTaskTitle, let start = entry.snapshot.activeTaskStartedAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                        .lineLimit(1)
                    
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.blue)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.snapshot.todayMinutes)m")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                    
                    Text("Focused Today")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetTheme.secondaryText(for: colorScheme))
                }
            }
            
            Spacer()
            
            if entry.snapshot.isRunning {
                Button(intent: StopFocusIntent()) {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Done")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                    .padding(.vertical, 6)
                    .background(WidgetTheme.actionButtonBackground(for: colorScheme), in: Capsule())
                    .overlay(Capsule().strokeBorder(WidgetTheme.glassStroke(for: colorScheme), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                Button(intent: StartFocusIntent(taskTitle: "Deep Work", minutes: 25)) {
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("25m Focus")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .background(WidgetTheme.blue, in: Capsule())
                    .shadow(color: WidgetTheme.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }
    
    // Medium Widget with Interactive Shortcut Buttons
    private var mediumWidgetView: some View {
        VStack(spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(WidgetTheme.blue.opacity(colorScheme == .light ? 0.14 : 0.28))
                        .frame(width: 32, height: 32)
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    if entry.snapshot.isRunning, let title = entry.snapshot.activeTaskTitle {
                        Text(title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Text("Focus Session • \(entry.snapshot.activeTaskEstimatedMinutes ?? 25)m")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetTheme.secondaryText(for: colorScheme))
                    } else {
                        Text("TEMPO FOCUS")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(WidgetTheme.tertiaryText(for: colorScheme))
                        
                        Text("\(entry.snapshot.todayMinutes)m Total Today")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                    }
                }
                
                Spacer()
                
                if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.blue)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("\(Int(entry.snapshot.calibrationScore * 100))% Calibrated")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WidgetTheme.blue.opacity(colorScheme == .light ? 0.12 : 0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(WidgetTheme.blue.opacity(colorScheme == .light ? 0.25 : 0.35), lineWidth: 0.8))
                }
            }
            
            // Interactive Shortcut Buttons or Active View
            if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt, let est = entry.snapshot.activeTaskEstimatedMinutes {
                VStack(spacing: 8) {
                    ProgressView(
                        timerInterval: start...start.addingTimeInterval(Double(max(1, est) * 60)),
                        countsDown: false,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(WidgetTheme.blue)
                    
                    Button(intent: StopFocusIntent()) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Complete Session")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .background(WidgetTheme.blue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: WidgetTheme.blue.opacity(0.35), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 8) {
                    shortcutButton(icon: "bolt.fill", title: "15m", task: "Quick Focus", mins: 15)
                    shortcutButton(icon: "target", title: "25m", task: "Deep Work", mins: 25)
                    shortcutButton(icon: "chevron.left.forwardslash.chevron.right", title: "45m", task: "Programming", mins: 45)
                }
            }
        }
        .padding(8)
    }
    
    @ViewBuilder
    private func shortcutButton(icon: String, title: String, task: String, mins: Int) -> some View {
        Button(intent: StartFocusIntent(taskTitle: task, minutes: mins)) {
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                    Text("\(mins)m")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetTheme.primaryText(for: colorScheme))
                }
                Text(task)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetTheme.secondaryText(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(WidgetTheme.cardBackground(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WidgetTheme.glassStroke(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - LOCK SCREEN ACCESSORY WIDGETS
struct TempoLockScreenWidget: Widget {
    let kind: String = "TempoLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            AccessoryView(entry: entry)
        }
        .configurationDisplayName("Tempo Lock Screen")
        .description("View focus status and calibration on your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct AccessoryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    var entry: TempoWidgetEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                    Text("\(entry.snapshot.todayMinutes)m")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetTheme.blue)
                    Text("TEMPO FOCUS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                } else {
                    Text("\(entry.snapshot.todayMinutes)m today • \(entry.snapshot.todayCompletedCount) done")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        case .accessoryInline:
            if entry.snapshot.isRunning, let title = entry.snapshot.activeTaskTitle {
                Text("Tempo: \(title)")
            } else {
                Text("Tempo: \(entry.snapshot.todayMinutes)m focused today")
            }
        default:
            EmptyView()
        }
    }
}

