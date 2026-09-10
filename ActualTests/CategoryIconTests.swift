import Testing
@testable import Actual

/// `isEmojiIcon` is what decides whether a category's `symbolName` renders as an SF
/// Symbol or as typed emoji text — the one thing that has to be right for
/// `CategoryIconView` to draw the correct thing at all.
struct CategoryIconTests {

    @Test("Every SF Symbol name this app actually uses reads as not-an-emoji")
    func sfSymbolNamesAreNotEmoji() {
        for symbol in CategoryIcon.choices {
            #expect(!symbol.isEmojiIcon, "\(symbol) should not be read as an emoji")
        }
    }

    @Test("A genuine emoji, single scalar or a multi-scalar sequence, reads as an emoji")
    func emojiReadsAsEmoji() {
        #expect("🧘".isEmojiIcon)
        #expect("🎸".isEmojiIcon)
        #expect("❤️".isEmojiIcon) // heart + variation selector: two scalars
        #expect("👨‍👩‍👧".isEmojiIcon) // family: a ZWJ sequence, several scalars
    }

    @Test("Plain digits and punctuation that can appear in a keycap sequence read as text, not emoji, on their own")
    func keycapComponentsAreNotEmojiAlone() {
        #expect(!"3".isEmojiIcon)
        #expect(!"#".isEmojiIcon)
        #expect(!"*".isEmojiIcon)
    }

    @Test("Empty string reads as not-an-emoji rather than crashing")
    func emptyStringIsNotEmoji() {
        #expect(!"".isEmojiIcon)
    }
}
