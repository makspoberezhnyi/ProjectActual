import SwiftUI

/// The exact tokens from the design reference. Views pull from here rather than
/// inventing colours, so the phone, watch and Mac stay one design rather than three.
public enum Theme {
    /// #141414 — the app background.
    public static let bg = Color(hex: 0x141414)
    /// #1e1e1e — raised cards.
    public static let card = Color(hex: 0x1E1E1E)
    /// #f2f0ec — primary text, and the fill on primary buttons.
    public static let ink = Color(hex: 0xF2F0EC)
    /// #a8a49c — secondary text.
    public static let inkSoft = Color(hex: 0xA8A49C)
    /// #68645c — tertiary text, labels, captions.
    public static let inkFaint = Color(hex: 0x68645C)
    /// Same value as ink. Used for emphasis, progress fills and selection.
    public static let accent = Color(hex: 0xF2F0EC)
    /// The dim wash behind a selected chip.
    public static let accentDim = Color.white.opacity(0.08)
    /// rgba(255,255,255,0.07) — every hairline border in the design.
    public static let line = Color.white.opacity(0.07)
    /// The track behind a progress fill.
    public static let track = Color.white.opacity(0.08)
    /// The wash behind a small inline badge.
    public static let badge = Color.white.opacity(0.05)
    /// The wash behind a context tag pill.
    public static let pill = Color.white.opacity(0.06)

    public enum Radius {
        public static let card: CGFloat = 22
        public static let row: CGFloat = 16
        public static let panel: CGFloat = 18
        public static let chip: CGFloat = 14
        public static let sheet: CGFloat = 28
    }

    public enum Padding {
        /// The 24pt gutter the phone screens are laid out on.
        public static let screen: CGFloat = 24
        /// The wider 32pt gutter used on the focused single-purpose screens.
        public static let focused: CGFloat = 32
        public static let card: CGFloat = 22
        public static let row: CGFloat = 16
    }
}

extension Color {
    /// Builds a colour from a hex literal so the token values above read the same as
    /// the design reference does.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Inter is the design's typeface. It is not bundled here, so these map onto the
/// system face at the same sizes and weights; swapping in the real font later means
/// changing this one file.
public enum Typeface {
    public static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
    public static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    public static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    public static func medium(_ size: CGFloat) -> Font { .system(size: size, weight: .medium) }
    public static func semibold(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }

    /// The running timer. Monospaced digits so the number does not jitter each tick.
    public static func timer(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).monospacedDigit()
    }
}
