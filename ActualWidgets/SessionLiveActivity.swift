import ActivityKit
import WidgetKit
import SwiftUI

/// The running session on the lock screen and in the Dynamic Island.
///
/// Often the very first thing someone sees without unlocking their phone at all, so it
/// carries the same two facts the app shows — how long you have been going, and how long
/// this usually takes — and the same one-tap end.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Theme.bg)
                .activitySystemActionForegroundColor(Theme.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(context.attributes.contextTag)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(
                        timerInterval: context.state.startedAt...Date.distantFuture,
                        countsDown: false
                    )
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        if let expected = context.state.expectedMinutes {
                            Text("usually ~\(DurationFormatting.compact(minutes: expected))")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.inkFaint)
                        }

                        Spacer()

                        Button(intent: EndSessionIntent(sessionID: context.attributes.sessionID)) {
                            Text("End")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.bg)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Theme.ink, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } compactLeading: {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
            } compactTrailing: {
                Text(
                    timerInterval: context.state.startedAt...Date.distantFuture,
                    countsDown: false
                )
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: 44)
            } minimal: {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
            }
        }
    }

    private func lockScreen(
        _ context: ActivityViewContext<SessionActivityAttributes>
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.attributes.title) · \(context.attributes.contextTag)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)

                Text(
                    timerInterval: context.state.startedAt...Date.distantFuture,
                    countsDown: false
                )
                .font(.system(size: 30, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                if let expected = context.state.expectedMinutes {
                    Text("of ~\(DurationFormatting.compact(minutes: expected)) expected")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkFaint)
                }
            }

            Spacer(minLength: 0)

            Button(intent: EndSessionIntent(sessionID: context.attributes.sessionID)) {
                Text("End")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.ink, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}
