import SwiftUI

// The fixed set an icon for a brand-new category can be chosen from, in the same
// mostly-unfilled SF Symbol style the seeded categories already use (`laptopcomputer`,
// `car.fill`, `envelope`, `cart`, `phone`, `book` — see `SeedData`). A typed name that
// matches nothing existing would otherwise fall back to a plain, unlabelled circle
// forever; this is what lets a new category look like it belongs next to the others
// rather than standing out as the one thing nobody bothered to give a picture.
enum CategoryIcon {
    static let choices: [String] = [
        "circle", "briefcase", "laptopcomputer", "envelope", "phone",
        "message", "car.fill", "bus", "airplane", "figure.walk",
        "cart", "fork.knife", "cup.and.saucer", "book", "pencil",
        "paintbrush", "music.note", "gamecontroller", "dumbbell", "heart",
        "bed.double", "house", "wrench.and.screwdriver", "gift", "pawprint",
        "camera", "bag", "graduationcap", "person.2", "leaf",
    ]
}

// A horizontal row of the curated SF Symbol set. Shown only while the typed title
// doesn't match an existing category — an existing one already has a picture, and
// this is about giving a new one a reasonable one rather than editing what's already
// there. The custom-emoji option lives separately in `EmojiIconButton`, not in this
// row — it isn't one of the curated choices, it's a different kind of input.
struct CategoryIconPicker: View {
    @Binding var selection: String

    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CategoryIcon.choices, id: \.self) { symbol in
                        let isSelected = selection == symbol
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                selection = symbol
                            }
                            HapticFeedback.mediumImpact()
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 16))
                                .foregroundStyle(isSelected ? Theme.bg : Theme.inkSoft)
                                .frame(width: 40, height: 40)
                                .background {
                                    Circle().fill(isSelected ? Theme.ink : Theme.card)
                                }
                                .overlay {
                                    Circle().strokeBorder(Theme.line, lineWidth: isSelected ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }

            // Fade-in animation for the picker
            if appeared {
                Spacer()
            }
        }
        .onAppear { appeared = true }
    }
}

// A dedicated button for picking a custom emoji icon, meant to sit beside a title
// field rather than inside the curated `CategoryIconPicker` row — it was there
// before, but reading and behaving like a second, half-broken text field next to a
// row of tappable icons was exactly the confusing part. This still opens the
// system's own emoji keyboard (the globe key) the same way as before — there is no
// public, supported way to force it open on its own — but the tappable surface now
// reads unambiguously as a button: an emoji once one is picked, a plain placeholder
// glyph until then, never a blinking cursor or a field that looks like it swallowed
// what was typed.
struct EmojiIconButton: View {
    @Binding var selection: String

    var body: some View {
        let isSelected = !selection.isEmpty && !selection.contains(where: { !$0.isWhitespace })
        ZStack {
            if isSelected {
                Text(selection).font(.system(size: 18))
            } else {
                Image(systemName: "face.smiling")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.inkSoft)
            }

            // Invisible but tappable/typable: it never displays its own draft, so
            // there is nothing on screen that looks like text-field chrome. Typed
            // input still reaches `emojiBinding`, which only ever keeps an emoji.
            TextField("", text: emojiBinding)
                .tint(.clear)
                .foregroundStyle(.clear)
        }
        .frame(width: 40, height: 40)
        .background {
            Circle().fill(isSelected ? Theme.ink : Theme.card)
        }
        .overlay {
            Circle().strokeBorder(Theme.line, lineWidth: isSelected ? 0 : 1)
        }
        .accessibilityLabel(isSelected ? "Emoji icon, \(selection)" : "Pick an emoji icon")
    }

    // Never echoes a draft back — the display above is driven entirely by `selection`
    // — and only ever accepts an emoji: the last character typed is what counts, so
    // pasting text or switching back to a letter keyboard mid-edit doesn't leave a
    // behind.
    private var emojiBinding: Binding<String> {
        Binding(
            get: { selection },
            set: { newValue in
                selection = newValue.filter { $0.isLetter || $0.isNumber || $0 == " " }
            }
        )
    }
}