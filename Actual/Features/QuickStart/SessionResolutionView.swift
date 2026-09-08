import SwiftUI

/// The "what was this" step, shown the instant a quick-started session ends.
///
/// The friction lands at the one point where it costs almost nothing: right after the
/// person already knows what they just did, instead of making them stop and think before
/// they have even started.
///
/// Asking for the context here, seconds after the fact, stays close enough to the moment
/// that it does not reopen the risk context tags exist to avoid — picking a tag long
/// afterward specifically to explain away a result.
struct SessionResolutionView: View {
    let session: Session
    let categories: [TaskCategory]
    let history: [SessionRecord]
    /// Hands back the chosen category (nil means create one from `title`) and context.
    let onResolve: (_ categoryID: String?, _ title: String, _ contextTag: ContextTag) -> Void
    let onDismiss: () -> Void

    @State private var selectedCategoryID: String?
    @State private var typedTitle: String = ""
    @State private var contextTag: ContextTag = .normal
    @State private var isNaming = false

    /// The person's most frequent categories, which is what a one-tap chip list is for.
    private var frequent: [TaskCategory] {
        let counts = Dictionary(grouping: history, by: \.categoryID).mapValues(\.count)
        return categories
            .sorted { (counts[$0.id] ?? 0) > (counts[$1.id] ?? 0) }
            .prefix(8)
            .map { $0 }
    }

    private var canResolve: Bool {
        selectedCategoryID != nil || !typedTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        categorySection
                        contextSection
                    }
                    .padding(.horizontal, Theme.Padding.focused)
                    .padding(.top, 26)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                actions
            }
        }
        .alert("What was it?", isPresented: $isNaming) {
            TextField("Name it", text: $typedTitle)
            Button("Cancel", role: .cancel) { typedTitle = "" }
            Button("Use this") { selectedCategoryID = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Caption("Ran for \(DurationFormatting.compact(minutes: session.actualMinutes ?? 0))")
            Text("What was this?")
                .font(Typeface.title(24))
                .foregroundStyle(Theme.ink)
            Text("The time is already recorded. This just says what it counts toward.")
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.top, 26)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Category")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(frequent) { category in
                    Chip(title: category.name, isSelected: selectedCategoryID == category.id) {
                        selectedCategoryID = category.id
                        typedTitle = ""
                    }
                }
                Chip(
                    title: typedTitle.isEmpty ? "+ something else" : typedTitle,
                    isSelected: selectedCategoryID == nil && !typedTitle.isEmpty,
                    isDashed: typedTitle.isEmpty
                ) {
                    isNaming = true
                }
            }
        }
    }

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("Context")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(ContextTag.defaults, id: \.self) { tag in
                    Chip(title: tag.displayName, isSelected: tag == contextTag) {
                        contextTag = tag
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Save") {
                let trimmed = typedTitle.trimmingCharacters(in: .whitespaces)
                let title = selectedCategoryID
                    .flatMap { id in categories.first { $0.id == id }?.name }
                    ?? trimmed
                onResolve(selectedCategoryID, title, contextTag)
            }
            .opacity(canResolve ? 1 : 0.4)
            .disabled(!canResolve)

            // Dismissing is allowed, but the session then sits plainly visible as
            // unresolved rather than vanishing into a backlog.
            Button(action: onDismiss) {
                Text("Not now")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.bottom, 46)
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
