import SwiftUI

/// What the capture screen hands back. The category is resolved by the shell, since
/// creating one needs the store.
struct SessionDraft {
    var title: String
    var contextTag: ContextTag
    var estimatedMinutes: Int?
    /// Set when the person picked somewhere to go, which marks this as a trip.
    var destination: (name: String, latitude: Double, longitude: Double)?
}

/// Estimate capture. A guess, a context, and — once there is enough history — the
/// number the person's own past says is more likely.
///
/// Both numbers stay on screen together. Seeing your own two hours next to the app's
/// two forty is what produces the recognition; hiding the raw guess afterward would
/// turn an honest mirror into a corrections notice.
struct EstimateCaptureView: View {
    /// What to open the screen already knowing — repeating a past session, say, where
    /// the category and context are already settled and only the guess is worth a
    /// second look, not a fresh trip through the category field.
    struct Prefill {
        var title: String
        var contextTag: ContextTag
        var estimatedMinutes: Int
    }

    let categories: [TaskCategory]
    let history: [SessionRecord]
    let onStart: (SessionDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var contextTag: ContextTag
    @State private var guessMinutes: Int
    @State private var customTagName: String = ""
    @State private var isAddingCustomTag = false
    @State private var isPickingCustomDuration = false
    @State private var isPickingDestination = false
    @State private var destination: (name: String, latitude: Double, longitude: Double)?

    private let engine = BiasEngine()
    private let presets: [Int] = [30, 60, 120, 180]

    init(
        categories: [TaskCategory],
        history: [SessionRecord],
        prefill: Prefill? = nil,
        onStart: @escaping (SessionDraft) -> Void
    ) {
        self.categories = categories
        self.history = history
        self.onStart = onStart

        if let prefill {
            _title = State(initialValue: prefill.title)
            _contextTag = State(initialValue: prefill.contextTag)
            _guessMinutes = State(initialValue: prefill.estimatedMinutes)
        } else {
            #if DEBUG
            _title = State(initialValue: LaunchOptions.captureTitle)
            #else
            _title = State(initialValue: "")
            #endif
            _contextTag = State(initialValue: .normal)
            _guessMinutes = State(initialValue: 120)
        }
    }

    /// The context tags on offer: the fixed defaults, plus any custom tag the person
    /// has already used often enough to have earned a place beside them.
    private var availableTags: [ContextTag] {
        var tags = ContextTag.defaults
        let usage = Dictionary(grouping: history, by: \.contextTag).mapValues(\.count)
        let promoted = usage
            .filter { !$0.key.isDefault && $0.value >= 3 }
            .keys
            .sorted { $0.rawValue < $1.rawValue }
        tags.append(contentsOf: promoted)
        if !contextTag.isDefault && !tags.contains(contextTag) { tags.append(contextTag) }
        return tags
    }

    /// The matched category for whatever has been typed, if it is one the person
    /// already has history under.
    ///
    /// Matching is deliberately forgiving. Requiring someone to retype "Work session"
    /// character for character to see their own history would hide the one thing the
    /// product exists to show them. An exact match wins; failing that, a prefix match
    /// counts only while it is unambiguous, so "work" finds the work sessions but a
    /// prefix shared by two categories waits for more typing rather than guessing.
    private var matchedCategory: TaskCategory? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        if let exact = categories.first(where: { $0.name.lowercased() == trimmed }) {
            return exact
        }

        let prefixed = categories.filter { $0.name.lowercased().hasPrefix(trimmed) }
        return prefixed.count == 1 ? prefixed.first : nil
    }

    /// The engine's answer for this exact category and context, or nil during cold
    /// start — in which case no recalibrated number is shown at all.
    private var estimate: RecalibratedEstimate? {
        guard let category = matchedCategory else { return nil }
        return engine.recalibratedEstimate(
            rawGuessMinutes: guessMinutes,
            for: CategoryKey(categoryID: category.id, contextTag: contextTag),
            from: history
        )
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                titleField
                contextSection
                guessSection
                destinationRow

                if let estimate {
                    historyCard(estimate)
                        .padding(.horizontal, Theme.Padding.screen)
                        .padding(.top, 22)
                }

                Spacer(minLength: 12)
                actions
            }
        }
        .sheet(isPresented: $isPickingCustomDuration) { durationPicker }
        .sheet(isPresented: $isPickingDestination) {
            DestinationPickerView { name, latitude, longitude in
                destination = (name, latitude, longitude)
            }
        }
        .alert("New context", isPresented: $isAddingCustomTag) {
            TextField("Name it", text: $customTagName)
            Button("Cancel", role: .cancel) { customTagName = "" }
            Button("Add") {
                let tag = ContextTag(customTagName)
                if !tag.rawValue.isEmpty { contextTag = tag }
                customTagName = ""
            }
        } message: {
            Text("A fixed list will never cover everything. Name the situation you're actually in.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()
            Caption("New task")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private var titleField: some View {
        VStack(spacing: 16) {
            TextField(
                "",
                text: $title,
                prompt: Text("What are you about to do").foregroundStyle(Theme.inkFaint)
            )
            .font(Typeface.title(22))
            .foregroundStyle(Theme.ink)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled()

            Hairline()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Context

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Context")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(availableTags, id: \.self) { tag in
                    Chip(title: tag.displayName, isSelected: tag == contextTag) {
                        contextTag = tag
                    }
                }
                Chip(title: "+ custom", isDashed: true) { isAddingCustomTag = true }
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 24)
    }

    // MARK: - The guess

    private var guessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Your guess")

            Text(DurationFormatting.padded(minutes: guessMinutes))
                .font(Typeface.display(44))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    PresetChip(
                        title: DurationFormatting.compact(minutes: preset),
                        isSelected: guessMinutes == preset
                    ) {
                        guessMinutes = preset
                    }
                }
                PresetChip(title: "custom", isDashed: true) { isPickingCustomDuration = true }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 28)
    }

    /// Somewhere to go, for the trips that have one.
    ///
    /// A destination is what lets the app ask a routing service for an objective number
    /// to sit alongside the guess, so the trip has something besides the person's own
    /// history to be measured against.
    private var destinationRow: some View {
        Button {
            isPickingDestination = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destinationName == nil ? "mappin.and.ellipse" : "mappin.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(destinationName == nil ? Theme.inkFaint : Theme.accent)

                Text(destinationName ?? "Add a destination, if this is a trip")
                    .font(Typeface.body(13))
                    .foregroundStyle(destinationName == nil ? Theme.inkFaint : Theme.ink)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Theme.card, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var destinationName: String? {
        destination?.name ?? matchedCategory?.destinationName
    }

    // MARK: - What their history says

    @ViewBuilder
    private func historyCard(_ estimate: RecalibratedEstimate) -> some View {
        // Low confidence renders muted, so a number resting on six sessions does not
        // carry the same authority as one resting on forty.
        let isMuted = estimate.confidence == .low

        CardSurface(radius: Theme.Radius.panel, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: estimate.scope == .exact
                                 ? "BASED ON YOUR HISTORY"
                                 : "BASED ON THIS CATEGORY GENERALLY")
                    Spacer()
                    CountBadge(text: "\(estimate.instanceCount) sessions")
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(DurationFormatting.compact(minutes: estimate.minutes))
                        .font(Typeface.display(30))
                        .foregroundStyle(Theme.ink)
                        .opacity(isMuted ? 0.65 : 1)

                    if let trend = trendText(estimate) {
                        Caption(trend, size: 12)
                    }
                }

                Text(explanation(estimate))
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if isMuted {
                    Caption(estimate.confidence.label, size: 11.5)
                }
            }
        }
    }

    /// The longer read on direction, not the one-session delta. Absent rather than
    /// invented when there is not enough history behind it.
    private func trendText(_ estimate: RecalibratedEstimate) -> String? {
        guard let prior = estimate.priorMinutes, prior != estimate.minutes else { return nil }
        let rising = estimate.minutes > prior
        return "\(rising ? "\u{2191}" : "\u{2193}") \(rising ? "up" : "down") from \(DurationFormatting.compact(minutes: prior))"
    }

    /// Plain language, and always the person's own history as the reason. If they ask
    /// why the app expects this number, the answer is their last N sessions, not a model.
    private func explanation(_ estimate: RecalibratedEstimate) -> String {
        let percent = DurationFormatting.percent(estimate.output.deviation)
        let noun = contextTag.rawValue
        let subject = matchedCategory?.name.lowercased() ?? "sessions"

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

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                // Sometimes there is no moment to stop and pick a category. Start the
                // timer now; the label is asked for at the end, when the person already
                // knows what it was.
                PrimaryButton(title: "Start without a label") {
                    start(with: guessMinutes)
                }
                Caption("You'll say what it was when you stop.", size: 12)
            } else {
                HStack(spacing: 12) {
                    SecondaryButton(title: "Keep my guess") {
                        start(with: guessMinutes)
                    }

                    if let estimate {
                        PrimaryButton(title: "Use \(DurationFormatting.compact(minutes: estimate.minutes))") {
                            // Accepting the recalibrated number is one tap. Editing it
                            // instead is accepted immediately too, nothing to confirm.
                            start(with: estimate.minutes)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.bottom, 44)
    }

    private func start(with minutes: Int) {
        onStart(
            SessionDraft(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                contextTag: contextTag,
                estimatedMinutes: minutes,
                destination: destination
            )
        )
    }

    // MARK: - Custom duration

    private var durationPicker: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Picker("Minutes", selection: $guessMinutes) {
                    ForEach(Array(stride(from: 5, through: 480, by: 5)), id: \.self) { value in
                        Text(DurationFormatting.compact(minutes: value))
                            .foregroundStyle(Theme.ink)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
            }
            .navigationTitle("How long")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPickingCustomDuration = false }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}
