import SwiftUI

// What fits the free stretch you have right now.
//
// It does not rank downtime against productive time, and it never says a choice was
// wrong. It shows what has fit this window before and what is still pending, and logs
// whatever actually happens the same neutral way as everything else.
struct GapFillerView: View {
    let window: TimeWindow
    // What the window runs up against, which is what gives it meaning.
    let nextCommitment: String?
    let suggestions: [Suggestion]
    // The plain, unjudged fact about where time like this has gone lately.
    let honestNote: String?
    let onChoose: (Suggestion) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

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
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 22)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -20)
                .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                if suggestions.isEmpty {
                    CardSurface(radius: Theme.Radius.panel, padding: 16) {
                        Text("Nothing in your history fits a window this size yet.")
                            .font(Typeface.body(13))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.top, 22)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appeared)
                }

                Spacer(minLength: 12)

                if let honestNote {
                    CardSurface(radius: Theme.Radius.row, padding: 15) {
                        Text(honestNote)
                            .font(Typeface.body(12))
                            .foregroundStyle(Theme.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.bottom, 44)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -20)
                    .scaleEffect(appeared ? 1 : 0.95, anchor: .top)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)
                }
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
                    .foregroundStyle(Theme.primaryText)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Caption(nextCommitment ?? "")
                .foregroundStyle(Theme.primaryText)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screen)
        .padding(.top, 22)
    }

    // MARK: - Headline

    private var headline: some View {
        Text("What fits this window")
            .font(Typeface.title(22))
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.top, 22)
            .padding(.bottom, 6)
    }

    // MARK: - Subheading

    private var subheading: some View {
        Text("Suggested activities based on your history")
            .font(Typeface.body(13))
            .foregroundStyle(Theme.secondaryText)
            .padding(.horizontal, Theme.Spacing.screen)
            .padding(.bottom, 10)
    }

    // MARK: - Suggestion Row

    private struct SuggestionRow: View {
        let suggestion: Suggestion
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Image(systemName: suggestion.symbolName)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(Typeface.medium(14))
                            .foregroundStyle(Theme.primaryText)
                        Caption(suggestion.subtitle, size: 12)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, Theme.Spacing.row)
                .padding(.vertical, 14)
                .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                        .strokeBorder(Theme.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
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
                        .foregroundStyle(Theme.primaryText)

                    Text(subtitle)
                        .font(Typeface.body(13))
                        .foregroundStyle(Theme.secondaryText)
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