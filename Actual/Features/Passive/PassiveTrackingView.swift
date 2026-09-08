import SwiftUI

/// Opt-in scope, the persistent indicator, and the trend the whole feature exists to
/// show: not just how long, but when in the day.
///
/// Nothing here is a blanket switch. Every app starts unselected, and turning one on is
/// a deliberate choice about that one app, never an assumption made on the person's
/// behalf.
struct PassiveTrackingView: View {
    @AppStorage("passiveTrackingAppIDs") private var storedAppIDs = ""
    @Environment(\.dismiss) private var dismiss

    private var enabledAppIDs: Set<String> {
        Set(storedAppIDs.split(separator: ",").map(String.init))
    }

    private var trends: [PassiveUsageAnalyzer.AppTrend] {
        guard !enabledAppIDs.isEmpty else { return [] }
        let provider = SeededAppUsageProvider(enabledAppIDs: enabledAppIDs)
        return PassiveUsageAnalyzer.trends(for: provider.intervals(on: .now))
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    intro

                    if !enabledAppIDs.isEmpty {
                        indicator
                            .padding(.horizontal, Theme.Padding.screen)
                            .padding(.top, 20)
                    }

                    scopeSection
                        .padding(.horizontal, Theme.Padding.screen)
                        .padding(.top, 26)

                    if !trends.isEmpty {
                        trendSection
                            .padding(.horizontal, Theme.Padding.screen)
                            .padding(.top, 28)
                    }
                }
                .padding(.bottom, 60)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            Spacer()
            Caption("Screen time")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A few apps, tracked honestly")
                .font(Typeface.title(22))
                .foregroundStyle(Theme.ink)
            Text("For the handful of apps you turn on below, Actual notices when they're open and for how long. It never sees what's inside them, only that they were open. Nothing is on until you choose it here.")
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 18)
    }

    /// Non-negotiable per the concept: whenever tracking is active, this stays visible
    /// rather than running silently in the background.
    private var indicator: some View {
        HStack(spacing: 8) {
            Circle().fill(Theme.accent).frame(width: 6, height: 6)
            Text("Tracking is on for \(enabledAppIDs.count) \(enabledAppIDs.count == 1 ? "app" : "apps")")
                .font(Typeface.body(12.5))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Theme.card, in: .capsule)
        .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
    }

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Apps eligible for tracking")

            VStack(spacing: 0) {
                ForEach(Array(TrackableApp.candidates.enumerated()), id: \.element.id) { index, app in
                    if index > 0 { Hairline() }
                    appRow(app)
                }
            }
            .padding(.horizontal, 4)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.panel)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
    }

    private func appRow(_ app: TrackableApp) -> some View {
        Toggle(isOn: Binding(
            get: { enabledAppIDs.contains(app.id) },
            set: { toggle(app.id, on: $0) }
        )) {
            HStack(spacing: 12) {
                Image(systemName: app.symbolName)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 18)
                Text(app.displayName)
                    .font(Typeface.body(14))
                    .foregroundStyle(Theme.ink)
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func toggle(_ appID: String, on: Bool) {
        var ids = enabledAppIDs
        if on { ids.insert(appID) } else { ids.remove(appID) }
        storedAppIDs = ids.sorted().joined(separator: ",")
    }

    // MARK: - Trend

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's pattern")
                .font(Typeface.title(15))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 10) {
                ForEach(trends) { trend in
                    TrendRow(trend: trend, name: displayName(for: trend.appID))
                }
            }
        }
    }

    private func displayName(for appID: String) -> String {
        TrackableApp.candidates.first { $0.id == appID }?.displayName ?? appID
    }
}

/// One app's day, split into its four bands as a small stacked bar, with the plain-fact
/// headline the feature exists for: when this actually happens, not just how much.
private struct TrendRow: View {
    let trend: PassiveUsageAnalyzer.AppTrend
    let name: String

    var body: some View {
        CardSurface(radius: Theme.Radius.row, padding: 15) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(name)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(DurationFormatting.compact(minutes: trend.totalMinutes))
                        .font(Typeface.medium(13))
                        .foregroundStyle(Theme.inkSoft)
                }

                bar

                Text(headline)
                    .font(Typeface.body(12))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(DayPart.allCases, id: \.self) { part in
                    let minutes = trend.minutesByPart[part] ?? 0
                    let fraction = trend.totalMinutes > 0 ? Double(minutes) / Double(trend.totalMinutes) : 0
                    Capsule()
                        .fill(minutes > 0 ? Theme.accent.opacity(0.35 + fraction * 0.5) : Theme.track)
                        .frame(width: max(4, geo.size.width * max(fraction, minutes > 0 ? 0.04 : 0)))
                }
            }
        }
        .frame(height: 8)
    }

    private var headline: String {
        guard trend.totalMinutes > 0 else { return "Nothing tracked today." }
        if let dominant = trend.dominantPart {
            return "Mostly \(dominant.label.lowercased()) today."
        }
        return "Spread fairly evenly through the day."
    }
}
