import SwiftUI

/// What a shared link opens into.
///
/// It explains the deal plainly, including the part the sender does not get: the
/// recipient's guess and actual duration stay private, because that data belongs to
/// whoever logged it, not whoever asked for it.
struct ReceiveReminderView: View {
    let reminder: SharedReminder
    /// Whether the sender should be told, later, that this was marked done.
    let onAccept: (_ sharesCompletion: Bool) -> Void
    let onDecline: () -> Void

    /// Off by default. It is a separate, later choice from accepting the reminder
    /// itself, never assumed just because the reminder came from someone.
    @State private var sharesCompletion = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 22) {
                    sender

                    VStack(alignment: .leading, spacing: 6) {
                        Text(reminder.title)
                            .font(Typeface.title(30))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(Typeface.body(14))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    CardSurface(radius: Theme.Radius.panel, padding: 18) {
                        Text(explanation)
                            .font(Typeface.body(13.5))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    completionToggle
                }
                .padding(.horizontal, Theme.Padding.focused)
                .frame(maxHeight: .infinity, alignment: .center)

                actions
            }
        }
    }

    private var header: some View {
        HStack {
            Caption(Date.now.formatted(.dateTime.hour().minute()))
            Spacer()
            Button(action: onDecline) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
    }

    private var sender: some View {
        HStack(spacing: 10) {
            Text(String(reminder.senderName.prefix(1)).uppercased())
                .font(Typeface.semibold(13))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 34, height: 34)
                .background(Theme.card, in: .circle)
                .overlay { Circle().strokeBorder(Theme.line, lineWidth: 1) }

            Text("\(reminder.senderName) sent you a reminder")
                .font(Typeface.body(13.5))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var subtitle: String {
        guard let minutes = reminder.senderEstimatedMinutes else {
            return reminder.windowDescription
        }
        return "\(reminder.windowDescription) · \(reminder.senderName) thinks about \(DurationFormatting.compact(minutes: minutes))"
    }

    private var explanation: String {
        let fit = reminder.senderEstimatedMinutes == nil
            ? "a free stretch"
            : "a free stretch that fits \(reminder.senderName)'s guess"

        return "Add this and Actual will wait until you actually have \(fit), then ask you directly if you want to do it right then, no need to remember it yourself. You'll guess how long it takes and it'll time the rest, same as everything else you log. \(reminder.senderName) won't see your guess or the actual time, only whether you mark it done, if you decide to share that much."
    }

    private var completionToggle: some View {
        Toggle(isOn: $sharesCompletion) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Let \(reminder.senderName) know when it's done")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.ink)
                Text("Just that it happened. Never your guess or how long it actually took.")
                    .font(Typeface.body(11.5))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .tint(Theme.accent)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Add to Actual", height: 54) { onAccept(sharesCompletion) }

            Button(action: onDecline) {
                Text("Not now")
                    .font(Typeface.body(13))
                    .foregroundStyle(Theme.inkFaint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Padding.focused)
        .padding(.bottom, 48)
    }
}

/// The prompt that fires the moment a fitting window actually turns up.
///
/// This is the whole difference between the feature and a to-do list. Rather than
/// sitting passively waiting to be noticed, it steps in when there is genuinely room.
struct ReminderPromptView: View {
    let reminder: ReceivedReminder
    let window: TimeWindow
    let onStart: (_ estimatedMinutes: Int) -> Void
    let onLater: () -> Void

    @State private var chosenMinutes: Int

    init(
        reminder: ReceivedReminder,
        window: TimeWindow,
        onStart: @escaping (Int) -> Void,
        onLater: @escaping () -> Void
    ) {
        self.reminder = reminder
        self.window = window
        self.onStart = onStart
        self.onLater = onLater
        // The sender's guess is a sensible starting number when there is no history
        // here yet, clearly labelled as theirs rather than the recipient's own.
        _chosenMinutes = State(initialValue: reminder.senderEstimatedMinutes ?? 25)
    }

    private var presets: [Int] {
        let base = reminder.senderEstimatedMinutes ?? 25
        return [max(5, base - 10), base, base + 10]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                SectionLabel(text: "FITS YOUR FREE TIME")
                Spacer()
                CountBadge(text: "\(DurationFormatting.compact(minutes: window.minutes)) open right now")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(Typeface.title(22))
                    .foregroundStyle(Theme.ink)
                Caption("from \(reminder.senderName) · \(reminder.windowDescription.lowercased())", size: 13)
            }

            VStack(alignment: .leading, spacing: 8) {
                Caption(guessLabel)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        PresetChip(
                            title: DurationFormatting.compact(minutes: preset),
                            isSelected: chosenMinutes == preset
                        ) {
                            chosenMinutes = preset
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                SecondaryButton(title: "Later", action: onLater)
                PrimaryButton(title: "Start now") { onStart(chosenMinutes) }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(.rect(topLeadingRadius: Theme.Radius.sheet, topTrailingRadius: Theme.Radius.sheet))
        .overlay(alignment: .top) { Hairline() }
    }

    private var guessLabel: String {
        guard let sender = reminder.senderEstimatedMinutes else { return "Your guess" }
        return "Your guess, \(reminder.senderName) thought \(DurationFormatting.compact(minutes: sender))"
    }
}
