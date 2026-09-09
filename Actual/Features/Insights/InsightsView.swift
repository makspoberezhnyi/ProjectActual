import SwiftUI

/// Where the person is most wrong, sorted plainly by how far from right they are
/// rather than alphabetically or by how often something happens.
struct InsightsView: View {
    let sessions: [Session]
    let categories: [TaskCategory]

    @State private var range: Range = .last30Days
    @State private var selected: BiasEngineOutput?

    private let engine = BiasEngine()

    enum Range: String, CaseIterable {
        case last30Days = "Last 30 days"
        case allTime = "All time"

        var cutoff: Date? {
            switch self {
            case .last30Days: return Calendar.current.date(byAdding: .day, value: -30, to: .now)
            case .allTime: return nil
            }
        }
    }

    private var records: [SessionRecord] {
        let all = sessions.records
        guard let cutoff = range.cutoff else { return all }
        return all.filter { $0.endedAt >= cutoff }
    }

    private var ranking: [BiasEngineOutput] { engine.ranking(from: records) }
    private var aggregate: Double? { engine.aggregateDeviation(from: records) }

    /// Drifted categories are pulled out and shown as their own plain note, since a
    /// real pattern shift deserves to be seen rather than folded into an average.
    private var drifted: [BiasEngineOutput] { ranking.filter(\.driftFlag) }
    private var steady: [BiasEngineOutput] { ranking.filter { !$0.driftFlag } }

    /// Built once per body evaluation rather than scanned per ranked row.
    private var categoriesByID: [String: TaskCategory] { categories.indexedByID() }

    var body: some View {
        VStack(spacing: 0) {
            // Title and range stay put, so the ranked list scrolls beneath them rather
            // than under the status bar.
            VStack(alignment: .leading, spacing: 0) {
                Text("Your patterns")
                    .font(Typeface.title(22))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, Theme.Padding.screen)
                    .padding(.top, 22)
                    .padding(.bottom, 6)

                rangePicker
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.bg)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    headline

                    Text("Where you're most wrong")
                        .font(Typeface.title(15))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, Theme.Padding.screen)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                    if ranking.isEmpty {
                        CardSurface(radius: Theme.Radius.row, padding: 16) {
                            Text("Not enough history in this range yet. A handful of logged sessions in a category and this fills in.")
                                .font(Typeface.body(13))
                                .foregroundStyle(Theme.inkSoft)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Theme.Padding.screen)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(steady, id: \.key) { output in
                                Button { selected = output } label: {
                                    DeviationRow(output: output, name: name(for: output.key))
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(drifted, id: \.key) { output in
                                Button { selected = output } label: {
                                    DriftRow(output: output, name: name(for: output.key))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Padding.screen)
                    }
                }
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selected) { output in
            CategoryTrendView(
                name: name(for: output.key),
                output: output,
                history: BiasEngine().multiplierHistory(for: output.key, from: records)
            )
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(Range.allCases, id: \.self) { option in
                Button {
                    range = option
                } label: {
                    Text(option.rawValue)
                        .font(option == range ? Typeface.medium(12) : Typeface.body(12))
                        .foregroundStyle(option == range ? Theme.bg : Theme.inkFaint)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if option == range { Capsule().fill(Theme.ink) }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 6)
    }

    /// One honest headline. Nil rather than a fabricated zero when nothing qualifies.
    private var headline: some View {
        CardSurface(radius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Caption("On average, you're off by")

                if let aggregate {
                    Text(DurationFormatting.percent(aggregate))
                        .font(Typeface.display(38))
                        .foregroundStyle(Theme.ink)
                    Caption(
                        "weighted across \(ranking.count) \(ranking.count == 1 ? "category" : "categories") with enough history",
                        size: 12
                    )
                } else {
                    Text("—")
                        .font(Typeface.display(38))
                        .foregroundStyle(Theme.inkFaint)
                    Caption("no category has enough history in this range yet", size: 12)
                }
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 20)
    }

    /// Category and context together, since that pairing is what the engine measured.
    private func name(for key: CategoryKey) -> String {
        let base = categoriesByID[key.categoryID]?.name ?? key.categoryID
        return key.contextTag == .normal ? base : "\(base), \(key.contextTag.rawValue)"
    }
}

/// One ranked category. Low confidence is rendered muted and says so, so a number
/// resting on nine sessions does not borrow the authority of one resting on fifty-one.
struct DeviationRow: View {
    let output: BiasEngineOutput
    let name: String

    private var isMuted: Bool { output.confidence == .low }

    var body: some View {
        CardSurface(radius: Theme.Radius.row, padding: 15) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(name)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    CountBadge(text: "\(output.instanceCount) logs")
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(DurationFormatting.signedPercent(output.deviation))
                        .font(Typeface.display(20))
                        .foregroundStyle(Theme.accent)
                        .opacity(isMuted ? 0.7 : 1)

                    Caption(output.deviationDescription, size: 12)

                    if isMuted {
                        Spacer()
                        Caption(output.confidence.label, size: 11)
                    }
                }

                ProgressBar(
                    fraction: min(output.absoluteDeviation, 1),
                    dimmed: isMuted
                )
            }
        }
    }
}

/// A category whose multiplier moved quickly. Stated as something to look at, not as
/// a problem to fix.
struct DriftRow: View {
    let output: BiasEngineOutput
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(Typeface.medium(14))
                    .foregroundStyle(Theme.ink)
                Spacer()
                CountBadge(text: "shifted recently", emphasised: true)
            }

            Text("This one moved quickly in the last stretch, worth a second look if something in this routine changed.")
                .font(Typeface.body(12))
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
