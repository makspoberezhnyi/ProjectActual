import SwiftUI

/// The exact tokens from the design reference, plus a light counterpart for each one.
/// Views pull from here rather than inventing colours, so the phone, watch and Mac
/// stay one design rather than three — and so light/dark stays a single edit here
/// rather than a hunt through every screen.
public enum Theme {
    /// #141414 dark / #f7f5f1 light — the app background.
    public static let bg = Color.dynamic(dark: 0x141414, light: 0xF7F5F1)
    /// #1e1e1e dark / #ffffff light — raised cards, one step lighter than the
    /// background in both directions, so "raised" reads the same way in either mode.
    public static let card = Color.dynamic(dark: 0x1E1E1E, light: 0xFFFFFF)
    /// #f2f0ec dark / #1a1917 light — primary text, and the fill on primary buttons.
    public static let ink = Color.dynamic(dark: 0xF2F0EC, light: 0x1A1917)
    /// #a8a49c dark / #6b675f light — secondary text.
    public static let inkSoft = Color.dynamic(dark: 0xA8A49C, light: 0x6B675F)
    /// #68645c dark / #a39e93 light — tertiary text, labels, captions.
    public static let inkFaint = Color.dynamic(dark: 0x68645C, light: 0xA39E93)
    /// Same value as ink in both modes. Used for emphasis, progress fills and selection.
    public static let accent = Color.dynamic(dark: 0xF2F0EC, light: 0x1A1917)
    /// The dim wash behind a selected chip — white in dark mode, the same ink colour
    /// at low opacity in light mode, so the wash always reads as "ink, faded" rather
    /// than flipping to a literal white smear on a light background.
    public static let accentDim = Color.dynamicOpacity(dark: (.white, 0.08), light: (Color(hex: 0x1A1917), 0.06))
    /// Every hairline border in the design.
    public static let line = Color.dynamicOpacity(dark: (.white, 0.07), light: (.black, 0.08))
    /// The track behind a progress fill.
    public static let track = Color.dynamicOpacity(dark: (.white, 0.08), light: (.black, 0.08))
    /// The wash behind a small inline badge.
    public static let badge = Color.dynamicOpacity(dark: (.white, 0.05), light: (.black, 0.04))
    /// The wash behind a context tag pill.
    public static let pill = Color.dynamicOpacity(dark: (.white, 0.06), light: (.black, 0.05))

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

/// Light, dark, or whatever the system is set to. Stored under this key so
/// `RootView` can read it with a plain `@AppStorage` and apply
/// `.preferredColorScheme` once at the root — every screen below inherits it
/// through the `Theme` tokens above without needing to know this exists.
public enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
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

    /// A colour that switches between two hex values by the *rendering* trait
    /// collection rather than a fixed value — this is what lets `.preferredColorScheme`
    /// at the root flip every `Theme` token everywhere it's used, with no call site
    /// anywhere needing to know which mode is active.
    static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    /// The same switching behaviour for the app's translucent washes, which are
    /// white-on-dark and need to become black-on-light rather than staying literally
    /// white once the background itself turns light.
    static func dynamicOpacity(dark: (Color, Double), light: (Color, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark.0.opacity(dark.1))
                : UIColor(light.0.opacity(light.1))
        })
    }
}

/// Inter is the design's typeface. It is not bundled here, so these map onto the
/// system face at the same sizes and weights; swapping in the real font later means
/// changing this one file.
public enum Typeface {
    /// A modest across-the-board bump over the design reference's literal sizes —
    /// every call site already passes its own explicit size, so this is the one place
    /// that makes all of them read a little larger without hunting through every
    /// screen's font calls one at a time.
    private static let scale: CGFloat = 1.08

    public static func display(_ size: CGFloat) -> Font { .system(size: size * scale, weight: .bold) }
    public static func title(_ size: CGFloat) -> Font { .system(size: size * scale, weight: .semibold) }
    public static func body(_ size: CGFloat) -> Font { .system(size: size * scale, weight: .regular) }
    public static func medium(_ size: CGFloat) -> Font { .system(size: size * scale, weight: .medium) }
    public static func semibold(_ size: CGFloat) -> Font { .system(size: size * scale, weight: .semibold) }

    /// The running timer. Monospaced digits so the number does not jitter each tick.
    public static func timer(_ size: CGFloat) -> Font {
        .system(size: size * scale, weight: .bold).monospacedDigit()
    }
}
