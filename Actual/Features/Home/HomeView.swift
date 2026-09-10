import SwiftUI

/// Home. Whatever is running now, then what has already happened today, stated flatly.
///
/// Nothing on this screen ranks a session as good or bad. A commute, a call and
/// twenty-four minutes on a phone are all listed the same way.
struct HomeView: View {
    let sessions: [Session]
    let categories: [TaskCategory]
    let unresolved: [Session]
    let freeWindow: TimeWindow?
    let nextCommitment: String?
    let onOpenGapFiller: () -> Void
    let reminders: [ReceivedReminder]
    let onComposeReminder: () -> Void
    let onOpenSession: (Session) -> Void
    let onEndSession: (Session) -> Void
    let onResolve: (Session) -> Void
    let onStartAgain: (Session) -> Void
    let onDeleteSession: (Session) -> Void

    @State private var selectedPastSession: Session?
    @AppStorage("displayName") private var displayName = "Marta"

    private let engine = BiasEngine()

    /// Built once per body evaluation rather than scanned per row.
    private var categoriesByID: [String: TaskCategory] { categories.indexedByID() }

    /// More than one thing can legitimately be running at once, so this is a list, not
    /// a single session. Newest first.
    private var running: [Session] {
        sessions
            .filter(\.isRunning)
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private var todaysClosed: [Session] {
        sessions
            .filter {
                $0.isClosed
                    && $0.isResolved
                    && Calendar.current.isDateInToday($0.endedAt ?? .distantPast)
            }
            // Chronological, so the day reads top to bottom the way it happened.
            .sorted { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
    }

    private var history: [SessionRecord] { sessions.records }

    var body: some View {
        VStack(spacing: 0) {
            // The greeting stays put. Letting it scroll meant content passing under the
            // status bar with nothing behind it, which reads as a glitch on a dark app.
            greeting

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if running.isEmpty {
                        if let freeWindow {
                            FreeWindowCard(
                                window: freeWindow,
                                nextCommitment: nextCommitment,
                                onOpen: onOpenGapFiller
                            )
                            .padding(.horizontal, Theme.Padding.screen)
                            .padding(.top, 18)
                        } else {
                            idleCard
                                .padding(.horizontal, Theme.Padding.screen)
                                .padding(.top, 18)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(running) { session in
                                ActiveSessionCard(
                                    session: session,
                                    expectedMinutes: expectedMinutes(for: session),
                                    onOpen: { onOpenSession(session) },
                                    onEnd: { onEndSession(session) }
                                )
                            }
                        }
                        .padding(.horizontal, Theme.Padding.screen)
                        .padding(.top, 18)
                    }

                    if !unresolved.isEmpty {
                        UnresolvedSessionsCard(sessions: unresolved, onResolve: onResolve)
                            .padding(.horizontal, Theme.Padding.screen)
                            .padding(.top, 24)
                    }

                    if !reminders.isEmpty {
                        remindersSection
                            .padding(.horizontal, Theme.Padding.screen)
                            .padding(.top, 24)
                    }

                    todaySection
                }
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selectedPastSession) { session in
            SessionDetailView(
                session: session,
                categoryName: session.categoryID.flatMap { categoriesByID[$0] }?.name ?? session.title,
                history: sessions.records,
                onDismiss: { selectedPastSession = nil },
                // See the matching comment in HistoryView: dismissing this sheet and
                // presenting the capture sheet in the same action can race.
                onStartAgain: session.categoryID != nil ? {
                    selectedPastSession = nil
                    DispatchQueue.main.async {
                        onStartAgain(session)
                    }
                } : nil,
                onDelete: {
                    selectedPastSession = nil
                    onDeleteSession(session)
                }
            )
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Caption(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    Text("\(timeOfDayGreeting), \(displayName)")
                        .font(Typeface.title(22))
                        .foregroundStyle(Theme.ink)
                }

                Spacer()

                Button(action: onComposeReminder) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send a reminder")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
        .padding(.bottom, 6)
        .background(Theme.bg)
    }

    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Nothing running

    private var idleCard: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 6) {
                Caption("Nothing running")
                Text("Start something")
                    .font(Typeface.title(16))
                    .foregroundStyle(Theme.ink)
                Text("Tap the plus below, or say \"starting a work session, guessing two hours\".")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Today

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(Typeface.title(16))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Caption("\(todaysClosed.count) logged")
            }
            .padding(.bottom, 4)

            if todaysClosed.isEmpty {
                Caption("Nothing logged yet today.")
            } else {
                ForEach(todaysClosed) { session in
                    Button { selectedPastSession = session } label: {
                        LoggedSessionRow(session: session, categoriesByID: categoriesByID)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 24)
    }

    /// Reminders other people sent. An expired one stays listed as a plain, undone
    /// item rather than disappearing.
    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("From others")
                .font(Typeface.title(15))
                .foregroundStyle(Theme.ink)

            ForEach(reminders) { reminder in
                HStack(spacing: 12) {
                    Image(systemName: reminder.state == .expired ? "clock.badge.xmark" : "envelope")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title)
                            .font(Typeface.medium(14))
                            .foregroundStyle(Theme.ink)
                        Caption(subtitle(for: reminder), size: 12)
                    }

                    Spacer()

                    if let minutes = reminder.senderEstimatedMinutes {
                        Caption(DurationFormatting.compact(minutes: minutes), size: 12.5)
                    }
                }
                .padding(.horizontal, Theme.Padding.row)
                .padding(.vertical, 14)
                .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                        .strokeBorder(Theme.line, lineWidth: 1)
                }
                .opacity(reminder.state == .expired ? 0.6 : 1)
            }
        }
    }

    private func subtitle(for reminder: ReceivedReminder) -> String {
        if reminder.state == .expired {
            return "from \(reminder.senderName) · didn't happen"
        }
        return "from \(reminder.senderName) · \(reminder.windowDescription.lowercased())"
    }

    /// How long this usually takes, drawn from history alone.
    ///
    /// Deliberately not the stored guess re-multiplied. Once someone accepts the app's
    /// corrected number, that number *is* the correction; running it through the
    /// multiplier a second time compounds it and shows an expectation nobody's history
    /// supports. The honest figure for "how long this usually takes you" never depends
    /// on what was guessed today.
    /// Nil during cold start, and the card then simply shows no expectation.
    private func expectedMinutes(for session: Session) -> Int? {
        // A quick start has no category yet, so there is nothing to compare it against.
        guard let categoryID = session.categoryID else { return nil }
        return engine.recalibratedEstimate(
            rawGuessMinutes: nil,
            for: CategoryKey(categoryID: categoryID, contextTag: session.contextTag),
            from: history
        )?.minutes
    }
}

/// The running session, with its live timer, how long this usually takes, and one tap
/// to end it.
struct ActiveSessionCard: View {
    let session: Session
    let expectedMinutes: Int?
    let onOpen: () -> Void
    let onEnd: () -> Void

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Caption("Active now", size: 12)
                        Text(session.title)
                            .font(Typeface.title(16))
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    TagPill(text: session.contextTag.rawValue)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = session.elapsedSeconds(now: context.date)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(DurationFormatting.clock(seconds: elapsed))
                                .font(Typeface.timer(42))
                                .tracking(-0.4)
                                .foregroundStyle(Theme.ink)

                            if let expectedMinutes {
                                Caption(
                                    "of ~\(DurationFormatting.compact(minutes: expectedMinutes)) expected",
                                    size: 12.5
                                )
                            }
                        }

                        if let expectedMinutes, expectedMinutes > 0 {
                            ProgressBar(
                                fraction: Double(elapsed) / Double(expectedMinutes * 60)
                            )
                        }
                    }
                }

                PrimaryButton(title: "End session", height: 46, action: onEnd)
                    .padding(.top, 2)
            }
        }
        .contentShape(.rect)
        .onTapGesture(perform: onOpen)
    }
}

/// One closed session in the Today list: what it was, what was guessed, what it took.
struct LoggedSessionRow: View {
    let session: Session
    let categoriesByID: [String: TaskCategory]

    private var symbol: String {
        session.categoryID.flatMap { categoriesByID[$0] }?.symbolName ?? "circle"
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(symbolName: symbol)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(Typeface.medium(14))
                    .foregroundStyle(Theme.ink)

                Caption(
                    session.estimatedMinutes.map {
                        "guessed \(DurationFormatting.compact(minutes: $0))"
                    } ?? "not estimated",
                    size: 12
                )
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(DurationFormatting.compact(minutes: session.actualMinutes ?? 0))
                    .font(Typeface.title(16))
                    .foregroundStyle(Theme.ink)

                // "actual" is underlined only where there is a guess to have been
                // wrong about; a passively tracked duration is just "tracked".
                if session.wasTrackedPassively {
                    Caption("tracked", size: 11)
                } else if session.estimatedMinutes != nil {
                    Text("actual")
                        .font(Typeface.body(11))
                        .foregroundStyle(Theme.inkSoft)
                        .underline(true, color: Color.white.opacity(0.25))
                } else {
                    Caption("actual", size: 11)
                }
            }
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
