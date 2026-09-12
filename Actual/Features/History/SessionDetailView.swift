import SwiftUI

// A closed session, looked back on.
//
// Reuses the same guess/route-said/actual layout `SessionEndView` shows the moment a
// session closes — the only difference is this one has no "Done" button and no
// resolution step, since both already happened. This is the view that makes a trip's
// route visible again after the fact: previously the map only existed for the few
// seconds around a session ending, with no way back to it from History.
struct SessionDetailView: View {
    let session: Session
    let categoryName: String
    let history: [SessionRecord]
    let onDismiss: () -> Void
    // Nil for a session with no category to repeat, or an unresolved quick start.
    let onStartAgain: (() -> Void)?
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false
    @State private var appeared = false
    private let engine = BiasEngine()

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        outcome

                        if session.route.count >= 2 {
                            RouteSummaryView(route: session.route)
                                .frame(height: 220)
                                .clipShape(.rect(cornerRadius: Theme.Radius.panel))
                        }

                        if let estimate {
                            compareToUsual(estimate)
                        }

                        if session.isFlaggedLowConfidence {
                            flaggedNote
                        }
                    }
                    .padding(.horizontal, Theme.Padding.focused)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                VStack(spacing: 12) {
                    if let onStartAgain {
                        PrimaryButton(title: "Start again", action: onStartAgain)
                    }

                    Button {
                        HapticFeedback.heavyImpact()
                        isConfirmingDelete = true
                    } label: {
                        Text("Delete this session")
                            .font(Typeface.body(13))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Padding.focused)
                .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : -20)
            .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)
        }
        .alert("Delete this session?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Removes it from your history and from the numbers this category is based on. This cannot be undone.")
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
            Caption(session.endedAt?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "")
            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Outcome

    private var outcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Caption("\(categoryName) · \(session.contextTag.rawValue)")
                Text(session.title)
                    .font(Typeface.title(24))
                    .foregroundStyle(Theme.ink)
            }

            HStack(alignment: .top, spacing: session.apiBaselineMinutes == nil ? 22 : 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Caption("You guessed", size: 12)
                    Text(
                        session.estimatedMinutes.map { DurationFormatting.padded(minutes: $0) } ?? "—"
                    )
                    .font(Typeface.display(28))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let baseline = session.apiBaselineMinutes {
                    VStack(alignment: .leading, spacing: 4) {
                        Caption("Route said", size: 12)
                        Text(DurationFormatting.padded(minutes: baseline))
                            .font(Typeface.display(28))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual")
                        .font(Typeface.semibold(12))
                        .foregroundStyle(Theme.inkSoft)
                    Text(DurationFormatting.padded(minutes: session.actualMinutes ?? 0))
                        .font(Typeface.display(28))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Compare to usual

    @ViewBuilder
    private func compareToUsual(_ estimate: RecalibratedEstimate) -> some View {
        CardSurface(radius: Theme.Radius.panel, padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel(text: estimate.scope == .exact
                                 ? "BASED ON YOUR HISTORY"
                                 : "BASED ON THIS CATEGORY GENERALLY")
                    Spacer()
                    CountBadge(text: "\(estimate.instanceCount) sessions")
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(DurationFormatting.compact(minutes: estimate.minutes))
                        .font(Typeface.display(26))
                        .foregroundStyle(Theme.ink)

                    if let trend = trendText(estimate) {
                        Caption(trend, size: 12)
                    }
                }

                Text(explanation(estimate))
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if estimate.confidence == .low {
                    Caption(estimate.confidence.label, size: 11.5)
                }
            }
        }
    }

    private func trendText(_ estimate: RecalibratedEstimate) -> String? {
        guard let prior = estimate.priorMinutes, prior != estimate.minutes else { return nil }
        let rising = estimate.minutes > prior
        return "\(rising ? "↑" : "↓") \(rising ? "up" : "down") from \(DurationFormatting.compact(minutes: prior))"
    }

    private func explanation(_ estimate: RecalibratedEstimate) -> String {
        let percent = DurationFormatting.percent(estimate.output.deviation)
        let noun = session.contextTag.rawValue
        let subject = categoryName.lowercased()

        if estimate.output.scope == .categoryFallback {
            return "Not enough history for \(noun) yet, so this is based on your \(subject) generally."
        }
        if estimate.output.deviation > 0.005 {
            return "Your \(noun) \(subject)s have run about \(percent) longer than your guess recently."
        }
        if estimate.output.deviation < -0.005 {
            return "Your \(noun) \(subject)s have run about \(percent) shorter than your guess recently."
        }
        return "Your \(noun) \(subject)s have been landing close to your guess recently."
    }

    // MARK: - Flagged note

    private var flaggedNote: some View {
        CardSurface(radius: Theme.Radius.row, padding: 15) {
            Text("This session's data may not be reliable.")
                .font(Typeface.body(12))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.bottom, 44)
    }
}