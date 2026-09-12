import SwiftUI

// The "what was this" step, shown the instant a quick-started session ends.
//
// The friction lands at the one point where it costs almost nothing: right after the
// person already knows what they just did, instead of making them stop and think before
// they have even started.
//
// Asking for the context here, seconds after the fact, stays close enough to the moment
// that it does not reopen the risk context tags exist to avoid — picking a tag long
// afterward specifically to explain away a result.
struct SessionResolutionView: View {
    let session: Session
    let categories: [TaskCategory]
    let history: [SessionRecord]
    // Hands back the chosen category (nil means create one from `title`) and context.
    let onResolve: (_ categoryID: String?, _ title: String, _ contextTag: ContextTag, _ symbolName: String?) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategoryID: String?
    @State private var typedTitle: String = ""
    @State private var contextTag: ContextTag = .normal
    @State private var iconName: String = "circle"

    // Whether what's typed is about to create a new category — the only case an icon
    // choice means anything, since picking an existing chip already has one.
    private var isNewCategory: Bool {
        selectedCategoryID == nil && !typedTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // The person's most frequent categories, which is what the chip row shows before
    // anything has been typed — the same "most likely first" shortcut a blank search
    // field would otherwise waste.
    private var frequent: [TaskCategory] {
        let counts = Dictionary(grouping: history, by: \.categoryID).mapValues(\.count)
        return categories
            .sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
            .prefix(8)
            .map { $0 }
    }

    // What the chip row shows: the frequent list while the field is empty, or whatever
    // existing categories match what's been typed so far — a live search rather than a
    // fixed set, so reusing a category already in history is a type-then-tap instead of
    // retyping it character for character and hoping the app notices.
    private var suggestions: [TaskCategory] {
        let trimmed = typedTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return frequent }
        return categories
            .filter { $0.name.lowercased().contains(trimmed) }
            .prefix(8)
            .map { $0 }
    }

    private var canResolve: Bool {
        selectedCategoryID != nil || !typedTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: appeared)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        categorySection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -20)
                            .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                        contextSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : -20)
                            .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                    }
                    .padding(.horizontal, Theme.Padding.focused)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                actions
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
            }
        }
        .onAppear { appeared = true }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Caption("What was this")
            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    // MARK: - Category Section

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption("What was this")

            TextField("", text: $typedTitle, prompt: Text("Session title").foregroundStyle(Theme.inkFaint))
                .font(Typeface.body(15))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.row).strokeBorder(Theme.line, lineWidth: 1)
                }
                // Editing away from a picked chip un-picks it — the field is back to
                // being freeform text, exactly like it was before anything matched.
                .onChange(of: typedTitle) { _, newValue in
                    if let selectedCategoryID, categories.first(where: { $0.id == selectedCategoryID })?.name != newValue {
                        self.selectedCategoryID = nil
                    }
                }

            if isNewCategory {
                EmojiIconButton(selection: $iconName)
                    .padding(.horizontal, Theme.Padding.screen)
                    .padding(.top, 14)
            }

            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(suggestions, id: \.self) { category in
                    Chip(title: category.name, isSelected: selectedCategoryID == category.id) {
                        selectedCategoryID = category.id
                        typedTitle = category.name
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.top, 16)
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption("Context")

            FlowLayout(spacing: 7, lineSpacing: 7) {
                ForEach(ContextTag.defaults, id: \.self) { tag in
                    Chip(title: tag.displayName, isSelected: tag == contextTag) {
                        contextTag = tag
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.top, 16)
    }

    // MARK: - Actions

    private var actions: some View {
        PrimaryButton(title: "Done") {
            onResolve(selectedCategoryID, typedTitle.trimmingCharacters(in: .whitespaces), contextTag, isNewCategory ? iconName : nil)
        }
        .disabled(!canResolve)
        .opacity(canResolve ? 1 : 0.4)
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }
}

/// The plainly visible list of sessions still waiting on a label.
///
/// This is not meant to be a queue people let build up: an unresolved session
/// contributes nothing to their own history until it is resolved, so letting these pile
/// up quietly would defeat the point of quick start in the first place.
struct UnresolvedSessionsCard: View {
    let sessions: [Session]
    let onResolve: (Session) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Needs a label")
                    .font(Typeface.title(15))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Caption("\(sessions.count) waiting")
            }

            ForEach(sessions) { session in
                Button {
                    onResolve(session)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 18, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlabelled session")
                                .font(Typeface.medium(14))
                                .foregroundStyle(Theme.ink)
                            Caption(endedLabel(session), size: 12)
                        }

                        Spacer()

                        Text(DurationFormatting.compact(minutes: session.actualMinutes ?? 0))
                            .font(Typeface.title(16))
                            .foregroundStyle(Theme.ink)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .padding(.horizontal, Theme.Padding.row)
                    .padding(.vertical, 14)
                    .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.row)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func endedLabel(_ session: Session) -> String {
        guard let ended = session.endedAt else { return "still open" }
        if Calendar.current.isDateInToday(ended) {
            return "ended \(ended.formatted(.dateTime.hour().minute()))"
        }
        return "ended \(ended.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"
    }
}
