import SwiftUI

/// The fixed set an icon for a brand-new category can be chosen from, in the same
/// mostly-unfilled SF Symbol style the seeded categories already use (`laptopcomputer`,
/// `car.fill`, `envelope`, `cart`, `phone`, `book` — see `SeedData`). A typed name that
/// matches nothing existing would otherwise fall back to a plain, unlabelled circle
/// forever; this is what lets a new category look like it belongs next to the others
/// rather than standing out as the one thing nobody bothered to give a picture.
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

/// A horizontal row of selectable icons. Shown only while the typed title doesn't match
/// an existing category — an existing one already has a picture, and this is about
/// giving a new one a reasonable one rather than editing what's already there.
struct CategoryIconPicker: View {
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CategoryIcon.choices, id: \.self) { symbol in
                    let isSelected = selection == symbol
                    Button {
                        selection = symbol
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
    }
}
