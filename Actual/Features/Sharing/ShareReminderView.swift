import SwiftUI
import SwiftData

/// Sending someone a reminder, with your own rough guess at how long it takes.
///
/// The guess is optional but it is the thing that makes this different from dropping an
/// item into someone's list: it lets their app wait for a stretch that actually fits.
struct ShareReminderView: View {
    @AppStorage("displayName") private var displayName = "Marta"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var window: WindowPreset = .thisSaturday
    @State private var estimateMinutes: Int? = 25
    @State private var isPickingEstimate = false

    private let estimatePresets = [10, 15, 25]

    /// The reminder as it currently stands. Its share id is stable for the life of this
    /// screen so the preview and the copied link agree.
    @State private var shareID = SharedReminder.makeShareID()

    private var reminder: SharedReminder {
        let range = window.range()
        return SharedReminder(
            shareID: shareID,
            title: title.trimmingCharacters(in: .whitespaces),
            windowStart: range.start,
            windowEnd: range.end,
            senderName: displayName,
            senderEstimatedMinutes: estimateMinutes
        )
    }

    private var canShare: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    titleField
                    windowSection
                    estimateSection
                    preview
                    linkRow
                    shareButton
                }
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $isPickingEstimate) { estimatePicker }
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
            .accessibilityLabel("Close")
            Spacer()
            Caption("Send a reminder")
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
                prompt: Text("What do you need them to do").foregroundStyle(Theme.inkFaint)
            )
            .font(Typeface.title(22))
            .foregroundStyle(Theme.ink)
            .textInputAutocapitalization(.sentences)

            Hairline()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var windowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("When it needs to happen")

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(WindowPreset.allCases, id: \.self) { preset in
                    Chip(title: preset.label, isSelected: preset == window) { window = preset }
                }
            }

            Caption("Anytime in that window works, no fixed time needed.")
                .padding(.top, 2)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 24)
    }

    private var estimateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("About how long it takes")

            HStack(spacing: 8) {
                ForEach(estimatePresets, id: \.self) { preset in
                    PresetChip(
                        title: DurationFormatting.compact(minutes: preset),
                        isSelected: estimateMinutes == preset
                    ) {
                        estimateMinutes = preset
                    }
                }
                PresetChip(title: "custom", isDashed: true) { isPickingEstimate = true }
            }

            Text("Optional, but it's what lets Actual wait for a stretch that actually fits, instead of just dropping this into their list.")
                .font(Typeface.body(12.5))
                .foregroundStyle(Theme.inkFaint)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 26)
    }

    private var preview: some View {
        CardSurface(radius: Theme.Radius.panel, padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "LINK PREVIEW")

                Text(title.isEmpty ? "Your reminder" : title)
                    .font(Typeface.title(15))
                    .foregroundStyle(Theme.ink)

                Caption(previewLine, size: 13)

                Text("The moment they have a free stretch that fits, Actual will ask them directly if they want to do it then. You won't see their guess or how long it actually took, only whether they mark it done, if they choose to share that much.")
                    .font(Typeface.body(12.5))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var previewLine: String {
        var parts = [reminder.windowDescription]
        if let estimateMinutes {
            parts.append("about \(DurationFormatting.compact(minutes: estimateMinutes))")
        }
        parts.append("from \(displayName)")
        return parts.joined(separator: " · ")
    }

    private var linkRow: some View {
        HStack {
            Text(SharedReminderLink.displayText(for: reminder))
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Button {
                UIPasteboard.general.url = SharedReminderLink.url(for: reminder)
            } label: {
                Text("Copy")
                    .font(Typeface.semibold(12.5))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            .disabled(!canShare)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 24)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let url = SharedReminderLink.url(for: reminder), canShare {
            ShareLink(item: url, subject: Text(reminder.title)) {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.right.fill")
                        .font(.system(size: 14))
                    Text("Share link")
                        .font(Typeface.semibold(14))
                }
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.ink, in: .capsule)
            }
            // ShareLink has no completion callback, so this records the reminder as
            // sent the moment the share sheet is opened rather than waiting for
            // confirmation of where it went. Consistent with the rest of the app:
            // nothing here is gated behind an external system agreeing first.
            .simultaneousGesture(TapGesture().onEnded { recordAsSent() })
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 20)
            .padding(.bottom, 46)
        } else {
            Text("Add a title to share this.")
                .font(Typeface.body(13))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
                .padding(.bottom, 46)
        }
    }

    /// Persists a record of this reminder so a completion ping later has somewhere to
    /// land. Safe to call more than once for the same link: the shareID stays fixed for
    /// the life of this screen, and a duplicate insert would just overwrite the id.
    private func recordAsSent() {
        // Tapping Share Link more than once (different channels, a retry) must not
        // insert a second row against the same unique shareID.
        let id = shareID
        let descriptor = FetchDescriptor<SentReminder>(predicate: #Predicate { $0.shareID == id })
        guard (try? context.fetch(descriptor).first) == nil else { return }

        context.insert(SentReminder(sharing: reminder))
        try? context.save()
    }

    private var estimatePicker: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Picker("Minutes", selection: Binding(
                    get: { estimateMinutes ?? 25 },
                    set: { estimateMinutes = $0 }
                )) {
                    ForEach(Array(stride(from: 5, through: 240, by: 5)), id: \.self) { value in
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
                    Button("Done") { isPickingEstimate = false }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

/// The loose windows a sender actually thinks in. Never a fixed slot: the point is that
/// anytime inside the window works.
enum WindowPreset: CaseIterable, Hashable {
    case today
    case thisSaturday
    case thisWeekend
    case thisWeek

    var label: String {
        switch self {
        case .today: return "Today"
        case .thisSaturday: return "This Saturday"
        case .thisWeekend: return "This weekend"
        case .thisWeek: return "This week"
        }
    }

    func range(from now: Date = .now, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: now)

        func endOfDay(_ date: Date) -> Date {
            calendar.date(byAdding: DateComponents(day: 1, second: -1), to: calendar.startOfDay(for: date)) ?? date
        }

        switch self {
        case .today:
            return (startOfToday, endOfDay(now))
        case .thisSaturday:
            let saturday = Self.next(weekday: 7, from: now, calendar: calendar)
            return (calendar.startOfDay(for: saturday), endOfDay(saturday))
        case .thisWeekend:
            let saturday = Self.next(weekday: 7, from: now, calendar: calendar)
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) ?? saturday
            return (calendar.startOfDay(for: saturday), endOfDay(sunday))
        case .thisWeek:
            let end = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
            return (startOfToday, endOfDay(end))
        }
    }

    /// The next occurrence of a weekday, counting today when it matches.
    private static func next(weekday: Int, from date: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: date)
        let offset = (weekday - current + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: date) ?? date
    }
}
