import SwiftUI

/// A closed session, looked back on.
///
/// Reuses the same guess/route-said/actual layout `SessionEndView` shows the moment a
/// session closes — the only difference is this one has no "Done" button and no
/// resolution step, since both already happened. This is the view that makes a trip's
/// route visible again after the fact: previously the map only existed for the few
/// seconds around a session ending, with no way back to it from History.
struct SessionDetailView: View {
    let session: Session
    let categoryName: String
    let history: [SessionRecord]
    let onDismiss: () -> Void
    /// Nil for a session with no category to repeat, or an unresolved quick start.
    let onStartAgain: (() -> Void)?
    let onDelete: () -> Void

    @State private var isConfirmingDelete = false
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
        }
        .alert("Delete this session?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Removes it from your history and from the numbers this category is based on. This cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            Spacer()
            Caption(session.endedAt?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

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
    }

    private func compareToUsual(_ estimate: RecalibratedEstimate) -> some View {
        CardSurface(radius: Theme.Radius.panel, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Caption("Usually takes")
                    Spacer()
                    CountBadge(text: "\(estimate.instanceCount) sessions")
                }
                Text(DurationFormatting.compact(minutes: estimate.minutes))
                    .font(Typeface.display(22))
                    .foregroundStyle(Theme.ink)
            }
        }
    }

    private var flaggedNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Auto-closed")
                .font(Typeface.medium(13))
                .foregroundStyle(Theme.ink)
            Text("This one ran past its ceiling and closed on its own. Kept visible as an outlier rather than folded into your average.")
                .font(Typeface.body(12.5))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.row)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}
