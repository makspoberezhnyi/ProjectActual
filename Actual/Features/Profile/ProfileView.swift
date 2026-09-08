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
    @AppStorage("passiveTrackingAppIDs") private var passiveTrackingAppIDs = ""
    @State private var isConfirmingDelete = false
    @State private var isViewingPassiveTracking = false
    @State private var exportFileURL: URL?
    @State private var isSharingExport = false
    @State private var isImporting = false
    @State private var importSummary: DataTransfer.ImportSummary?
    @State private var importError: String?

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
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    record
                    categoriesSection
                    tagsSection
                    if !sentReminders.isEmpty {
                        sentRemindersSection
                    }
                    screenTime
                    dataTransfer
                    privacy
                    notConnected
                    dangerZone
                }
                .padding(.horizontal, Theme.Padding.screen)
                .padding(.top, 20)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Text("M")
                .font(Typeface.semibold(15))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(Theme.card, in: .circle)
                .overlay { Circle().strokeBorder(Theme.line, lineWidth: 1) }

            VStack(alignment: .leading, spacing: 1) {
                Text("Marta")
                    .font(Typeface.title(20))
                    .foregroundStyle(Theme.ink)
                Caption("Know your time.", size: 12)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
        .padding(.bottom, 6)
        .background(Theme.bg)
    }

    // MARK: - What has been recorded

    private var record: some View {
        CardSurface(radius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Caption("What Actual has recorded")

                HStack(spacing: 0) {
                    figure("\(closed.count)", "sessions")
                    figure("\(categoryCounts.count)", categoryCounts.count == 1 ? "category" : "categories")
                    figure(totalTracked, "logged")
                }

                if let firstLogged {
                    Caption(
                        "Since \(firstLogged.formatted(.dateTime.month(.wide).day().year()))",
                        size: 12
                    )
                }
            }
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Typeface.display(24))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Caption(label, size: 11.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                            Image(systemName: entry.category.symbolName)
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
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func sentStatus(_ sent: SentReminder) -> String {
        if sent.recipientCompletedAt != nil { return "done" }
        if sent.hasExpired { return "didn't happen" }
        return "pending"
    }

    // MARK: - Screen time

    private var screenTimeAppCount: Int {
        passiveTrackingAppIDs.split(separator: ",").count
    }

    private var screenTime: some View {
        Button { isViewingPassiveTracking = true } label: {
            section("Screen time") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(screenTimeAppCount == 0 ? "Not tracking any apps" : "Tracking \(screenTimeAppCount) \(screenTimeAppCount == 1 ? "app" : "apps")")
                            .font(Typeface.body(13.5))
                            .foregroundStyle(Theme.ink)
                        Text("Opt in per app, on-device only")
                            .font(Typeface.body(11.5))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isViewingPassiveTracking) { PassiveTrackingView() }
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

    /// Named plainly rather than shown as switches that would do nothing.
    private var notConnected: some View {
        section("Not connected yet") {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(
                    [
                        "iCloud sync, so your history reaches your other devices",
                        "Apple Watch and the Mac menu bar",
                        "Voice's microphone and Siri"
                    ],
                    id: \.self
                ) { line in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(Theme.inkFaint)
                            .frame(width: 3, height: 3)
                            .padding(.top, 7)
                        Text(line)
                            .font(Typeface.body(13))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
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
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typeface.body(14))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Typeface.body(11.5))
                    .foregroundStyle(Theme.inkFaint)
            }

            Spacer()
        }
        .padding(.vertical, 12)
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
        Button {
            isConfirmingDelete = true
        } label: {
            Text("Delete all history")
                .font(Typeface.body(14))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func deleteEverything() {
        for session in sessions { context.delete(session) }
        for category in categories { context.delete(category) }
        try? context.save()

        // Remembered, so the seed does not quietly reinstate what was just deleted the
        // next time the app opens.
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
