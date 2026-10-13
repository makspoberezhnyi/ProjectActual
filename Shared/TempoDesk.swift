import SwiftUI
import UIKit

// The mascot is a desk clock, so it lives on a desk: a zoomed-in table seen from slightly above.
// DeskSurface is pinned to the mascot (its back edge sits behind the clock, its feet stand on it).
// DeskFront is pinned under the controls: the rounded front edge, the shade under the table, the legs.

enum DeskPalette {
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

    /// Light oak by day, walnut in dark mode.
    static let surface = dynamic(light: 0xE9D6B9, dark: 0x3A2F27)
    static let surfaceFar = dynamic(light: 0xD8C09D, dark: 0x2C241E)
    static let grain = dynamic(light: 0xC9AC84, dark: 0x4A3D33)
    static let lip = dynamic(light: 0xF3E6D2, dark: 0x51443A)
    static let edge = dynamic(light: 0xCDAE85, dark: 0x2A211B)
    static let edgeDark = dynamic(light: 0xB08E63, dark: 0x1E1814)
    static let leg = dynamic(light: 0xBF9D70, dark: 0x2A211B)
    static let legShade = dynamic(light: 0xA98760, dark: 0x1C1612)
    static let under = dynamic(light: 0xE6E2DA, dark: 0x0C1220)
    /// The wall behind the desk: the app's own background color.
    static let wall = dynamic(light: 0xF6F4F0, dark: 0x11182B)
    static let ink = dynamic(light: 0x1A1A1A, dark: 0xF6F4F0)
    static let muted = dynamic(light: 0x6E6A61, dark: 0x9FADC9)
}

/// Where the clock's feet touch the surface, as a share of the mascot's frame height.
/// Matches the renderer: feet at y 254 of a 268 tall drawing.
let mascotFootFraction: CGFloat = 254.0 / 268.0

// MARK: - Surface

/// Table top from its back edge down. Faint grain lines run toward a vanishing point for depth.
struct DeskSurface: View {
    /// How far above the back edge the grain lines meet, as a share of the desk's height.
    /// Small values look like a low, steep view across the desk.
    var vanishingLift: CGFloat = 1.6

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [DeskPalette.surfaceFar, DeskPalette.surface],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.22)
            )
            DeskGrain(vanishingLift: vanishingLift)
                .stroke(DeskPalette.grain.opacity(0.45), lineWidth: 1)
            // Where the desk meets the wall: a crisp line and a soft contact shade.
            LinearGradient(colors: [Color.black.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 14)
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DeskGrain: Shape {
    var vanishingLift: CGFloat

    var animatableData: CGFloat {
        get { vanishingLift }
        set { vanishingLift = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let vanishing = CGPoint(x: rect.midX, y: rect.minY - rect.height * vanishingLift)
        let count = 14
        for i in 0...count {
            let x = rect.minX - rect.width * 0.4 + rect.width * 1.8 * CGFloat(i) / CGFloat(count)
            let bottom = CGPoint(x: x, y: rect.maxY)
            // Point on the line from the vanishing point to the bottom, at the back edge.
            let t = (rect.minY - vanishing.y) / (bottom.y - vanishing.y)
            let top = CGPoint(x: vanishing.x + (bottom.x - vanishing.x) * t, y: rect.minY)
            p.move(to: top)
            p.addLine(to: bottom)
        }
        return p
    }
}

// MARK: - Front edge and legs

/// The near edge of the table and what's under it. Its top is the front edge of the desk.
struct DeskFront: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let legWidth: CGFloat = 26
            let inset: CGFloat = 22
            ZStack(alignment: .top) {
                // Under the table: the wall behind, in the table's shade.
                LinearGradient(
                    colors: [Color.black.opacity(0.22), Color.black.opacity(0.06)],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.25)
                )
                .background(DeskPalette.under)

                // Legs, slightly tapered.
                ForEach([inset, w - inset - legWidth], id: \.self) { x in
                    LinearGradient(colors: [DeskPalette.leg, DeskPalette.legShade], startPoint: .leading, endPoint: .trailing)
                        .frame(width: legWidth)
                        .clipShape(DeskLegShape())
                        .position(x: x + legWidth / 2, y: geo.size.height / 2 + 10)
                }

                // Apron under the top, then the rounded front edge with its light lip.
                VStack(spacing: 0) {
                    Rectangle().fill(DeskPalette.lip).frame(height: 2)
                    LinearGradient(colors: [DeskPalette.edge, DeskPalette.edgeDark], startPoint: .top, endPoint: .bottom)
                        .frame(height: 16)
                    Rectangle().fill(DeskPalette.edgeDark).frame(height: 10)
                    LinearGradient(colors: [Color.black.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 12)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DeskLegShape: Shape {
    func path(in rect: CGRect) -> Path {
        let taper: CGFloat = 4
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + taper, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Small rooms (widgets, Live Activity)

/// A whole little scene for small surfaces: wall on top, desk from `horizon` (share of the height) down.
struct DeskBackdrop: View {
    var horizon: CGFloat = 0.62

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                DeskPalette.wall
                DeskSurface()
                    .frame(height: geo.size.height * (1 - horizon))
                    .offset(y: geo.size.height * horizon)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Places a static mascot of `size` so its feet stand at `feetY`, horizontally centered on `x`.
struct MascotStanding: View {
    let regime: TempoMascotRegime
    let size: CGFloat
    let x: CGFloat
    let feetY: CGFloat
    var bezelProgress: Double? = nil

    var body: some View {
        TempoWatchMascotView(regime: regime, size: size, animated: false, overrideBezelProgress: bezelProgress)
            .position(x: x, y: feetY - size * mascotFootFraction + size / 2)
    }
}

// MARK: - Placement helpers

extension View {
    /// Puts the desk surface behind a mascot of `size`, with the back edge `depth` points behind its feet.
    func standingOnDesk(mascotSize size: CGFloat, depth: CGFloat = 64, reach: CGFloat = 1200) -> some View {
        background(alignment: .top) {
            DeskSurface()
                .containerRelativeFrame(.horizontal)
                .frame(height: reach)
                .offset(y: size * mascotFootFraction - depth)
        }
    }

    /// Hangs the table's front edge and legs from the bottom of this view.
    func deskFrontEdge(gap: CGFloat = 4, reach: CGFloat = 700) -> some View {
        background(alignment: .top) {
            GeometryReader { geo in
                DeskFront()
                    .containerRelativeFrame(.horizontal)
                    .frame(height: reach)
                    // Centered under this view (which is centered on screen), starting just below it.
                    .position(x: geo.size.width / 2, y: geo.size.height + gap + reach / 2)
            }
        }
    }
}

#Preview("Desk") {
    VStack(spacing: 0) {
        TempoInteractiveMascotView(regime: .timerDialing, size: 200)
            .standingOnDesk(mascotSize: 200)
        Spacer().frame(height: 180)
        Text("controls")
            .frame(height: 60)
            .deskFrontEdge()
        Spacer()
    }
}
