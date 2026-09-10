import SwiftUI

/// The full log, grouped by day.
///
/// There is no design reference for this screen, so it stays inside the language the
/// others already establish: pinned header, card rows, the same guess-beside-actual
/// pairing. It ranks nothing and hides nothing — a commute, a call and time on a phone
/// all read the same way.
struct HistoryView: View {
    let sessions: [Session]
    let categories: [TaskCategory]
    let onStartAgain: (Session) -> Void
    let onDeleteSession: (Session) -> Void

    @State private var scope: Scope = .everything
    @State private var selected: Session?

    /// Built once per body evaluation rather than scanned per row.
    private var categoriesByID: [String: TaskCategory] { categories.indexedByID() }

    enum Scope: String, CaseIterable {
        case everything = "Everything"
        case estimated = "With a guess"

        /// Sessions logged without a guess still carry a real duration, they just have
        /// nothing to be compared against. Worth being able to set them aside.
        func includes(_ session: Session) -> Bool {
            switch self {
            case .everything: return true
            case .estimated: return session.estimatedMinutes != nil
            }
        }
    }

    /// Closed sessions, newest day first, newest session first within a day.
    private var days: [(date: Date, sessions: [Session])] {
        let closed = sessions
            .filter { $0.isClosed && scope.includes($0) }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }

        let grouped = Dictionary(grouping: closed) {
            Calendar.current.startOfDay(for: $0.endedAt ?? .distantPast)
        }
        return grouped
            .map { (date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    /// Sessions that auto-closed against a ceiling. Kept visible as outliers rather
    /// than deleted, so they can be seen and corrected.
    private var flagged: [Session] {
        sessions.filter { $0.isClosed && $0.isFlaggedLowConfidence }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if days.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(days, id: \.date) { day in
                            daySection(day.date, day.sessions)
                        }
                    }
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $selected) { session in
            SessionDetailView(
                session: session,
                categoryName: session.categoryID.flatMap { categoriesByID[$0] }?.name ?? session.title,
                history: sessions.records,
                onDismiss: { selected = nil },
                // Dismissing this sheet and presenting the capture sheet in the very
                // same action can race: SwiftUI has been seen to hand the new sheet's
                // content closure a stale snapshot of state set in that same call,
                // which showed up here as "Start again" opening a blank capture screen
                // instead of the pre-filled one. Deferring to the next run loop tick
                // lets this sheet's dismissal finish first.
                onStartAgain: session.categoryID != nil ? {
                    selected = nil
                    DispatchQueue.main.async {
                        onStartAgain(session)
                    }
                } : nil,
                onDelete: {
                    selected = nil
                    onDeleteSession(session)
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("History")
                    .font(Typeface.title(22))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Caption(totalSummary)
            }
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 22)
            .padding(.bottom, 6)

            HStack(spacing: 8) {
                ForEach(Scope.allCases, id: \.self) { option in
                    Button {
                        scope = option
                    } label: {
                        Text(option.rawValue)
                            .font(option == scope ? Typeface.medium(12) : Typeface.body(12))
                            .foregroundStyle(option == scope ? Theme.bg : Theme.inkFaint)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background {
                                if option == scope { Capsule().fill(Theme.ink) }
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
    }

    private var totalSummary: String {
        let count = days.reduce(0) { $0 + $1.sessions.count }
        return "\(count) logged"
    }

    private var empty: some View {
        VStack {
            Spacer()
            CardSurface(radius: Theme.Radius.row, padding: 16) {
                Text("Nothing logged yet. Anything you start and finish shows up here.")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Padding.screen)
            Spacer()
            Spacer()
        }
    }

    // MARK: - One day

    private func daySection(_ date: Date, _ sessions: [Session]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayLabel(date))
                    .font(Typeface.title(15))
                    .foregroundStyle(Theme.ink)
                Spacer()
                // A factual total for the day. No target, nothing to be under or over.
                Caption(DurationFormatting.compact(minutes: totalMinutes(sessions)))
            }
            .padding(.bottom, 2)

            ForEach(sessions) { session in
                Button { selected = session } label: {
                    HistoryRow(session: session, categoriesByID: categoriesByID)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private func totalMinutes(_ sessions: [Session]) -> Int {
        sessions.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        // Inside the last week a weekday name reads faster than a date.
        if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

/// A logged session in the history list. Carries the same guess-beside-actual pairing
/// as the home list, plus how far off it was, which is the thing this screen is for.
struct HistoryRow: View {
    let session: Session
    let categoriesByID: [String: TaskCategory]

    private var symbol: String {
        session.categoryID.flatMap { categoriesByID[$0] }?.symbolName ?? "circle"
    }

    /// Only meaningful where a guess exists to have been wrong about.
    private var deviation: Double? {
        guard let guess = session.estimatedMinutes, guess > 0,
              let actual = session.actualMinutes else { return nil }
        return Double(actual) / Double(guess) - 1
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(symbolName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(session.title)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)

                    if session.contextTag != .normal {
                        Text(session.contextTag.rawValue)
                            .font(Typeface.body(10.5))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.pill, in: .capsule)
                    }
                }

                HStack(spacing: 6) {
                    Caption(
                        session.estimatedMinutes.map {
                            "guessed \(DurationFormatting.compact(minutes: $0))"
                        } ?? (session.wasTrackedPassively ? "tracked, not estimated" : "not estimated"),
                        size: 12
                    )

                    if let deviation, abs(deviation) >= 0.005 {
                        Caption("·", size: 12)
                        Text(DurationFormatting.signedPercent(deviation))
                            .font(Typeface.body(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DurationFormatting.compact(minutes: session.actualMinutes ?? 0))
                    .font(Typeface.title(16))
                    .foregroundStyle(Theme.ink)
                Caption(endedLabel, size: 11)
            }
        }
        .padding(.horizontal, Theme.Padding.row)
        .padding(.vertical, 14)
        .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.row)
                .strokeBorder(
                    session.isFlaggedLowConfidence ? Color.white.opacity(0.18) : Theme.line,
                    lineWidth: 1
                )
        }
    }

    private var endedLabel: String {
        // A flagged session says so plainly rather than passing as ordinary data.
        if session.isFlaggedLowConfidence { return "auto-closed" }
        guard let ended = session.endedAt else { return "" }
        return ended.formatted(.dateTime.hour().minute())
    }
}
