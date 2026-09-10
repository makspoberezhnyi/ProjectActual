import SwiftUI

// MARK: - Surfaces

/// The raised card the design uses everywhere: card fill, hairline border, generous radius.
struct CardSurface<Content: View>: View {
    var radius: CGFloat = Theme.Radius.card
    var padding: CGFloat = Theme.Padding.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Theme.line, lineWidth: 1)
            }
    }
}

// MARK: - Buttons

/// The filled pill: ink background, background-coloured label. The one primary action
/// on a screen.
struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.semibold(14.5))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Theme.ink, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

/// The filled-but-quiet pill, for the secondary choice sitting beside a primary one.
/// A hairline-only outline against `Theme.bg` read as barely there — no fill meant
/// almost no contrast, so this stood out as text with a border rather than a tappable
/// surface. A `Theme.card` fill gives it the same raised quality every other surface
/// in the design already has, while staying visibly quieter than `PrimaryButton`'s
/// solid ink fill.
struct SecondaryButton: View {
    let title: String
    var height: CGFloat = 52
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.medium(14))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Theme.card, in: .capsule)
                .overlay { Capsule().strokeBorder(Theme.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chips

/// A selectable chip. Selected chips invert to ink-on-background; unselected ones are
/// a soft outline. Used for context tags and duration presets.
struct Chip: View {
    let title: String
    var isSelected: Bool = false
    var isDashed: Bool = false
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 8
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? Typeface.medium(13) : Typeface.body(13))
                .foregroundStyle(isSelected ? Theme.bg : (isDashed ? Theme.inkFaint : Theme.inkSoft))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background {
                    if isSelected {
                        Capsule().fill(Theme.ink)
                    } else if isDashed {
                        Capsule().strokeBorder(
                            Theme.inkFaint,
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                    } else {
                        Capsule().strokeBorder(Theme.line, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// The duration preset chip. Selected reads as a dim wash with accent text rather than
/// a full inversion, so it sits quieter than a context tag.
struct PresetChip: View {
    let title: String
    var isSelected: Bool = false
    var isDashed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typeface.body(13))
                .foregroundStyle(isSelected ? Theme.accent : (isDashed ? Theme.inkFaint : Theme.inkSoft))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    let shape = RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    if isSelected {
                        shape.fill(Theme.accentDim)
                    } else if isDashed {
                        shape.strokeBorder(Theme.inkFaint, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    } else {
                        shape.strokeBorder(Theme.line, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badges

/// The small count that sits beside a number: "32 sessions", "51 logs".
struct CountBadge: View {
    let text: String
    var emphasised: Bool = false

    var body: some View {
        Text(text)
            .font(Typeface.body(11))
            .foregroundStyle(emphasised ? Theme.ink : Theme.inkFaint)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(emphasised ? Theme.accentDim : Theme.badge, in: .capsule)
    }
}

/// The context tag shown on an active session card.
struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typeface.body(11))
            .foregroundStyle(Theme.inkSoft)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.pill, in: .capsule)
    }
}

// MARK: - Progress

/// The thin progress bar under a running timer. Fills toward the expected duration and
/// stops at full rather than overflowing, since running past the estimate is normal and
/// not an error state.
struct ProgressBar: View {
    /// 0...1, already clamped by the caller or here.
    let fraction: Double
    var height: CGFloat = 5
    var dimmed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.accent)
                    .opacity(dimmed ? 0.5 : 1)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Small text styles

/// The all-caps section label: "BASED ON YOUR HISTORY".
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typeface.semibold(12.5))
            .tracking(0.25)
            .foregroundStyle(Theme.inkSoft)
    }
}

/// A faint caption in the design's tertiary ink.
struct Caption: View {
    let text: String
    var size: CGFloat = 12.5

    init(_ text: String, size: CGFloat = 12.5) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(Typeface.body(size))
            .foregroundStyle(Theme.inkFaint)
    }
}

/// The hairline divider used between stacked blocks.
struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1)
    }
}
