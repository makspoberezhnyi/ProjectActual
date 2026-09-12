import SwiftUI

/// What fits the free stretch you have right now.
///
/// It does not rank downtime against productive time, and it never says a choice was
/// wrong. It shows what has fit this window before and what is still pending, and logs
/// whatever actually happens the same neutral way as everything else.
struct GapFillerView: View {
    let window: TimeWindow
    /// What the window runs up against, which is what gives it meaning.
    let nextCommitment: String?
    let suggestions: [Suggestion]
    /// The plain, unjudged fact about where time like this has gone lately.
    let honestNote: String?
    let onChoose: (Suggestion) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                headline
                subheading

                VStack(spacing: 12) {
                    ForEach(suggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion) { onChoose(suggestion) }
                    }
                }
                .padding(.horizontal, Theme.Padding.screen)
                .padding(.top, 22)

                if suggestions.isEmpty {
                    CardSurface(radius: Theme.Radius.panel, padding: 16) {
                        Text("Nothing in your history fits a window this size yet.")
                            .font(Typeface.body(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.horizontal, Theme.Padding.screen)
                    .padding(.top, 22)
                }

                Spacer(minLength: 12)

                if let honestNote {
                    CardSurface(radius: Theme.Radius.row, padding: 15) {
                        Text(honestNote)
                            .font(Typeface.body(12))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Theme.Padding.screen)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Caption(Date.now.formatted(.dateTime.hour().minute()))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private var headline: some View {
        Text(headlineText)
            .font(Typeface.title(21))
            .foregroundStyle(Theme.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 18)
    }

    private var headlineText: String {
        let duration = DurationFormatting.compact(minutes: window.minutes)
        guard let nextCommitment, !nextCommitment.isEmpty else {
            return "You have \(duration) free."
        }
        return "You have \(duration) free before \(nextCommitment)."
    }

    private var subheading: some View {
        Text("Here's what's fit this window before, no ranking, just what's true and what's pending.")
            .font(Typeface.body(13))
            .foregroundStyle(Theme.inkSoft)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Padding.screen)
            .padding(.top, 10)
    }
}

/// One thing that would fit.
struct SuggestionRow: View {
    let suggestion: Suggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                CategoryIconView(symbolName: suggestion.symbolName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accentDim, in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(Typeface.medium(14))
                        .foregroundStyle(Theme.ink)
                    Caption(suggestion.subtitle, size: 12)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.panel))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.panel)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

/// The card on home that says a free stretch is open right now.
struct FreeWindowCard: View {
    let window: TimeWindow
    let nextCommitment: String?
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            CardSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Caption("Free until", size: 12)
                        Spacer()
                        TagPill(text: "open window")
                    }

                    Text(window.end.formatted(.dateTime.hour().minute()))
                        .font(Typeface.title(16))
                        .foregroundStyle(Theme.ink)

                    Text(subtitle)
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let duration = DurationFormatting.compact(minutes: window.minutes)
        guard let nextCommitment, !nextCommitment.isEmpty else {
            return "\(duration) open. See what fits."
        }
        return "\(duration) before \(nextCommitment). See what fits."
    }
}
