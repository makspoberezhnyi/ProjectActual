import SwiftUI
import Charts

/// One category's history, drawn as a line: is this getting better, worse, or holding
/// steady, rather than only its current deviation.
///
/// A single number can't show direction on its own. This is the same series the drift
/// detector already watches, just formatted into something glanceable.
struct CategoryTrendView: View {
    let name: String
    let output: BiasEngineOutput
    let history: [BiasEngine.HistoryPoint]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// `AdaptiveColor` resolves itself for `.foregroundStyle()`/`.fill()`, but Swift
    /// Charts' gradient wants a concrete `[Color]`, so this picks the matching one by
    /// hand rather than hardcoding a single mode.
    private var resolvedAccent: Color {
        colorScheme == .dark ? Theme.accent.dark : Theme.accent.light
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                summary

                if history.count >= 2 {
                    chart
                        .padding(.horizontal, Theme.Spacing.screen)
                        .padding(.top, 28)
                        .frame(height: 220)
                } else {
                    Caption("Not enough history yet to draw a trend for this one.")
                        .padding(.horizontal, Theme.Spacing.screen)
                        .padding(.top, 40)
                }

                if output.driftFlag {
                    driftNote
                        .padding(.horizontal, Theme.Spacing.screen)
                        .padding(.top, 20)
                }

                Spacer()
            }
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Caption("Trend")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 22)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(Typeface.title(24))
                .foregroundStyle(Theme.primaryText)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DurationFormatting.signedPercent(output.deviation))
                    .font(Typeface.display(30))
                    .foregroundStyle(Theme.accent)
                Caption("right now, \(output.deviationDescription)", size: 13)
            }

            CountBadge(text: "\(output.instanceCount) sessions")
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 18)
    }

    /// The line reads in the same units as everywhere else on the screen: percent off,
    /// signed, zero meaning a spot-on guess. Plotting the raw multiplier would force
    /// the reader to do the "minus one" conversion themselves.
    private var chart: some View {
        Chart {
            RuleMark(y: .value("Spot on", 0))
                .foregroundStyle(Theme.tertiaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))

            ForEach(Array(history.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Session", point.instanceCount),
                    y: .value("Off by", (point.multiplier - 1) * 100)
                )
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Session", point.instanceCount),
                    y: .value("Off by", (point.multiplier - 1) * 100)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [resolvedAccent.opacity(0.18), resolvedAccent.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel().foregroundStyle(Theme.tertiaryText)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(Theme.border)
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text("\(Int(percent))%")
                    }
                }
                .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    private var driftNote: some View {
        CardSurface(radius: Theme.Radius.row, padding: 15) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Shifted recently")
                        .font(Typeface.medium(13))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                }
                Text("This moved quickly in the last stretch on the chart above, worth a second look if something in this routine changed.")
                    .font(Typeface.body(12.5))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.row)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}
