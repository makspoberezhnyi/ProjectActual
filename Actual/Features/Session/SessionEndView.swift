import SwiftUI

/// What happened, next to what was expected, and what that changed.
///
/// This is the moment the product exists for. The guess is not hidden once the outcome
/// is known — the pairing is the whole point — and nothing here asks the person to
/// justify the difference.
struct SessionEndView: View {
    let session: Session
    let history: [SessionRecord]
    /// Set only when this session came from a reminder whose sender asked to be told,
    /// off by default. Offers the one-tap ping rather than sending it automatically.
    let pingURL: URL?
    let onDone: () -> Void

    private let engine = BiasEngine()

    /// Recomputed with this session already counted, since it closed a moment ago.
    private var estimate: RecalibratedEstimate? {
        guard let categoryID = session.categoryID else { return nil }
        return engine.recalibratedEstimate(
            rawGuessMinutes: session.estimatedMinutes,
            for: CategoryKey(categoryID: categoryID, contextTag: session.contextTag),
            from: history
        )
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 4) {
                        Caption("\(session.title) · \(session.contextTag.rawValue)")
                        Text("Session ended")
                            .font(Typeface.title(24))
                            .foregroundStyle(Theme.primaryText)
                    }

                    outcome

                    if session.route.count >= 2 {
                        RouteSummaryView(route: session.route)
                            .frame(height: 150)
                            .clipShape(.rect(cornerRadius: Theme.Radius.panel))
                    }

                    Hairline()

                    if let estimate {
                        updatedCard(estimate)
                    } else {
                        firstTimeCard
                    }
                }
                .padding(.horizontal, Theme.Spacing.focused)

                Spacer()
                actions
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - The two numbers

    private var outcome: some View {
        // Three columns is tighter than two, so the numbers shrink to fit rather than
        // wrapping mid-value.
        HStack(alignment: .top, spacing: session.apiBaselineMinutes == nil ? 22 : 14) {
            VStack(alignment: .leading, spacing: 4) {
                Caption("You guessed", size: 12)
                Text(
                    session.estimatedMinutes.map { DurationFormatting.padded(minutes: $0) } ?? "—"
                )
                .font(Typeface.display(28))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Three numbers where a route was consulted: what they guessed, what the
            // route said, and what happened. The middle one is what makes "you tend to
            // arrive later than the route predicts" a thing that can be said at all.
            if let baseline = session.apiBaselineMinutes {
                VStack(alignment: .leading, spacing: 4) {
                    Caption("Route said", size: 12)
                    Text(DurationFormatting.padded(minutes: baseline))
                        .font(Typeface.display(28))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Actual")
                    .font(Typeface.semibold(12))
                    .foregroundStyle(Theme.secondaryText)
                Text(DurationFormatting.padded(minutes: session.actualMinutes ?? 0))
                    .font(Typeface.display(28))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - What it changed

    private func updatedCard(_ estimate: RecalibratedEstimate) -> some View {
        CardSurface(radius: Theme.Radius.panel, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Caption("Updated for next time")
                    Spacer()
                    CountBadge(text: "\(estimate.instanceCount) sessions")
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(DurationFormatting.compact(minutes: estimate.minutes))
                        .font(Typeface.display(24))
                        .foregroundStyle(Theme.primaryText)

                    if let delta = estimate.trendMinutes, delta != 0 {
                        Caption(
                            "\(delta > 0 ? "\u{2191} up" : "\u{2193} down") \(abs(delta))m",
                            size: 12
                        )
                    }
                }

                Text(summary(estimate))
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let routeNote {
                    Text(routeNote)
                        .font(Typeface.body(12.5))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// How this person compares to the route itself, once enough trips carry a baseline.
    private var routeNote: String? {
        guard let categoryID = session.categoryID else { return nil }
        let key = CategoryKey(categoryID: categoryID, contextTag: session.contextTag)
        guard let multiplier = engine.baselineMultiplier(for: key, from: history) else { return nil }

        let deviation = multiplier - 1
        guard abs(deviation) >= 0.05 else {
            return "You tend to arrive about when the route predicts."
        }
        let percent = DurationFormatting.percent(deviation)
        return deviation > 0
            ? "You tend to take about \(percent) longer than the route predicts."
            : "You tend to take about \(percent) less than the route predicts."
    }

    /// Below the threshold there is deliberately no number, and the copy says why
    /// rather than implying data that does not exist.
    private var firstTimeCard: some View {
        CardSurface(radius: Theme.Radius.panel, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Caption("Logged")
                Text("A few more of these and Actual will start showing you what this usually takes.")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summary(_ estimate: RecalibratedEstimate) -> String {
        let context = session.contextTag.rawValue
        let name = session.title.lowercased()

        if estimate.output.deviation > 0.05 {
            return "Your \(context) \(name)s are still trending a bit longer than your guesses. Nothing to do here, just something to notice."
        }
        if estimate.output.deviation < -0.05 {
            return "Your \(context) \(name)s are trending shorter than your guesses. Nothing to do here, just something to notice."
        }
        return "Your \(context) \(name)s are landing close to your guesses lately."
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            if let pingURL {
                ShareLink(item: pingURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.system(size: 13))
                        Text("Let them know it's done")
                            .font(Typeface.body(13))
                    }
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay { Capsule().strokeBorder(Theme.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }

            PrimaryButton(title: "Done", action: onDone)

            HStack(spacing: 4) {
                Text("This felt unusual?")
                    .foregroundStyle(Theme.tertiaryText)
                Text("Tag the context")
                    .foregroundStyle(Theme.secondaryText)
                    .underline()
            }
            .font(Typeface.body(12.5))
        }
        .padding(.horizontal, Theme.Spacing.focused)
        .padding(.bottom, 46)
    }
}
