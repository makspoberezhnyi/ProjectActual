import SwiftUI
import UIKit

// MARK: - Adaptive colors (light + dark, never pure black)

extension Color {
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let tempoInk = dynamic(light: 0x1A1A1A, dark: 0xF6F4F0)
    static let tempoMuted = dynamic(light: 0x7A776F, dark: 0x9FADC9)
    static let tempoAccent = Color(red: 1, green: 0.31, blue: 0)
}

// MARK: - Soft aura behind the hero mascot

struct TempoAura: View {
    var size: CGFloat = 340

    var body: some View {
        RadialGradient(
            colors: [Color.tempoAccent.opacity(0.22), Color.tempoAccent.opacity(0)],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Round icon button (one primary per screen, the rest are ghosts)

struct TempoRoundButton: View {
    let symbol: String
    let label: LocalizedStringKey
    var isPrimary: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: isPrimary ? 28 : 20, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(isPrimary ? Color.white : Color.tempoInk)
                .frame(width: isPrimary ? 76 : 54, height: isPrimary ? 76 : 54)
                .background(
                    Circle().fill(isPrimary ? Color.tempoAccent : Color.tempoInk.opacity(0.08))
                )
        }
        .buttonStyle(TempoPressStyle())
        .accessibilityLabel(label)
    }
}

struct TempoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: - Big thin numerals

extension Font {
    static func tempoNumerals(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .rounded).monospacedDigit()
    }
}

enum TempoFormat {
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func stopwatch(_ seconds: TimeInterval) -> String {
        let t = max(0, seconds)
        let m = Int(t) / 60
        let s = Int(t) % 60
        let c = Int((t - floor(t)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, c)
    }
}
