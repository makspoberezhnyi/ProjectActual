import SwiftUI

extension String {
    /// True for anything actually typed or picked as an emoji, as opposed to one of
    /// this app's own SF Symbol names — every SF Symbol name here is plain lowercase
    /// ASCII with dots, never an emoji scalar, so checking the first character is
    /// enough to tell the two apart. Excludes the handful of plain characters (digits,
    /// "#", "*") Unicode still marks `isEmoji` purely because they can appear inside a
    /// keycap sequence, but which read as ordinary text on their own.
    var isEmojiIcon: Bool {
        guard let first = unicodeScalars.first, first.properties.isEmoji else { return false }
        return first.properties.isEmojiPresentation || unicodeScalars.count > 1
    }
}

/// Renders a category's `symbolName` as whichever it actually is — one of this app's
/// own SF Symbols, or an emoji typed from the keyboard instead. Shared with the widget
/// target, since a quick-start button there shows the same icon the app does.
///
/// There is no way to make an emoji match the SF Symbols' monochrome line style: an SF
/// Symbol is a vector path this app can recolour and weight to fit `Theme`, but an
/// emoji is fixed, pre-rendered colour artwork (Apple's Color Emoji font) with no path
/// to restyle. It renders exactly as picked rather than pretending otherwise.
struct CategoryIconView: View {
    let symbolName: String

    var body: some View {
        if symbolName.isEmojiIcon {
            Text(symbolName)
        } else {
            Image(systemName: symbolName)
        }
    }
}
