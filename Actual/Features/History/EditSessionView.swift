import SwiftUI

/// A correction, not a redo.
///
/// Reached from a swipe on a closed session, this fixes a mistake after the fact —
/// a mistyped title, the wrong context tag, a guess that was never entered, or start
/// and end times that drifted from what actually happened. It edits the session's own
/// fields directly rather than reopening `EstimateCaptureView`, which exists to start
/// something new, not to patch something already logged.
struct EditSessionView: View {
    /// What comes back on save. `RootView` decides how `startedAt` actually gets
    /// written — a trip with a real GPS departure keeps its clock on `departedAt`,
    /// which this view has no reason to know about.
    struct Edit {
        var title: String
        var contextTag: ContextTag
        var estimatedMinutes: Int?
        var startedAt: Date
        var endedAt: Date
    }

    let history: [SessionRecord]
    let onSave: (Edit) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var contextTag: ContextTag
    @State private var hasGuess: Bool
    @State private var guessMinutes: Int
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var isAddingCustomTag = false
    @State private var customTagName = ""

    init(session: Session, history: [SessionRecord], onSave: @escaping (Edit) -> Void, onCancel: @escaping () -> Void) {
        self.history = history
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: session.title)
        _contextTag = State(initialValue: session.contextTag)
        _hasGuess = State(initialValue: session.estimatedMinutes != nil)
        _guessMinutes = State(initialValue: session.estimatedMinutes ?? 30)
        _startedAt = State(initialValue: session.clockStart ?? session.startedAt ?? .now)
        _endedAt = State(initialValue: session.endedAt ?? .now)
    }

    /// Same rule as capture: the fixed defaults, plus any custom tag that has earned
    /// its place through use, plus whatever this session already carries even if it's
    /// neither.
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

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endedAt > startedAt
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleField
                        contextSection
                        guessSection
                        timesSection
                    }
                    .padding(.horizontal, Theme.Spacing.focused)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                }
                .scrollIndicators(.hidden)

                PrimaryButton(title: "Save changes") {
                    onSave(
                        Edit(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            contextTag: contextTag,
                            estimatedMinutes: hasGuess ? guessMinutes : nil,
                            startedAt: startedAt,
                            endedAt: endedAt
                        )
                    )
                }
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.4)
                .padding(.horizontal, Theme.Spacing.focused)
                .padding(.bottom, 24)
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
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
            Spacer()
            Caption("Edit session")
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 22)
    }

    // MARK: - Fields

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption("Title")
            TextField(
                "",
                text: $title,
                prompt: Text("What was this").foregroundStyle(Theme.tertiaryText)
            )
            .font(Typeface.body(15))
            .foregroundStyle(Theme.primaryText)
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.border, lineWidth: 1)
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption("Context")
            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(availableTags, id: \.self) { tag in
                    Chip(title: tag.displayName, isSelected: tag == contextTag) {
                        contextTag = tag
                    }
                }
                Chip(title: "+ custom", isDashed: true) { isAddingCustomTag = true }
            }
        }
    }

    private var guessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caption("Your guess")
                Spacer()
                Toggle("Had a guess", isOn: $hasGuess)
                    .labelsHidden()
                    .tint(Theme.accent)
            }

            if hasGuess {
                HStack {
                    Text(DurationFormatting.padded(minutes: guessMinutes))
                        .font(Typeface.display(26))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Stepper("", value: $guessMinutes, in: 5...600, step: 5)
                        .labelsHidden()
                }
            } else {
                Caption("Not estimated")
            }
        }
    }

    private var timesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption("When it actually happened")
            CardSurface(radius: Theme.Radius.row, padding: 14) {
                VStack(spacing: 12) {
                    DatePicker("Started", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.primaryText)
                    Hairline()
                    DatePicker("Ended", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.primaryText)
                }
            }

            if isValid {
                Caption(
                    "That's \(DurationFormatting.compact(minutes: Int(endedAt.timeIntervalSince(startedAt) / 60)))",
                    size: 12
                )
            } else {
                Text("End has to be after start.")
                    .font(Typeface.body(12))
                    .foregroundStyle(.red)
            }
        }
    }
}
