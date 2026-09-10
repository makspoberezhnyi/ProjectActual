import SwiftUI
import SwiftData

/// Profile. What the app holds, where it lives, and how to get rid of it.
///
/// No score, no streak, no rank — the product does not grade how anyone spends their
/// time, and this screen is the most tempting place to start. It states what has been
/// recorded and nothing about whether that is good.
///
/// It also names what is not wired up yet rather than showing dead switches, since a
/// toggle that silently does nothing would be worse than an honest line of text.
struct ProfileView: View {
    let sessions: [Session]
    let categories: [TaskCategory]
    let sentReminders: [SentReminder]

    @Environment(\.modelContext) private var context
    @AppStorage("hasClearedData") private var hasClearedData = false
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.dark.rawValue
    @AppStorage("displayName") private var displayName = "Marta"
    @AppStorage("profilePhotoData") private var profilePhotoData: Data?
    @State private var isEditingProfile = false
    @State private var isConfirmingDelete = false
    @State private var exportFileURL: URL?
    @State private var isSharingExport = false
    @State private var isImporting = false
    @State private var importSummary: DataTransfer.ImportSummary?
    @State private var importError: String?
    @State private var reminderPendingDeletion: SentReminder?
    @State private var deleteError: String?

    private var closed: [Session] { sessions.filter(\.isClosed) }

    private var firstLogged: Date? {
        closed.compactMap(\.endedAt).min()
    }

    /// Categories the person actually has closed sessions under, with counts, most
    /// logged first.
    private var categoryCounts: [(category: TaskCategory, count: Int)] {
        let counts = Dictionary(grouping: closed.compactMap(\.categoryID)) { $0 }
            .mapValues(\.count)
        return categories
            .compactMap { category in
                guard let count = counts[category.id] else { return nil }
                return (category: category, count: count)
            }
            .sorted { $0.count > $1.count }
    }

    /// Context tags in use, defaults and custom alike, ranked by how often they appear.
    private var tagCounts: [(tag: ContextTag, count: Int)] {
        Dictionary(grouping: closed.map(\.contextTag)) { $0 }
            .map { (tag: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                heroCard
                categoriesSection
                tagsSection
                if !sentReminders.isEmpty {
                    sentRemindersSection
                }
                appearanceSection
                dataTransfer
                privacy
                dangerZone
            }
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        // An alert rather than a confirmation dialog: the dialog rendered the
        // destructive button without a visible way to back out, which is the wrong
        // shape for the one irreversible action in the app.
        .alert(
            "Delete everything Actual has recorded?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteEverything)
        } message: {
            Text("Every session, category and context tag. This cannot be undone, and nothing will be seeded back.")
        }
        .alert(
            "Couldn't delete",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Hero

    /// The profile's own hero: name, join date and stats stacked on the left, photo on
    /// the right — the same shape a social profile header uses, name-first rather than
    /// photo-first, with the numbers read as a tight row rather than spread edge to
    /// edge. One card, one tap target to edit it.
    private var heroCard: some View {
        Button { isEditingProfile = true } label: {
            CardSurface(radius: 20, padding: 16) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(displayName)
                            .font(Typeface.display(21))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let firstLogged {
                            // Abbreviated month, not `.wide`: "Joined September 2026"
                            // was long enough to wrap onto a second line the moment the
                            // avatar took its share of the card's width, which pushed
                            // the stats row down and read as broken rather than just
                            // snug. "Sep 2026" fits on one line at any card width this
                            // layout actually produces.
                            Caption(
                                "Joined \(firstLogged.formatted(.dateTime.month(.abbreviated).year()))",
                                size: 12.5
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        }

                        HStack(spacing: 12) {
                            figure("\(closed.count)", "sessions")
                            figure("\(categoryCounts.count)", categoryCounts.count == 1 ? "category" : "categories")
                            figure(totalTracked, "logged")
                        }
                        .padding(.top, 1)
                    }

                    Spacer(minLength: 8)

                    heroAvatar
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit profile")
        .sheet(isPresented: $isEditingProfile) { EditProfileView() }
    }

    @ViewBuilder
    private var heroAvatar: some View {
        Group {
            if let profilePhotoData, let uiImage = UIImage(data: profilePhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
            } else {
                Text(ProfilePhoto.initial(for: displayName))
                    .font(Typeface.title(30))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 88, height: 88)
                    .background(Theme.card)
            }
        }
        .clipShape(.circle)
        .overlay { Circle().strokeBorder(Theme.line, lineWidth: 1) }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Typeface.display(17))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Caption(label, size: 10.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .fixedSize()
    }

    private var totalTracked: String {
        DurationFormatting.coarse(minutes: closed.reduce(0) { $0 + ($1.actualMinutes ?? 0) })
    }

    // MARK: - Categories and tags

    private var categoriesSection: some View {
        section("Your categories") {
            if categoryCounts.isEmpty {
                Caption("Nothing logged yet.", size: 13)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(categoryCounts.enumerated()), id: \.element.category.id) { index, entry in
                        if index > 0 { Hairline() }
                        HStack(spacing: 12) {
                            CategoryIconView(symbolName: entry.category.symbolName)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.inkSoft)
                                .frame(width: 18)

                            Text(entry.category.name)
                                .font(Typeface.body(14))
                                .foregroundStyle(Theme.ink)

                            Spacer()

                            Caption("\(entry.count)", size: 12.5)
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        section("Context tags in use") {
            if tagCounts.isEmpty {
                Caption("Nothing logged yet.", size: 13)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(tagCounts, id: \.tag) { entry in
                            HStack(spacing: 6) {
                                Text(entry.tag.displayName)
                                    .font(Typeface.body(13))
                                    .foregroundStyle(Theme.inkSoft)
                                Text("\(entry.count)")
                                    .font(Typeface.body(11.5))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
                        }
                    }

                    Text("Normal is one context among several, not the baseline the others deviate from.")
                        .font(Typeface.body(12))
                        .foregroundStyle(Theme.inkFaint)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Reminders sent to others

    private var sentRemindersSection: some View {
        section("Reminders you've sent") {
            VStack(spacing: 0) {
                ForEach(Array(sentReminders.sorted { $0.createdAt > $1.createdAt }.enumerated()), id: \.element.shareID) { index, sent in
                    if index > 0 { Hairline() }
                    HStack(spacing: 10) {
                        Image(systemName: sent.recipientCompletedAt != nil ? "checkmark.circle.fill" : "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(sent.recipientCompletedAt != nil ? Theme.accent : Theme.inkFaint)

                        Text(sent.title)
                            .font(Typeface.body(14))
                            .foregroundStyle(Theme.ink)

                        Spacer()

                        Caption(sentStatus(sent), size: 12)

                        Button {
                            reminderPendingDeletion = sent
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.inkFaint)
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete record of \"\(sent.title)\"")
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        // Only a record of having sent it, not the reminder itself sitting on the
        // recipient's device — deleting here means a future completion ping for it
        // finds no match and quietly does nothing, the same graceful-absence behaviour
        // the app already relies on everywhere else.
        .alert(
            "Delete this record?",
            isPresented: Binding(
                get: { reminderPendingDeletion != nil },
                set: { if !$0 { reminderPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { reminderPendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let sent = reminderPendingDeletion {
                    context.delete(sent)
                    try? context.save()
                }
                reminderPendingDeletion = nil
            }
        } message: {
            Text("This only removes your own record of having sent it. It cannot be undone.")
        }
    }

    private func sentStatus(_ sent: SentReminder) -> String {
        if sent.recipientCompletedAt != nil { return "done" }
        if sent.hasExpired { return "didn't happen" }
        return "pending"
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        section("Appearance") {
            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearanceModeRaw = mode.rawValue
                    } label: {
                        Text(mode.label)
                            .font(mode.rawValue == appearanceModeRaw ? Typeface.medium(13) : Typeface.body(13))
                            .foregroundStyle(mode.rawValue == appearanceModeRaw ? Theme.bg : Theme.inkFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if mode.rawValue == appearanceModeRaw {
                                    Capsule().fill(Theme.ink)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(mode.rawValue == appearanceModeRaw ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacy: some View {
        section("Privacy") {
            Text("Everything above lives on this device. Nothing is ranked, judged, or shared with anyone.")
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Export and import

    /// Every table, in one file the person actually holds — the same "your data
    /// belongs to you" premise the rest of the app is built on, extended to getting it
    /// back out.
    private var dataTransfer: some View {
        section("Your data") {
            VStack(spacing: 0) {
                Button(action: prepareExport) {
                    row(
                        icon: "square.and.arrow.up",
                        title: "Export everything",
                        subtitle: "Every session, category and reminder, as one file"
                    )
                }
                .buttonStyle(.plain)

                Hairline()

                Button { isImporting = true } label: {
                    row(
                        icon: "square.and.arrow.down",
                        title: "Import from a file",
                        subtitle: "Adds to what's already here, never overwrites"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isSharingExport) {
            if let exportFileURL {
                ActivityShareSheet(items: [exportFileURL])
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            onCompletion: handleImport
        )
        .alert(
            "Imported",
            isPresented: Binding(
                get: { importSummary != nil },
                set: { if !$0 { importSummary = nil } }
            )
        ) {
            Button("OK") { importSummary = nil }
        } message: {
            Text(importSummaryText)
        }
        .alert(
            "Couldn't import that file",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )
        ) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Typeface.body(13.5))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Typeface.body(11))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var importSummaryText: String {
        guard let importSummary else { return "" }
        guard importSummary.totalChanged > 0 else {
            return "Nothing new in that file — everything in it was already here."
        }
        var parts: [String] = []
        let categories = importSummary.categoriesAdded + importSummary.categoriesUpdated
        if categories > 0 { parts.append("\(categories) \(categories == 1 ? "category" : "categories")") }
        let sessions = importSummary.sessionsAdded + importSummary.sessionsUpdated
        if sessions > 0 { parts.append("\(sessions) \(sessions == 1 ? "session" : "sessions")") }
        if importSummary.remindersAdded > 0 {
            parts.append("\(importSummary.remindersAdded) \(importSummary.remindersAdded == 1 ? "reminder" : "reminders")")
        }
        return parts.joined(separator: ", ") + " added or updated."
    }

    private func prepareExport() {
        let export = DataTransfer.export(from: context)
        exportFileURL = try? DataTransfer.writeToTemporaryFile(export)
        isSharingExport = exportFileURL != nil
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription

        case .success(let url):
            // A file picked from Files or iCloud Drive is security-scoped: reading it
            // needs an explicit start/stop around the access, or it silently fails.
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                let export = try DataTransfer.decode(data)
                importSummary = DataTransfer.merge(export, into: context)
            } catch {
                importError = "That file isn't a recognizable Actual export."
            }
        }
    }

    // MARK: - Deleting

    private var dangerZone: some View {
        SecondaryButton(title: "Delete all history") {
            isConfirmingDelete = true
        }
    }

    private func deleteEverything() {
        for session in sessions { context.delete(session) }
        for category in categories { context.delete(category) }

        // Flipped only once the delete genuinely lands. Setting it unconditionally
        // would mean a failed save — the one place in the app where that would
        // actually matter — leaves the data behind with nothing on screen saying so,
        // and nothing left to ever restore it, since the seed only reinstates once.
        do {
            try context.save()
        } catch {
            deleteError = "Something went wrong deleting your history. Nothing was removed — try again."
            return
        }

        hasClearedData = true
    }

    // MARK: - Shared section chrome

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Typeface.title(15))
                .foregroundStyle(Theme.ink)

            CardSurface(radius: Theme.Radius.panel, padding: 16) {
                content()
            }
        }
    }
}

/// A thin bridge to the system share sheet. SwiftUI's own `ShareLink` needs its item
/// ready at render time; export needs to write the file first, so this is driven from
/// a Button instead, the same way the rest of the app treats every other action.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
