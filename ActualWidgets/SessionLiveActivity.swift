import ActivityKit
import WidgetKit
import SwiftUI

/// The running session on the lock screen and in the Dynamic Island.
///
/// Often the very first thing someone sees without unlocking their phone at all, so it
/// carries the same two facts the app shows — how long you have been going, and how long
/// this usually takes — and the same one-tap end.
struct SessionLiveActivity: Widget {
    /// `Text(timerInterval:)` sizes itself for the *widest* value the interval could
    /// ever show, not just the current one — an open range ending at `.distantFuture`
    /// (year 4001) makes it reserve room for a number with dozens of digits, which is
    /// what was ballooning the compact pill out to nearly the full screen width instead
    /// of a tight capsule around the sensor housing. A bounded end date, far longer than
    /// any real session, keeps that reservation sane while `countsDown: false` still
    /// just counts up from `startedAt` same as before.
    private static func elapsedRange(from startedAt: Date) -> ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(24 * 60 * 60)
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Theme.bg.dark)
                .activitySystemActionForegroundColor(Theme.primaryText.dark)
        } dynamicIsland: { context in
            DynamicIsland {
                // One row, not three: a timer with the title underneath on the
                // leading side, one big stop button on the trailing side — the same
                // shape as the system's own screen-recording Live Activity, rather
                // than the cramped title/context/expected-duration/small-pill layout
                // this replaced, which read as cluttered and clipped its own title
                // against the island's rounded corner.
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.accent).frame(width: 8, height: 8)
                            Text(
                                timerInterval: Self.elapsedRange(from: context.state.startedAt),
                                countsDown: false
                            )
                            .font(.system(size: 20, weight: .bold).monospacedDigit())
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        }
                        Text(context.attributes.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // Same stop glyph as the in-app End button
                    // (SessionActiveView.endButton): a filled circle with a small
                    // rounded-square icon, sized for an easy tap rather than a
                    // small text pill.
                    Button(intent: EndSessionIntent(sessionID: context.attributes.sessionID)) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Theme.bg)
                            .frame(width: 14, height: 14)
                            .frame(width: 44, height: 44)
                            .background(Theme.primaryText, in: .circle)
                    }
                    .buttonStyle(.plain)
                }
            } compactLeading: {
                Circle().fill(Theme.accent).frame(width: 6, height: 6)
            } compactTrailing: {
                // The compact pill sits directly against the camera cutout, the
                // tightest space anywhere in the Dynamic Island. showsHours: false
                // caps the string at "59:59" regardless of session length, rather
                // than "1:23:45" appearing the moment a session crosses an hour and
                // getting clipped by the island's edge. A tight 44pt frame keeps this
                // region pinned to that width instead of letting the system's compact
                // pill balloon to whatever the text's ideal size is; minimumScaleFactor
                // is what absorbs "59:59" being fractionally wider than "0:07".
                Text(
                    timerInterval: Self.elapsedRange(from: context.state.startedAt),
                    countsDown: false,
                    showsHours: false
                )
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, alignment: .trailing)
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
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)

                Text(
                    timerInterval: Self.elapsedRange(from: context.state.startedAt),
                    countsDown: false
                )
                .font(.system(size: 30, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                if let expected = context.state.expectedMinutes {
                    Text("of ~\(DurationFormatting.compact(minutes: expected)) expected")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            Spacer()
            Button(intent: EndSessionIntent(sessionID: context.attributes.sessionID)) {
                Image(systemName: "play.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Theme.primaryText)
            }
            .buttonStyle(.plain)
        }
    }
}
