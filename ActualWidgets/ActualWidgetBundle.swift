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
    static let mint = Color(red: 0.35, green: 0.88, blue: 0.65)
    static let cyan = Color(red: 0.3, green: 0.75, blue: 0.95)
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.45)
    static let glassStroke = LinearGradient(
        colors: [.white.opacity(0.28), .white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - LIVE ACTIVITY & DYNAMIC ISLAND
struct TempoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            // Lock Screen Banner
            lockScreenBanner(context: context)
                .activityBackgroundTint(Color.black.opacity(0.72))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Island Leading
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(WidgetTheme.mint.opacity(0.18))
                                .frame(width: 26, height: 26)
                            Image(systemName: "timer")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(WidgetTheme.mint)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(context.attributes.taskTitle)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            Text("Focus Session")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.leading, 6)
                }
                
                // Expanded Island Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.attributes.estimatedMinutes)m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WidgetTheme.mint.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(WidgetTheme.mint.opacity(0.3), lineWidth: 0.8))
                        .padding(.trailing, 6)
                }
                
                // Expanded Island Center / Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(alignment: .center) {
                            Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Button(intent: StopFocusIntent()) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Done")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.18), in: Capsule())
                                .overlay(Capsule().strokeBorder(WidgetTheme.glassStroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        
                        // Live Progress Bar
                        ProgressView(
                            timerInterval: context.attributes.startDate...context.attributes.startDate.addingTimeInterval(Double(max(1, context.attributes.estimatedMinutes) * 60)),
                            countsDown: false,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .tint(WidgetTheme.mint)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 2)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.mint)
                    .padding(.leading, 2)
            } compactTrailing: {
                Text(context.attributes.startDate, style: .timer)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WidgetTheme.mint)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36, alignment: .trailing)
                    .padding(.trailing, 2)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WidgetTheme.mint)
            }
        }
    }
    
    // Lock Screen Live Activity Banner
    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<TempoActivityAttributes>) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Glass Icon Orb
                ZStack {
                    Circle()
                        .fill(WidgetTheme.mint.opacity(0.18))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(WidgetTheme.mint)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.taskTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text("Target: \(context.attributes.estimatedMinutes)m Focus")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Live Timer Display
                VStack(alignment: .trailing, spacing: 1) {
                    Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    
                    Text("ELAPSED")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(WidgetTheme.mint)
                }
            }
            
            // Progress Bar & Action Row
            HStack(spacing: 10) {
                ProgressView(
                    timerInterval: context.attributes.startDate...context.attributes.startDate.addingTimeInterval(Double(max(1, context.attributes.estimatedMinutes) * 60)),
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .tint(WidgetTheme.mint)
                
                Button(intent: StopFocusIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                        Text("Done")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().strokeBorder(WidgetTheme.glassStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }
}

// MARK: - HOME SCREEN WIDGET (Small & Medium)
struct TempoFocusWidget: Widget {
    let kind: String = "TempoFocusWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoWidgetProvider()) { entry in
            TempoWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.12, blue: 0.16),
                                Color(red: 0.05, green: 0.06, blue: 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        RadialGradient(
                            colors: [WidgetTheme.mint.opacity(0.12), Color.clear],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 120
                        )
                    }
                }
        }
        .configurationDisplayName("Tempo Focus")
        .description("Track your focus sessions and launch quick timers directly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
                    .foregroundStyle(WidgetTheme.mint)
                Text("TEMPO")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                
                let score = Int(entry.snapshot.calibrationScore * 100)
                HStack(spacing: 2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                    Text("\(score)%")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WidgetTheme.mint)
            }
            
            Spacer()
            
            if entry.snapshot.isRunning, let title = entry.snapshot.activeTaskTitle, let start = entry.snapshot.activeTaskStartedAt {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.mint)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(entry.snapshot.todayMinutes)m")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Focused Today")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
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
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().strokeBorder(WidgetTheme.glassStroke, lineWidth: 1))
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
                    .foregroundStyle(.black)
                    .padding(.vertical, 6)
                    .background(WidgetTheme.mint, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
    }
    
    // Medium Widget with Interactive Shortcut Buttons
    private var mediumWidgetView: some View {
        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("TEMPO FOCUS")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    
                    if entry.snapshot.isRunning, let title = entry.snapshot.activeTaskTitle {
                        Text("Active: \(title)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    } else {
                        Text("\(entry.snapshot.todayMinutes)m Total Today")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.mint)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundStyle(WidgetTheme.mint)
                        Text("\(Int(entry.snapshot.calibrationScore * 100))% Calibrated")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(Capsule().strokeBorder(WidgetTheme.glassStroke, lineWidth: 0.8))
                }
            }
            
            Divider().opacity(0.15)
            
            // Interactive Shortcut Buttons or Active View
            if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt, let est = entry.snapshot.activeTaskEstimatedMinutes {
                VStack(spacing: 8) {
                    ProgressView(
                        timerInterval: start...start.addingTimeInterval(Double(max(1, est) * 60)),
                        countsDown: false,
                        label: { EmptyView() },
                        currentValueLabel: { EmptyView() }
                    )
                    .tint(WidgetTheme.mint)
                    
                    Button(intent: StopFocusIntent()) {
                        HStack(spacing: 6) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Complete Session")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WidgetTheme.glassStroke, lineWidth: 1))
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
                        .foregroundStyle(WidgetTheme.mint)
                    Text("\(mins)m")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text(task)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WidgetTheme.glassStroke, lineWidth: 1))
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
    var entry: TempoWidgetEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .bold))
                    Text("\(entry.snapshot.todayMinutes)m")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                    Text("TEMPO FOCUS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                }
                
                if entry.snapshot.isRunning, let start = entry.snapshot.activeTaskStartedAt {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                } else {
                    Text("\(entry.snapshot.todayMinutes)m today • \(entry.snapshot.todayCompletedCount) done")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
