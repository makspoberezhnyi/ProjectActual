import WidgetKit
import SwiftUI
import AppIntents

/// The home screen widget.
///
/// Two states, because the useful thing to show depends entirely on whether something is
/// running: a live timer when it is, and one-tap starts when it is not. Starting or
/// ending here never opens the app.
struct SessionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SessionWidget", provider: SessionTimelineProvider()) { entry in
            SessionWidgetView(snapshot: entry.snapshot)
                .containerBackground(Theme.bg, for: .widget)
        }
        .configurationDisplayName("Actual")
        .description("Start something, or see what's running.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SessionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SessionTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry {
        SessionEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        Task { @MainActor in
            completion(SessionEntry(date: .now, snapshot: .current()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        Task { @MainActor in
            let snapshot = WidgetSnapshot.current()
            let entry = SessionEntry(date: .now, snapshot: snapshot)

            // The running timer draws itself from a date, so there is no need to wake
            // every minute just to move a number. A widget showing quick starts only
            // needs refreshing when the ranking might have changed.
            let next = snapshot.running == nil
                ? Date.now.addingTimeInterval(30 * 60)
                : Date.now.addingTimeInterval(15 * 60)

            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SessionWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let running = snapshot.running {
            RunningWidgetView(running: running, isCompact: family == .systemSmall)
        } else {
            QuickStartWidgetView(
                quickStarts: snapshot.quickStarts,
                isCompact: family == .systemSmall
            )
        }
    }
}

/// What is running, and one tap to stop it.
struct RunningWidgetView: View {
    let running: WidgetSnapshot.Running
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            HStack(spacing: 6) {
                Circle().fill(Theme.accent).frame(width: 5, height: 5)
                Text(running.title)
                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }

            // Ticks on its own without the widget being woken every second, which no
            // widget framework can sustain anyway.
            Text(running.startedAt, style: .timer)
                .font(.system(size: isCompact ? 26 : 32, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let expected = running.expectedMinutes {
                Text("of ~\(DurationFormatting.compact(minutes: expected)) expected")
                    .font(.system(size: isCompact ? 10 : 11))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            Button(intent: EndSessionIntent(sessionID: running.sessionID)) {
                Text("End")
                    .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
                    .foregroundStyle(Theme.bg)
                    .frame(maxWidth: .infinity)
                    .frame(height: isCompact ? 28 : 32)
                    .background(Theme.ink, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Nothing running: one tap to start blind — the same "start now, label it when
/// you're done" path the app's own quick start uses, `StartSessionIntent()` with no
/// category. This is the widget's main job; the most-used categories are a secondary
/// shortcut alongside it when there's room, not the primary surface.
struct QuickStartWidgetView: View {
    let quickStarts: [WidgetSnapshot.QuickStart]
    let isCompact: Bool

    var body: some View {
        if isCompact {
            blindStartButton
        } else {
            HStack(alignment: .top, spacing: 14) {
                blindStartButton
                    .frame(maxWidth: .infinity)

                if !quickStarts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Or start again")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)

                        ForEach(quickStarts.prefix(3)) { start in
                            quickStartRow(start)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var blindStartButton: some View {
        Button(intent: StartSessionIntent()) {
            VStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: isCompact ? 20 : 22, weight: .semibold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: isCompact ? 46 : 50, height: isCompact ? 46 : 50)
                    .background(Theme.ink, in: .circle)

                Text("Start")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func quickStartRow(_ start: WidgetSnapshot.QuickStart) -> some View {
        Button(intent: StartSessionIntent(
            category: CategoryEntity(id: start.categoryID, name: start.name),
            contextTag: start.contextTag,
            estimatedMinutes: start.expectedMinutes
        )) {
            HStack(spacing: 8) {
                CategoryIconView(symbolName: start.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 14)

                Text(start.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let minutes = start.expectedMinutes {
                    Text(DurationFormatting.compact(minutes: minutes))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.card, in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
