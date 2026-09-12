import SwiftUI

// MARK: - AdaptiveColor Struct

/// A color that adapts to the current appearance mode (light/dark/system).
/// Uses rendering trait collection for smooth transitions without rebuilds.
///
/// Conforms to both `ShapeStyle` (so it drops into `.foregroundStyle()`,
/// `.background(_:in:)`, `.fill()`, `.tint()`, etc.) and `View` (so
/// `Theme.bg.ignoresSafeArea()` works the same way a plain `Color` would),
/// mirroring `Color`'s own dual conformance.
public struct AdaptiveColor: Equatable, Hashable, ShapeStyle, View {
    private let darkColor: Color
    private let lightColor: Color

    /// Resolved by the *rendering* trait collection rather than a fixed value, so
    /// `.preferredColorScheme` at the root flips every token everywhere it's used
    /// with no call site anywhere needing to know which mode is active.
    private var resolved: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(self.darkColor) : UIColor(self.lightColor)
        })
    }

    public var body: some View { resolved }

    public init(dark: Color, light: Color) {
        self.darkColor = dark
        self.lightColor = light
    }

    /// Creates an adaptive color from hex values for both modes.
    public init(hexDark: UInt32, hexLight: UInt32) {
        self.init(dark: Color(hex: hexDark), light: Color(hex: hexLight))
    }

    /// Creates an adaptive color with opacity that adapts to theme.
    public init(opacityDark: (Color, Double), opacityLight: (Color, Double)) {
        self.init(
            dark: opacityDark.0.opacity(opacityDark.1),
            light: opacityLight.0.opacity(opacityLight.1)
        )
    }

    /// Creates a solid adaptive color (same value for both modes).
    public init(solid hex: UInt32) {
        self.init(hexDark: hex, hexLight: hex)
    }

    /// Returns the dark color (for use in widgets and other contexts).
    public var dark: Color { self.darkColor }

    /// Returns the light color (for use in widgets and other contexts).
    public var light: Color { self.lightColor }
}

/// The exact tokens from the design reference, plus a light counterpart for each one.
/// Views pull from here rather than inventing colours, so the phone, watch and Mac
/// stay one design rather than three — and so light/dark stays a single edit here
/// rather than a hunt through every screen.
public enum Theme {
    // MARK: - Background & Surface Colors

    /// #141414 dark / #f7f5f1 light — the app background.
    public static let bg = AdaptiveColor(hexDark: 0x141414, hexLight: 0xF7F5F1)

    /// #1e1e1e dark / #ffffff light — raised cards, one step lighter than the
    /// background in both directions, so "raised" reads the same way in either mode.
    public static let card = AdaptiveColor(hexDark: 0x1E1E1E, hexLight: 0xFFFFFF)

    /// #252525 dark / #faf9f8 light — slightly darker than cards for panels/sections.
    public static let panel = AdaptiveColor(hexDark: 0x252525, hexLight: 0xF7F5F1)

    /// #2d2d2d dark / #e8e6e4 light — subtle surface elevation.
    public static let surface = AdaptiveColor(hexDark: 0x2D2D2D, hexLight: 0xE8E6E4)

    // MARK: - Text Colors

    /// #f2f0ec dark / #1a1917 light — primary text, and the fill on primary buttons.
    public static let primaryText = AdaptiveColor(hexDark: 0xF2F0EC, hexLight: 0x1A1917)

    /// #a8a49c dark / #6b675f light — secondary text.
    public static let secondaryText = AdaptiveColor(hexDark: 0xA8A49C, hexLight: 0x6B675F)

    /// #68645c dark / #a39e93 light — tertiary text, labels, captions.
    public static let tertiaryText = AdaptiveColor(hexDark: 0x68645C, hexLight: 0xA39E93)

    /// #525252 dark / #7a7671 light — muted placeholders and disabled states.
    public static let placeholder = AdaptiveColor(hexDark: 0x525252, hexLight: 0x7A7671)

    // MARK: - Accent & Selection

    /// Same value as primaryText in both modes. Used for emphasis, progress fills and
    /// selection.
    public static let accent = AdaptiveColor(hexDark: 0xF2F0EC, hexLight: 0x1A1917)

    /// The dim wash behind a selected chip — white in dark mode, the same primary-text
    /// colour at low opacity in light mode, so the wash always reads as "text, faded"
    /// rather than flipping to a literal white smear on a light background.
    public static let accentDim = AdaptiveColor(
        opacityDark: (.white, 0.08),
        opacityLight: (Color(hex: 0x1A1917), 0.06)
    )

    // MARK: - Border & Track Colors

    /// Every hairline border in the design.
    public static let border = AdaptiveColor(opacityDark: (.white, 0.07), opacityLight: (.black, 0.08))

    /// #2a2a2a dark / #d4d2d0 light — subtle dividers and tracks.
    public static let trackBackground = AdaptiveColor(hexDark: 0x2A2A2A, hexLight: 0xD4D2D0)

    /// The same as trackBackground but slightly darker for progress track background.
    public static let trackDark = AdaptiveColor(opacityDark: (.white, 0.10), opacityLight: (.black, 0.12))

    /// The wash behind a small inline badge.
    public static let badgeBg = AdaptiveColor(opacityDark: (.white, 0.05), opacityLight: (.black, 0.04))

    /// The wash behind a context tag pill.
    public static let pillBg = AdaptiveColor(opacityDark: (.white, 0.06), opacityLight: (.black, 0.05))

    // MARK: - Swipe Action Button Colors

    /// Delete button background — red, same in both modes.
    public static let deleteButtonBg = AdaptiveColor(solid: 0xFF5252)
    public static let deleteButtonBgOpaque = AdaptiveColor(solid: 0xFF5252)

    /// Edit button background — blue, same in both modes.
    public static let editButtonBg = AdaptiveColor(solid: 0x4285F4)
    public static let editButtonBgOpaque = AdaptiveColor(solid: 0x4285F4)

    /// Start again button background — green, same in both modes.
    public static let startAgainButtonBg = AdaptiveColor(solid: 0x4CAF50)
    public static let startAgainButtonBgOpaque = AdaptiveColor(solid: 0x4CAF50)

    // MARK: - Status Colors

    public static let success = AdaptiveColor(solid: 0x4CAF50)
    public static let warning = AdaptiveColor(solid: 0xFFC107)
    public static let error = AdaptiveColor(solid: 0xF44336)

    // MARK: - Radius Constants

    public enum Radius {
        public static let card: CGFloat = 22
        public static let row: CGFloat = 16
        public static let panel: CGFloat = 18
        public static let chip: CGFloat = 14
        public static let sheet: CGFloat = 28
        public static let small: CGFloat = 10
        public static let tiny: CGFloat = 6
    }

    // MARK: - Spacing Constants

    public enum Spacing {
        /// The 24pt gutter the phone screens are laid out on.
        public static let screen: CGFloat = 24
        /// The wider 32pt gutter used on the focused single-purpose screens.
        public static let focused: CGFloat = 32
        public static let card: CGFloat = 22
        public static let row: CGFloat = 16
        public static let compact: CGFloat = 14
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
}

public enum Typeface {
    /// A modest across-the-board bump applied to every size passed to the functions
    /// below, so every screen reads slightly larger without a per-call-site pass
    /// through the whole design system.
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
