import SwiftUI

/// The running session, given a whole screen. One number, how long this usually takes,
/// and a way to stop.
///
/// The copy here does the work of setting expectations: there is nothing to confirm
/// afterward, so nothing on this screen implies there will be.
struct SessionActiveView: View {
    let session: Session
    let history: [SessionRecord]
    let onEnd: () -> Void
    let onDismiss: () -> Void
    /// Only meaningful for a trip; nil everywhere else.
    let onShowMap: (() -> Void)?

    private let engine = BiasEngine()

    /// How long this usually takes, drawn from history alone.
    ///
    /// Deliberately not the stored guess re-multiplied. Once someone accepts the app's
    /// corrected number, that number *is* the correction; running it through the
    /// multiplier a second time compounds it and shows an expectation nobody's history
    /// supports. The honest figure for "how long this usually takes you" never depends
    /// on what was guessed today.
    private var estimate: RecalibratedEstimate? {
        guard let categoryID = session.categoryID else { return nil }
        return engine.recalibratedEstimate(
            rawGuessMinutes: nil,
            for: CategoryKey(categoryID: categoryID, contextTag: session.contextTag),
            from: history
        )
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = session.elapsedSeconds(now: context.date)

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(session.title) · \(session.contextTag.rawValue)")
                                .font(Typeface.body(13.5))
                                .foregroundStyle(Theme.inkFaint)

                            Text(DurationFormatting.clock(seconds: elapsed))
                                .font(Typeface.timer(64))
                                .tracking(-1.3)
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.top, 44)

                        if let estimate {
                            ProgressBar(
                                fraction: Double(elapsed) / Double(max(1, estimate.minutes * 60)),
                                height: 4
                            )
                            .padding(.top, 26)

                            HStack {
                                Caption("expected around")
                                Spacer()
                                Text("\(DurationFormatting.compact(minutes: estimate.minutes)) · \(estimate.instanceCount) sessions")
                                    .font(Typeface.body(12.5))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            .padding(.top, 16)
                        } else {
                            Caption("No history for this yet, so there's no expectation to show.")
                                .padding(.top, 26)
                        }
                    }
                }
                .padding(.horizontal, Theme.Padding.focused)

                Spacer()

                if let onShowMap, !session.route.isEmpty {
                    routeCard(onTap: onShowMap)
                        .padding(.horizontal, Theme.Padding.focused)
                        .padding(.bottom, 12)
                }

                CardSurface(radius: Theme.Radius.row, padding: 17) {
                    Text("Say \"ending \(session.title.lowercased())\" or tap below when you're done. Nothing to confirm, Actual just records what happened.")
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Padding.focused)

                endButton
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                Text("IN PROGRESS")
                    .font(Typeface.body(12))
                    .tracking(0.72)
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    /// Opens the live route. Shown only for a trip once it actually has fixes to draw,
    /// since there is nothing to look at before the car has moved.
    private func routeCard(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "map")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                Text("View route")
                    .font(Typeface.medium(13))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if session.routeDistanceMeters > 0 {
                    Caption(DurationFormatting.distance(meters: session.routeDistanceMeters), size: 12)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var endButton: some View {
        VStack(spacing: 14) {
            Button(action: onEnd) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Theme.bg)
                    .frame(width: 24, height: 24)
                    .frame(width: 80, height: 80)
                    .background(Theme.ink, in: .circle)
            }
            .buttonStyle(.plain)

            Caption("End session")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 48)
    }
}
