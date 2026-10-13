import SwiftUI
import UIKit

// Objects that sit on the desk: physical keys you press, and paper cards you read.
// Everything interactive in the scene is one of these, so controls feel like part of the room.

enum DeskKeyTone {
    case paper, orange, carbon

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

    var top: Color {
        switch self {
        case .paper: return Self.dynamic(light: 0xFAF7F1, dark: 0x3A4258)
        case .orange: return TempoMascotPalette.orange
        case .carbon: return Self.dynamic(light: 0x2B2B2B, dark: 0x1F2433)
        }
    }

    var side: Color {
        switch self {
        case .paper: return Self.dynamic(light: 0xD6CBBA, dark: 0x232838)
        case .orange: return Color(red: 0.76, green: 0.23, blue: 0)
        case .carbon: return Self.dynamic(light: 0x0E0E0E, dark: 0x0B0E16)
        }
    }

    var ink: Color {
        switch self {
        case .paper: return Self.dynamic(light: 0x1A1A1A, dark: 0xF6F4F0)
        case .orange, .carbon: return Color(red: 0.965, green: 0.957, blue: 0.941)
        }
    }
}

/// A key standing on the desk: a top face over a darker side, with a contact shadow.
/// It sinks when pressed, and stays half sunk while `latched` (a selected preset).
struct DeskKeyStyle: ButtonStyle {
    var tone: DeskKeyTone = .paper
    var cornerRadius: CGFloat = 14
    var latched = false
    static let travel: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        let sunk: CGFloat = configuration.isPressed ? Self.travel - 1 : (latched ? Self.travel - 3 : 0)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack(alignment: .top) {
            shape
                .fill(Color.black.opacity(0.22 - sunk * 0.015))
                .blur(radius: 5)
                .offset(y: Self.travel + 5)
                .padding(.horizontal, 4)
            shape
                .fill(tone.side)
                .offset(y: Self.travel)
            configuration.label
                .foregroundStyle(tone.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    shape.fill(tone.top)
                        .overlay(
                            shape.fill(LinearGradient(colors: [Color.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                        )
                        .overlay(shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                )
                .clipShape(shape)
                .offset(y: sunk)
        }
        .padding(.bottom, Self.travel)
        .animation(.spring(duration: 0.18, bounce: 0.35), value: configuration.isPressed)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: latched)
        .onChange(of: configuration.isPressed) { _, pressed in
            if pressed { TactileFeedback.light() }
        }
    }
}

extension View {
    /// A sheet of paper lying on the desk.
    func deskPaper(cornerRadius: CGFloat = 12) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DeskKeyTone.paper.top)
                .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 4)
        )
    }
}

/// Where the notch, home indicator and status bar are, independent of the keyboard.
@MainActor
enum DeviceInsets {
    static var current: UIEdgeInsets {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets ?? UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    }
}
