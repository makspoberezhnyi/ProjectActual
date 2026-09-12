import SwiftUI

// Where the person is most wrong, sorted plainly by how far from right they are
// rather than alphabetically or by how often something happens.
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

    // Drifted categories are pulled out and shown as their own plain note, since a
    // real pattern shift deserves to be seen rather than folded into an average.
    private var drifted: [BiasEngineOutput] { ranking.filter(\.driftFlag) }
    private var steady: [BiasEngineOutput] { ranking.filter { !$0.driftFlag } }

    // Built once per body evaluation rather than scanned per ranked row.
    private var categoriesByID: [String: TaskCategory] { categories.indexedByID() }

    @State private var appeared = false

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
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(steady, id: \.key) { output in
                                Button { selected = output } label: {
                                    DeviationRow(output: output, name: name(for: output.key))
                                }
                                .buttonStyle(.plain)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : -20)
                                .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(steady.firstIndex(of: output) ?? 0) * 0.07 + 0.2), value: appeared)
                            }
                            ForEach(drifted, id: \.key) { output in
                                Button { selected = output } label: {
                                    DriftRow(output: output, name: name(for: output.key))
                                }
                                .buttonStyle(.plain)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : -20)
                                .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(drifted.firstIndex(of: output) ?? 0) * 0.07 + 0.3), value: appeared)
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
        .onAppear { appeared = true }
    }

    // MARK: - Range Picker

    private var rangePicker: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    range = .last30Days
                }
            } label: {
                Text(range.rawValue)
                    .font(Typeface.body(13))
                    .foregroundStyle(range == .last30Days ? Theme.ink : Theme.inkFaint)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                    range = .allTime
                }
            } label: {
                Text("All time")
                    .font(Typeface.body(13))
                    .foregroundStyle(range == .allTime ? Theme.ink : Theme.inkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Headline

    private var headline: some View {
        Text("Insights")
            .font(Typeface.title(22))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 22)
            .padding(.bottom, 10)
    }

    // MARK: - Deviation Row

    private struct DeviationRow: View {
        let output: BiasEngineOutput
        let name: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.xy")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.inkSoft)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)
                    Text("\(DurationFormatting.compact(minutes: Int(output.averageActualMinutes.rounded())))")
                        .font(Typeface.body(12))
                        .foregroundStyle(output.deviation > 0 ? Theme.error : Theme.success)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, Theme.Padding.row)
            .padding(.vertical, 14)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
    }

    // MARK: - Drift Row

    private struct DriftRow: View {
        let output: BiasEngineOutput
        let name: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.error)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)
                    Text("\(DurationFormatting.compact(minutes: Int(output.averageActualMinutes.rounded())))")
                        .font(Typeface.body(12))
                        .foregroundStyle(output.deviation > 0 ? Theme.error : Theme.success)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, Theme.Padding.row)
            .padding(.vertical, 14)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
    }

    // MARK: - Helpers

    private func name(for key: CategoryKey) -> String {
        categoriesByID[key.categoryID]?.name ?? key.categoryID
    }
}