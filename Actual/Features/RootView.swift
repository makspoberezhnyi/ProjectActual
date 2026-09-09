import SwiftUI
import SwiftData

/// Where the app starts. Onboarding once, then the main shell for good.
struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    /// Set when the person clears their data from the profile screen, so the seed does
    /// not quietly put it back on the next launch.
    @AppStorage("hasClearedData") private var hasClearedData = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.dark.rawValue
    @Environment(\.modelContext) private var context

    /// A reminder opened from a link before the app was ready to show it.
    ///
    /// Handled here rather than inside the shell because a link can arrive during
    /// onboarding, when the shell does not exist yet. Dropping it there would lose the
    /// very thing the person tapped.
    @State private var pendingReminder: SharedReminder?

    /// Applied once, here, rather than read separately by every screen — every
    /// `Theme` colour already switches on the rendering trait collection, so this one
    /// modifier at the root is what actually flips them, and nothing below needs to
    /// know the setting exists.
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .dark
    }

    var body: some View {
        Group {
            if hasOnboarded {
                MainShell(pendingReminder: $pendingReminder)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.4)) { hasOnboarded = true }
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .onAppear {
            guard !hasClearedData else { return }
            SeedData.populateIfEmpty(context)
        }
        .onAppear { applyWindowAppearance() }
        .onChange(of: appearanceModeRaw) { _, _ in applyWindowAppearance() }
        .onOpenURL { url in
            if let shareID = PingLink.shareID(from: url) {
                markSentReminderDone(shareID: shareID)
                return
            }
            guard let reminder = SharedReminderLink.reminder(from: url) else { return }
            pendingReminder = reminder
        }
    }

    /// `.preferredColorScheme` sets the environment value SwiftUI's own semantic
    /// colours read, but a `sheet` or `fullScreenCover` gets its own presentation
    /// controller, and this app's `Theme` tokens resolve against the actual
    /// `UITraitCollection` of whatever window is drawing them — which that
    /// environment override does not reliably reach. Setting it directly on every
    /// connected window is what actually makes a manual light/dark choice hold
    /// everywhere a sheet can open, not just on the screen underneath it.
    private func applyWindowAppearance() {
        let style: UIUserInterfaceStyle
        switch appearanceMode.colorScheme {
        case .light: style = .light
        case .dark: style = .dark
        default: style = .unspecified
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    /// Handles a completion ping arriving on the sender's own device.
    ///
    /// Nothing about duration, guess, or timing crosses over here, only the boolean
    /// fact recorded on the matching `SentReminder`: it happened.
    private func markSentReminderDone(shareID: String) {
        let descriptor = FetchDescriptor<SentReminder>(
            predicate: #Predicate { $0.shareID == shareID }
        )
        guard let sent = try? context.fetch(descriptor).first else { return }
        sent.recipientCompletedAt = .now
        try? context.save()
    }
}

/// The five destinations on the bottom bar. Only Home and Insights are built in this
/// slice; the rest are placeholders rather than pretend screens.
enum Destination: Hashable, CaseIterable {
    case home, log, capture, insights, profile
}

/// The persistent frame: a screen, the bottom bar, and the sheets the core loop moves
/// through.
struct MainShell: View {
    /// Held by the root, so a link that arrived during onboarding still gets shown.
    @Binding var pendingReminder: SharedReminder?

    @Environment(\.modelContext) private var context
    @Query private var sessions: [Session]
    @Query private var categories: [TaskCategory]
    @Query private var receivedReminders: [ReceivedReminder]
    @Query private var sentReminders: [SentReminder]

    #if DEBUG
    @State private var destination: Destination = LaunchOptions.destination
    @State private var isViewingActiveSession = false
    #else
    @State private var destination: Destination = .home
    @State private var isViewingActiveSession = false
    #endif
    /// The capture sheet, keyed on one Identifiable value rather than a Bool plus a
    /// separately-read prefill. Reading `capturePrefill` as its own @State var inside
    /// a `.sheet(isPresented:)` closure genuinely raced in testing — the closure was
    /// observed evaluating with a stale nil prefill a few milliseconds after the
    /// variable had already been set to a real value, most likely because presenting
    /// this sheet from inside the very action that dismisses another one is exactly
    /// the ordering SwiftUI does not guarantee. `.sheet(item:)` sidesteps the question
    /// entirely: a new identity is a new presentation, full stop, with everything the
    /// sheet needs carried inside that one value instead of read separately.
    private struct CaptureRequest: Identifiable {
        let id = UUID()
        var prefill: EstimateCaptureView.Prefill?
    }
    #if DEBUG
    @State private var captureRequest: CaptureRequest? = LaunchOptions.opensCapture
        ? CaptureRequest(prefill: nil) : nil
    #else
    @State private var captureRequest: CaptureRequest?
    #endif

    /// The session just closed, held so the end screen can show its outcome.
    @State private var justEnded: Session?
    /// A quick-started session waiting to be told what it was.
    @State private var awaitingResolution: Session?
    /// Stage 5's single follow-up: one prompt the next time the app opens, never a
    /// repeating timer.
    @State private var hasPromptedForUnresolved = false

    @State private var schedule = ScheduleSource()
    @State private var routes = RouteBaselineService()
    @State private var trips = TripMonitor(detector: TripProgressDetector(configuration: {
        var configuration = TripProgressDetector.Configuration.standard
        #if DEBUG
        if let dwell = LaunchOptions.dwellSeconds { configuration.dwellSeconds = dwell }
        #endif
        return configuration
    }()))
    @State private var isViewingGapFiller = false
    @State private var isViewingTripMap = false

    @State private var isComposingReminder = false
    /// Suppressed for this launch once the person says "later", so the prompt does not
    /// reappear the moment the sheet closes.
    @State private var dismissedPrompts: Set<String> = []

    /// Which session the full-screen timer is showing. Tracked by identity rather than
    /// by "whichever is running", since more than one can be open at once and picking
    /// the first would end the wrong one.
    @State private var activeSessionID: UUID?

    private var runningSessions: [Session] {
        sessions
            .filter(\.isRunning)
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    /// The open stretch happening right now, if there is one worth suggesting into.
    private var freeWindow: TimeWindow? {
        #if DEBUG
        if let minutes = LaunchOptions.fakeGapMinutes {
            return TimeWindow(start: .now, end: Date.now.addingTimeInterval(Double(minutes) * 60))
        }
        #endif
        // Nothing to suggest into while something is already running.
        guard runningSessions.isEmpty else { return nil }
        return schedule.currentGap()
    }

    private var nextCommitmentTitle: String? {
        #if DEBUG
        if LaunchOptions.fakeGapMinutes != nil { return "picking up the kids" }
        #endif
        return schedule.nextCommitment?.title
    }

    private var categoryNames: [String: String] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    }

    private var categoriesByID: [String: TaskCategory] { categories.indexedByID() }

    private var suggestions: [Suggestion] {
        guard let freeWindow else { return [] }
        return SuggestionRanker().suggestions(
            for: freeWindow,
            history: sessions.records,
            categoryNames: categoryNames,
            categorySymbols: Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.symbolName) }),
            // A commute is travel to a fixed place, not something you choose to do with
            // a free hour at home. Offering one would be noise, however frequent it is.
            excluding: Set(categories.filter(\.isTrip).map(\.id)),
            pending: schedule.pending
        )
    }

    /// A plain fact about where time like this has actually gone, stated without a
    /// verdict attached. Absent rather than invented when there is nothing to say.
    private var honestNote: String? {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) else { return nil }
        let recent = sessions.filter { $0.isClosed && ($0.endedAt ?? .distantPast) >= cutoff }

        let total = recent.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
        let passive = recent.filter(\.wasTrackedPassively).reduce(0) { $0 + ($1.actualMinutes ?? 0) }
        guard total > 0, passive > 0 else { return nil }

        // "About 0%" is a worse thing to say than the truth, which is that it rounds
        // to almost nothing.
        let proportion = Double(passive) / Double(total) * 100
        let amount = proportion < 1 ? "less than 1%" : "about \(Int(proportion.rounded()))%"
        return "Over the last month, \(amount) of your logged time went to your phone. Just what's true, no judgment either way."
    }

    /// Reminders accepted from others and not yet done.
    private var pendingReminders: [ReceivedReminder] {
        receivedReminders
            .filter { $0.state == .pending || $0.state == .expired }
            .sorted { $0.windowEnd < $1.windowEnd }
    }

    /// The reminder to step in about right now, if any.
    ///
    /// A fitting window is the primary trigger. A single fallback still fires as the
    /// window closes, so something the person accepted does not simply lapse unmentioned.
    private var promptableReminder: (reminder: ReceivedReminder, window: TimeWindow)? {
        guard runningSessions.isEmpty else { return nil }

        let candidates = receivedReminders.filter {
            $0.state == .pending && !dismissedPrompts.contains($0.shareID)
        }
        guard !candidates.isEmpty else { return nil }

        if let window = freeWindow, let fitting = candidates.first(where: { $0.fits(window) }) {
            return (fitting, window)
        }

        // Closing soon and still not done: say something once rather than let it lapse.
        let closingSoon = candidates.filter {
            $0.windowEnd.timeIntervalSinceNow < 2 * 3600 && $0.windowEnd > .now
        }
        guard let urgent = closingSoon.min(by: { $0.windowEnd < $1.windowEnd }) else { return nil }

        let remaining = TimeWindow(start: .now, end: urgent.windowEnd)
        return (urgent, remaining)
    }

    private var presentedSession: Session? {
        guard let activeSessionID else { return nil }
        return sessions.first { $0.uuid == activeSessionID }
    }

    /// Closed sessions still missing a category. They contribute nothing to the bias
    /// engine until resolved, which is exactly why they stay visible.
    private var unresolved: [Session] {
        sessions
            .filter { $0.isClosed && !$0.isResolved }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch destination {
                case .home:
                    HomeView(
                        sessions: sessions,
                        categories: categories,
                        unresolved: unresolved,
                        freeWindow: freeWindow,
                        nextCommitment: nextCommitmentTitle,
                        onOpenGapFiller: { isViewingGapFiller = true },
                        reminders: pendingReminders,
                        onComposeReminder: { isComposingReminder = true },
                        onOpenSession: { open($0) },
                        onEndSession: end,
                        onResolve: { awaitingResolution = $0 },
                        onStartAgain: startAgain,
                        onDeleteSession: deleteSession
                    )
                case .insights:
                    InsightsView(sessions: sessions, categories: categories)
                case .log:
                    HistoryView(sessions: sessions, categories: categories, onStartAgain: startAgain, onDeleteSession: deleteSession)
                case .profile:
                    ProfileView(sessions: sessions, categories: categories, sentReminders: sentReminders)
                case .capture:
                    // Not a destination of its own: the centre button opens capture as
                    // a sheet over whatever screen you were already on.
                    HomeView(
                        sessions: sessions,
                        categories: categories,
                        unresolved: unresolved,
                        freeWindow: freeWindow,
                        nextCommitment: nextCommitmentTitle,
                        onOpenGapFiller: { isViewingGapFiller = true },
                        reminders: pendingReminders,
                        onComposeReminder: { isComposingReminder = true },
                        onOpenSession: { open($0) },
                        onEndSession: end,
                        onResolve: { awaitingResolution = $0 },
                        onStartAgain: startAgain,
                        onDeleteSession: deleteSession
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomBar(
                destination: $destination,
                onCapture: { captureRequest = CaptureRequest(prefill: nil) }
            )
        }
        .sheet(item: $captureRequest) { request in
            EstimateCaptureView(
                categories: categories,
                history: sessions.records,
                prefill: request.prefill,
                onStart: start
            )
        }
        .fullScreenCover(isPresented: $isViewingActiveSession) {
            if let session = presentedSession {
                SessionActiveView(
                    session: session,
                    history: sessions.records,
                    onEnd: {
                        isViewingActiveSession = false
                        end(session)
                    },
                    onDismiss: { isViewingActiveSession = false },
                    onShowMap: isTrip(session) ? { isViewingTripMap = true } : nil
                )
                .fullScreenCover(isPresented: $isViewingTripMap) {
                    TripMapView(session: session, onDismiss: { isViewingTripMap = false })
                }
            }
        }
        #if DEBUG
        .task {
            if LaunchOptions.opensActiveSession, let running = runningSessions.first {
                open(running)
            }
            guard LaunchOptions.endsRunningSession, let running = runningSessions.first else { return }
            end(running)
        }
        #endif
        .sheet(isPresented: $isViewingGapFiller) {
            if let freeWindow {
                GapFillerView(
                    window: freeWindow,
                    nextCommitment: nextCommitmentTitle,
                    suggestions: suggestions,
                    honestNote: honestNote,
                    onChoose: { choose($0, in: freeWindow) },
                    onDismiss: { isViewingGapFiller = false }
                )
            }
        }
        .task {
            reconcileLiveActivity()
            SessionOperations.closeAbandoned(sessions, context: context)
            await schedule.refresh()
            SessionOperations.expireLapsed(receivedReminders, context: context)
        }
        .sheet(item: $pendingReminder) { reminder in
            ReceiveReminderView(
                reminder: reminder,
                onAccept: { sharesCompletion in accept(reminder, sharesCompletion: sharesCompletion) },
                onDecline: { pendingReminder = nil }
            )
        }
        .onChange(of: pendingReminder?.shareID) { _, shareID in
            // Opening the same link twice should not produce a second copy.
            guard let shareID,
                  receivedReminders.contains(where: { $0.shareID == shareID })
            else { return }
            pendingReminder = nil
        }
        .sheet(isPresented: $isComposingReminder) { ShareReminderView() }
        .overlay(alignment: .bottom) {
            if let promptable = promptableReminder, !isViewingGapFiller, captureRequest == nil {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .onTapGesture { dismissedPrompts.insert(promptable.reminder.shareID) }

                    ReminderPromptView(
                        reminder: promptable.reminder,
                        window: promptable.window,
                        onStart: { start(promptable.reminder, estimatedMinutes: $0) },
                        onLater: { dismissedPrompts.insert(promptable.reminder.shareID) }
                    )
                }
                .transition(.opacity)
            }
        }
        .sheet(item: $awaitingResolution) { session in
            SessionResolutionView(
                session: session,
                categories: categories,
                history: sessions.records,
                onResolve: { categoryID, title, tag in
                    resolve(session, categoryID: categoryID, title: title, contextTag: tag)
                },
                onDismiss: { awaitingResolution = nil }
            )
        }
        .task {
            // One prompt, once, rather than nagging on a timer.
            guard !hasPromptedForUnresolved else { return }
            hasPromptedForUnresolved = true
            if awaitingResolution == nil, let oldest = unresolved.last {
                awaitingResolution = oldest
            }
        }
        .sheet(item: $justEnded) { ended in
            SessionEndView(session: ended, history: sessions.records, pingURL: SessionOperations.pingURL(for: ended, receivedReminders: receivedReminders)) {
                justEnded = nil
            }
        }
    }

    // MARK: - The loop

    private func start(_ draft: SessionDraft) {
        // Quick start: only the guess and the start time are known now. Category and
        // context are deliberately left null until the person actually knows what they
        // logged, which is the moment it ends.
        let isQuickStart = draft.title.isEmpty
        // Held as an object rather than looked up again by id. A category created a
        // moment ago is not yet in the query results, so a second lookup would find
        // nothing and the trip would never be watched.
        let category = isQuickStart ? nil : resolveCategory(named: draft.title)

        let session = Session(
            categoryID: category?.id,
            title: isQuickStart ? "Unlabelled session" : draft.title,
            contextTag: draft.contextTag,
            estimatedMinutes: draft.estimatedMinutes,
            startedAt: .now
        )
        context.insert(session)

        // A destination turns this category into a trip, and gives the routing service
        // somewhere to route to.
        if let destination = draft.destination, let category {
            category.isTrip = true
            category.destinationName = destination.name
            category.destinationLatitude = destination.latitude
            category.destinationLongitude = destination.longitude
        }

        try? context.save()

        captureRequest = nil
        open(session)
        announce(session)
        fetchBaseline(for: session, category: category)
        beginTripMonitoring(for: session, category: category)
    }

    private func deleteSession(_ session: Session) {
        SessionOperations.deleteSession(session, context: context)
    }

    /// Opens the same review screen a fresh capture uses, pre-filled with the
    /// category and context already settled — a second look at the guess, not a
    /// silent instant start. Starting immediately would leave no moment to catch an
    /// estimate that has since drifted, or simply to change one's mind about the
    /// number before the clock is actually running.
    ///
    /// Repeats a past session: same category, same context, started now, with the
    /// current recalibrated estimate rather than whatever was guessed last time — the
    /// point is skipping the category picker, not freezing the estimate in the past.
    /// Not a duplicate of `start(_:)`: that one exists to turn typed or spoken text
    /// into a category, this one already has a real `TaskCategory` in hand and should
    /// never re-run name matching against it.
    private func startAgain(_ past: Session) {
        guard let categoryID = past.categoryID, let category = categoriesByID[categoryID]
        else { return }

        let estimate = SessionOperations.expectedMinutes(for: past, history: sessions.records)

        captureRequest = CaptureRequest(
            prefill: EstimateCaptureView.Prefill(
                title: category.name,
                contextTag: past.contextTag,
                estimatedMinutes: estimate ?? past.estimatedMinutes ?? 30
            )
        )
    }

    private func isTrip(_ session: Session) -> Bool {
        SessionOperations.isTrip(session, categoriesByID: categoriesByID)
    }

    /// Puts a newly started session on the lock screen and refreshes the widget.
    private func announce(_ session: Session) {
        guard let start = session.clockStart else { return }

        // History alone, never the stored guess re-multiplied. See HomeView for why.
        let expected = SessionOperations.expectedMinutes(for: session, history: sessions.records)

        LiveActivityController.shared.start(
            sessionID: session.uuid,
            title: session.title,
            contextTag: session.contextTag.rawValue,
            startedAt: start,
            expectedMinutes: expected
        )
    }

    /// Starts watching a trip so it can end itself.
    ///
    /// Only for a category with somewhere to go. Everything else still needs an explicit
    /// stop, because guessing when a work session truly ended without an external signal
    /// is unreliable and would corrupt the data the engine depends on.
    private func beginTripMonitoring(for session: Session, category: TaskCategory?) {
        guard let category, category.isTrip,
              let latitude = category.destinationLatitude,
              let longitude = category.destinationLongitude
        else {
            tripLog.notice("not watching: category \(category?.name ?? "none"), isTrip \(category?.isTrip ?? false), hasDestination \(category?.hasDestination ?? false)")
            return
        }

        let sessionID = session.uuid

        // The session object is captured directly. Looking it up in the query results
        // would search a snapshot taken before this session was inserted, so the
        // callbacks would quietly find nothing and the trip would never close itself.
        trips.onRouteUpdate = { [session] points in
            session.routeData = RouteCodec.encode(points)
            try? context.save()
        }

        trips.onDeparture = { [session, category] departed in
            guard session.isRunning else { return }
            session.departedAt = departed
            try? context.save()
            LiveActivityController.shared.update(
                startedAt: departed,
                expectedMinutes: SessionOperations.expectedMinutes(for: session, history: sessions.records)
            )

            // The baseline fetched at the tap can already be stale by the time the
            // person actually leaves — prep time, a delayed goodbye, a last-minute
            // errand first. Refetching against real departure means the number on
            // screen reflects the traffic that is actually there, not whatever it was
            // when the button was pressed.
            if let latitude = category.destinationLatitude,
               let longitude = category.destinationLongitude {
                Task { [session] in
                    guard let minutes = await routes.baselineMinutes(
                        toLatitude: latitude, longitude: longitude
                    ) else { return }
                    guard session.isRunning else { return }
                    session.apiBaselineMinutes = minutes
                    try? context.save()
                }
            }
        }

        trips.onArrival = { [session] arrived in
            guard session.isRunning else { return }
            session.endedAt = arrived
            try? context.save()
            LiveActivityController.shared.stop()

            // Closed by arriving rather than by tapping, so the outcome is shown the
            // same way it would have been either way.
            isViewingActiveSession = false
            justEnded = session
        }

        trips.begin(
            destination: Coordinate(latitude: latitude, longitude: longitude),
            origin: routes.lastKnownCoordinate,
            sessionID: sessionID
        )
    }

    /// Brings the lock screen back in line with what is actually running.
    ///
    /// Both directions matter. A session ended from the widget or by arriving can leave
    /// a timer stranded, and a session *started* from the widget has no activity at all,
    /// because that intent runs in the extension rather than the app. Neither should
    /// depend on the person noticing.
    private func reconcileLiveActivity() {
        guard let running = runningSessions.first else {
            LiveActivityController.shared.endStrandedActivities()
            return
        }
        announce(running)
    }

    /// One call, at the moment the trip starts, and never on a poll.
    ///
    /// Deliberately fire and forget: the session is already open and already recording.
    /// If the call fails the baseline stays nil, which every screen below already
    /// handles, and the trip behaves exactly as it would if this feature did not exist.
    private func fetchBaseline(for session: Session, category: TaskCategory?) {
        guard let category, category.isTrip,
              let latitude = category.destinationLatitude,
              let longitude = category.destinationLongitude
        else { return }

        Task {
            guard let minutes = await routes.baselineMinutes(
                toLatitude: latitude, longitude: longitude
            ) else { return }

            session.apiBaselineMinutes = minutes
            try? context.save()
        }
    }

    /// Whatever is chosen runs through the same loop as anything else. The suggestion
    /// engine never blocks or judges the eventual choice, it only offers into the gap.
    private func choose(_ suggestion: Suggestion, in window: TimeWindow) {
        isViewingGapFiller = false

        let categoryID: String?
        let estimate: Int?

        switch suggestion.source {
        case .history(let id):
            categoryID = id
            estimate = suggestion.typicalMinutes
        case .planning:
            // Never logged through the app before, so there is no honest number to
            // pre-fill. Recalibration starts on its next occurrence.
            categoryID = resolveCategory(named: suggestion.title).id
            estimate = nil
        }

        let session = Session(
            categoryID: categoryID,
            title: suggestion.title,
            contextTag: .normal,
            estimatedMinutes: estimate,
            startedAt: .now
        )
        context.insert(session)
        try? context.save()
        open(session)
    }

    // MARK: - Reminders from other people

    private func accept(_ reminder: SharedReminder, sharesCompletion: Bool) {
        let stored = ReceivedReminder(accepting: reminder)
        stored.sharesCompletion = sharesCompletion
        context.insert(stored)
        try? context.save()
        pendingReminder = nil
    }

    /// From here it runs through the same loop as anything else, and stops being a
    /// special object at all.
    private func start(_ reminder: ReceivedReminder, estimatedMinutes: Int) {
        let session = Session(
            categoryID: resolveCategory(named: reminder.title).id,
            title: reminder.title,
            contextTag: .normal,
            estimatedMinutes: estimatedMinutes,
            startedAt: .now,
            sourceReminderShareID: reminder.shareID
        )
        context.insert(session)

        reminder.state = .started
        reminder.sessionID = session.uuid
        try? context.save()

        open(session)
    }

    private func open(_ session: Session) {
        activeSessionID = session.uuid
        isViewingActiveSession = true
    }

    private func resolveCategory(named title: String) -> TaskCategory {
        SessionOperations.resolveCategory(named: title, categories: categories, context: context)
    }

    /// Closing writes the actual duration immediately. No confirmation prompt, no
    /// "was this right" step: the system is recording, not asking for agreement.
    private func end(_ session: Session) {
        trips.stop()
        LiveActivityController.shared.stop()
        session.endedAt = .now

        if let shareID = session.sourceReminderShareID,
           let reminder = receivedReminders.first(where: { $0.shareID == shareID }) {
            reminder.state = .done
        }
        try? context.save()

        // The duration is written either way. What is still missing on a quick start is
        // what it counts toward, and that is asked before the outcome is shown.
        if session.isResolved {
            justEnded = session
        } else {
            awaitingResolution = session
        }
    }

    /// Applies the label chosen at the end. From this point the session is treated
    /// exactly like one categorised at the start, with no distinction left between them.
    private func resolve(
        _ session: Session,
        categoryID: String?,
        title: String,
        contextTag: ContextTag
    ) {
        session.categoryID = categoryID ?? resolveCategory(named: title).id
        session.title = title
        session.contextTag = contextTag
        try? context.save()

        awaitingResolution = nil
        // Only worth showing an outcome for a session that was just now ended.
        if session.endedAt.map({ Date.now.timeIntervalSince($0) < 60 }) == true {
            justEnded = session
        }
    }
}

/// The bottom bar from the design: four glyphs around a filled centre action.
struct BottomBar: View {
    @Binding var destination: Destination
    let onCapture: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, symbol: "house.fill", label: "Home")
            tab(.log, symbol: "line.3.horizontal", label: "History")

            captureButton
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Start a session")

            tab(.insights, symbol: "chart.bar.fill", label: "Insights")
            tab(.profile, symbol: "person", label: "Profile")
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            VStack(spacing: 0) {
                Hairline()
                Theme.bg
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// Liquid Glass where it fits best: the one floating, un-anchored control in the
    /// whole app, the same kind of accessory a system tab bar puts glass on. Older
    /// OSes keep the plain filled-circle look — there is nothing to fall back *to*,
    /// glass is additive polish on a control that already works without it.
    @ViewBuilder
    private var captureButton: some View {
        if #available(iOS 26.0, *) {
            // Plain `.glass`, not `.glassProminent`: prominent fills with the tint and
            // always draws white content on top, which on this app's near-white dark-mode
            // accent left the "+" nearly invisible against its own background. Plain
            // glass draws the icon in the colour it's actually given instead.
            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        } else {
            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 46, height: 46)
                    .background(Theme.accent, in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private func tab(_ target: Destination, symbol: String, label: String) -> some View {
        Button {
            destination = target
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(destination == target ? Theme.ink : Theme.inkFaint)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(destination == target ? .isSelected : [])
    }
}
