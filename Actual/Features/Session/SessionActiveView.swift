import SwiftUI

// The running session, given a whole screen. One number, how long this usually takes,
// and a way to stop.
//
// The copy here does the work of setting expectations: there is nothing to confirm
// afterward, so nothing on this screen implies there will be.
struct SessionActiveView: View {
    let session: Session
    let history: [SessionRecord]
    let onEnd: () -> Void
    let onDismiss: () -> Void
    // Only meaningful for a trip; nil everywhere else.
    let onShowMap: (() -> Void)?

    private let engine = BiasEngine()

    // How long this usually takes, drawn from history alone.
    //
    // Deliberately not the stored guess re-multiplied. Once someone accepts the app's
    // corrected number, that number *is* the correction; running it through the
    // multiplier a second time compounds it and shows an expectation nobody's history
    // supports. The honest figure for "how long this usually takes you" never depends
    // on what was guessed today.
    private var estimate: RecalibratedEstimate? {
        guard let categoryID = session.categoryID else { return nil }
        return engine.recalibratedEstimate(
            rawGuessMinutes: nil,
            for: CategoryKey(categoryID: categoryID, contextTag: session.contextTag),
            from: history
        )
    }

    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = session.elapsedSeconds(now: context.date)
                    let isOverdue = estimate.map { elapsed > $0.minutes * 60 } ?? false

                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(session.title) · \(session.contextTag.rawValue)")
                                .font(Typeface.body(13.5))
                                .foregroundStyle(isOverdue ? Theme.error : Theme.inkFaint)

                            Text(DurationFormatting.clock(seconds: elapsed))
                                .font(Typeface.timer(64))
                                .tracking(-1.3)
                                .foregroundStyle(isOverdue ? Theme.error : Theme.ink)
                        }
                        .padding(.top, 44)

                        if let estimate {
                            ProgressBar(
                                fraction: Double(elapsed) / Double(max(1, estimate.minutes * 60)),
                                height: 4,
                                dimmed: isOverdue
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
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

                Spacer()

                if let onShowMap, !session.route.isEmpty {
                    routeCard(onTap: onShowMap)
                        .padding(.horizontal, Theme.Padding.focused)
                        .padding(.bottom, 12)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)
                }

                CardSurface(radius: Theme.Radius.row, padding: 17) {
                    Text("Say \"ending \(session.title.lowercased())\" or tap below when you're done. Nothing to confirm, Actual just records what happened.")
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Padding.focused)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)

                endButton
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Caption(session.title)
            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Route Card

    @ViewBuilder
    private func routeCard(onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            CardSurface(radius: Theme.Radius.row, padding: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "route")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)

                    Text("View route")
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.ink)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - End Button

    private var endButton: some View {
        PrimaryButton(title: "End session") {
            onEnd()
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }
}