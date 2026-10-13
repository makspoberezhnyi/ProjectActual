import SwiftUI

// A window on the wall that looks out on a city, drawn live in that city's own light:
// the sun or moon where it is right now, stars at night, lit windows after dark, and the landmarks
// that make it that city. Layers move at different speeds when you pan, for a bit of depth.

enum CityLandmark: String {
    case eiffel, bigBen, empireState, tokyoTower, goldenGate, operaHouse, burjKhalifa
    case culturePalace, goldenDomes, tvTower, colosseum, skyline

    /// Picks the landmark from the city name or its time zone.
    static func forCity(name: String, timeZone: String) -> CityLandmark {
        let key = (name + " " + timeZone).lowercased()
        if key.contains("paris") { return .eiffel }
        if key.contains("london") { return .bigBen }
        if key.contains("new york") || key.contains("new_york") { return .empireState }
        if key.contains("tokyo") { return .tokyoTower }
        if key.contains("francisco") { return .goldenGate }
        if key.contains("sydney") { return .operaHouse }
        if key.contains("dubai") { return .burjKhalifa }
        if key.contains("warsaw") || key.contains("warszawa") { return .culturePalace }
        if key.contains("kyiv") || key.contains("kiev") { return .goldenDomes }
        if key.contains("berlin") { return .tvTower }
        if key.contains("rome") || key.contains("roma") { return .colosseum }
        return .skyline
    }

    var hasWater: Bool { self == .goldenGate || self == .operaHouse || self == .empireState }
    var hasMountain: Bool { self == .tokyoTower }
}

/// How the light looks at a given local hour.
struct CityLight {
    let skyTop: Color
    let skyBottom: Color
    let night: Double        // 0 day ... 1 deep night
    let dusk: Double         // warm glow around sunrise and sunset

    private static let keys: [(h: Double, top: (Double, Double, Double), bottom: (Double, Double, Double))] = [
        (0, (0.04, 0.06, 0.16), (0.11, 0.15, 0.31)),
        (5, (0.11, 0.15, 0.31), (0.23, 0.25, 0.45)),
        (6.5, (0.37, 0.44, 0.70), (0.96, 0.69, 0.51)),
        (8, (0.50, 0.72, 0.93), (0.80, 0.91, 0.97)),
        (12, (0.37, 0.66, 0.91), (0.75, 0.89, 0.97)),
        (17, (0.47, 0.68, 0.88), (0.95, 0.83, 0.64)),
        (19, (0.29, 0.31, 0.56), (0.94, 0.54, 0.36)),
        (20.5, (0.13, 0.16, 0.35), (0.36, 0.29, 0.54)),
        (22, (0.05, 0.09, 0.22), (0.12, 0.17, 0.31)),
        (24, (0.04, 0.06, 0.16), (0.11, 0.15, 0.31))
    ]

    init(hour: Double) {
        let h = hour.truncatingRemainder(dividingBy: 24)
        var i = 0
        while i < Self.keys.count - 2 && h >= Self.keys[i + 1].h { i += 1 }
        let a = Self.keys[i], b = Self.keys[i + 1]
        let t = (h - a.h) / max(0.001, b.h - a.h)
        func mix(_ x: (Double, Double, Double), _ y: (Double, Double, Double)) -> Color {
            Color(red: x.0 + (y.0 - x.0) * t, green: x.1 + (y.1 - x.1) * t, blue: x.2 + (y.2 - x.2) * t)
        }
        skyTop = mix(a.top, b.top)
        skyBottom = mix(a.bottom, b.bottom)
        func ramp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(1, max(0, (v - lo) / (hi - lo))) }
        night = max(1 - ramp(h, 5, 7.5), ramp(h, 19, 21.5))
        dusk = max(1 - abs(h - 6.6) / 1.4, 1 - abs(h - 19.2) / 1.6, 0)
    }

    func blend(_ day: (Double, Double, Double), _ nightColor: (Double, Double, Double), warm: (Double, Double, Double)? = nil) -> Color {
        var r = day.0 + (nightColor.0 - day.0) * night
        var g = day.1 + (nightColor.1 - day.1) * night
        var b = day.2 + (nightColor.2 - day.2) * night
        if let warm {
            r += (warm.0 - r) * dusk * 0.45
            g += (warm.1 - g) * dusk * 0.45
            b += (warm.2 - b) * dusk * 0.45
        }
        return Color(red: r, green: g, blue: b)
    }
}

/// Tiny deterministic random numbers, so each city always gets the same skyline.
struct SeededRandom {
    private var state: UInt64
    init(_ text: String) {
        state = text.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }
    mutating func next() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

/// The view through the window. `pan` (points) slides the layers at different speeds.
struct CityPanorama: View, Animatable {
    let name: String
    let landmark: CityLandmark
    let hour: Double
    var pan: CGFloat

    var animatableData: CGFloat {
        get { pan }
        set { pan = newValue }
    }

    var body: some View {
        Canvas { ctx, size in
            draw(&ctx, size)
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        let light = CityLight(hour: hour)
        let ground = h * (landmark.hasWater ? 0.80 : 0.92)

        // Sky
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(Gradient(colors: [light.skyTop, light.skyBottom]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

        // Stars
        if light.night > 0.05 {
            var rnd = SeededRandom(name + "stars")
            for _ in 0..<46 {
                let x = rnd.range(0, w * 1.6) - w * 0.3 + pan * 0.08
                let y = rnd.range(0, h * 0.6)
                let r = rnd.range(0.6, 1.6)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(.white.opacity(light.night * rnd.range(0.4, 0.95))))
            }
        }

        // Sun by day, moon by night, riding an arc across the window.
        drawSunOrMoon(&ctx, w: w, h: h, light: light)

        // Far layer: hills (and Fuji), barely moving.
        let farColor = light.blend((0.66, 0.73, 0.84), (0.15, 0.19, 0.35), warm: (0.80, 0.55, 0.58))
        ctx.drawLayer { far in
            far.translateBy(x: pan * 0.2, y: 0)
            if landmark.hasMountain {
                var fuji = Path()
                let cx = w * 0.72, top = h * 0.30
                fuji.move(to: CGPoint(x: cx - w * 0.55, y: ground))
                fuji.addLine(to: CGPoint(x: cx - w * 0.07, y: top))
                fuji.addLine(to: CGPoint(x: cx + w * 0.07, y: top))
                fuji.addLine(to: CGPoint(x: cx + w * 0.55, y: ground))
                far.fill(fuji, with: .color(farColor))
                var cap = Path()
                cap.move(to: CGPoint(x: cx - w * 0.115, y: top + h * 0.09))
                cap.addLine(to: CGPoint(x: cx - w * 0.07, y: top))
                cap.addLine(to: CGPoint(x: cx + w * 0.07, y: top))
                cap.addLine(to: CGPoint(x: cx + w * 0.115, y: top + h * 0.09))
                cap.addLine(to: CGPoint(x: cx + w * 0.04, y: top + h * 0.06))
                cap.addLine(to: CGPoint(x: cx, y: top + h * 0.1))
                cap.addLine(to: CGPoint(x: cx - w * 0.04, y: top + h * 0.06))
                cap.closeSubpath()
                far.fill(cap, with: .color(.white.opacity(0.9 - light.night * 0.4)))
            }
            var hills = Path()
            var rnd = SeededRandom(name + "hills")
            let a1 = rnd.range(0.5, 1.5), a2 = rnd.range(2, 4), p = rnd.range(0, 6)
            hills.move(to: CGPoint(x: -w, y: ground))
            var x = -w
            while x <= w * 2 {
                let t = Double(x / w)
                let y = ground - h * (0.08 + 0.05 * sin(t * a1 * .pi + p) + 0.03 * sin(t * a2 * .pi))
                hills.addLine(to: CGPoint(x: x, y: y))
                x += 8
            }
            hills.addLine(to: CGPoint(x: w * 2, y: h))
            hills.addLine(to: CGPoint(x: -w, y: h))
            hills.closeSubpath()
            far.fill(hills, with: .color(farColor.opacity(0.85)))
        }

        // Mid layer: the city's skyline, windows lit after dark.
        let midColor = light.blend((0.42, 0.50, 0.64), (0.08, 0.11, 0.22), warm: (0.45, 0.32, 0.42))
        let windowGlow = Color(red: 1.0, green: 0.82, blue: 0.45)
        ctx.drawLayer { mid in
            mid.translateBy(x: pan * 0.55, y: 0)
            var rnd = SeededRandom(name + "city")
            var x = -w * 0.8
            while x < w * 1.8 {
                let bw = rnd.range(16, 38)
                let bh = h * rnd.range(0.10, landmark == .skyline ? 0.42 : 0.28)
                let rect = CGRect(x: x, y: ground - bh, width: bw, height: bh)
                mid.fill(Path(rect), with: .color(midColor))
                if light.night > 0.25 {
                    var wy = rect.minY + 5
                    while wy < ground - 4 {
                        var wx = rect.minX + 4
                        while wx < rect.maxX - 4 {
                            if rnd.next() < 0.38 {
                                mid.fill(Path(CGRect(x: wx, y: wy, width: 3, height: 3.5)),
                                         with: .color(windowGlow.opacity(light.night * 0.85)))
                            }
                            wx += 7
                        }
                        wy += 8
                    }
                }
                x += bw + rnd.range(1, 6)
            }
        }

        // Near layer: the landmark, moving with your finger.
        let nearColor = light.blend((0.30, 0.36, 0.48), (0.04, 0.06, 0.14), warm: (0.32, 0.22, 0.30))
        ctx.drawLayer { near in
            near.translateBy(x: pan, y: 0)
            drawLandmark(&near, w: w, h: h, ground: ground, color: nearColor, light: light)
        }

        // Water for harbour cities, with a shimmer of reflected light.
        if landmark.hasWater {
            let water = light.blend((0.36, 0.55, 0.74), (0.05, 0.08, 0.18), warm: (0.80, 0.50, 0.40))
            ctx.fill(Path(CGRect(x: 0, y: ground, width: w, height: h - ground)), with: .color(water))
            var rnd = SeededRandom(name + "water")
            for _ in 0..<14 {
                let lx = rnd.range(0, w) + pan * 0.3
                let ly = rnd.range(ground + 4, h - 2)
                let lw = rnd.range(10, 34)
                ctx.fill(Path(CGRect(x: lx, y: ly, width: lw, height: 1.2)),
                         with: .color((light.night > 0.5 ? windowGlow : .white).opacity(0.35)))
            }
        }
    }

    private func drawSunOrMoon(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, light: CityLight) {
        let hr = hour.truncatingRemainder(dividingBy: 24)
        let isDay = hr >= 6 && hr < 19.5
        let t = isDay ? (hr - 6) / 13.5 : ((hr - 19.5 + 24).truncatingRemainder(dividingBy: 24)) / 10.5
        let x = w * (0.1 + 0.8 * t) + pan * 0.1
        let y = h * 0.62 - sin(.pi * t) * h * 0.46
        if isDay {
            let low = 1 - sin(.pi * t)
            let sun = Color(red: 1, green: 0.88 - low * 0.25, blue: 0.55 - low * 0.35)
            let center = CGPoint(x: x, y: y)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 32, y: y - 32, width: 64, height: 64)),
                with: .radialGradient(Gradient(colors: [sun.opacity(0.5), sun.opacity(0)]), center: center, startRadius: 8, endRadius: 32)
            )
            ctx.fill(Path(ellipseIn: CGRect(x: x - 11, y: y - 11, width: 22, height: 22)), with: .color(sun))
        } else {
            let moon = Color(red: 0.95, green: 0.95, blue: 0.88)
            let center = CGPoint(x: x, y: y)
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 26, y: y - 26, width: 52, height: 52)),
                with: .radialGradient(Gradient(colors: [moon.opacity(0.22), moon.opacity(0)]), center: center, startRadius: 6, endRadius: 26)
            )
            // A real crescent: the disc minus an offset disc, so the sky shows through.
            let disc = Path(ellipseIn: CGRect(x: x - 10, y: y - 10, width: 20, height: 20))
            let bite = Path(ellipseIn: CGRect(x: x - 4, y: y - 13, width: 20, height: 20))
            ctx.fill(disc.subtracting(bite), with: .color(moon))
        }
    }

    // MARK: - Landmarks

    private func drawLandmark(_ ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, ground: CGFloat, color: Color, light: CityLight) {
        let lit = light.night > 0.5
        switch landmark {
        case .eiffel:
            eiffel(&ctx, x: w * 0.24, ground: ground, size: h * 0.82, color: lit ? Color(red: 0.95, green: 0.72, blue: 0.32) : color)
        case .bigBen:
            bigBen(&ctx, x: w * 0.18, ground: ground, size: h * 0.78, color: color, face: lit ? Color(red: 1, green: 0.85, blue: 0.5) : Color(white: 0.9))
            londonEye(&ctx, x: w * 0.84, ground: ground, size: h * 0.62, color: color)
        case .empireState:
            empire(&ctx, x: w * 0.2, ground: ground, size: h * 0.78, color: color, lit: lit)
            chrysler(&ctx, x: w * 0.86, ground: ground, size: h * 0.6, color: color)
        case .tokyoTower:
            tokyoTower(&ctx, x: w * 0.22, ground: ground, size: h * 0.78, light: light)
        case .goldenGate:
            goldenGate(&ctx, w: w, ground: ground, size: h * 0.62, light: light)
        case .operaHouse:
            opera(&ctx, x: w * 0.2, ground: ground, size: h * 0.30, lit: lit)
            harbourBridge(&ctx, x: w * 0.8, ground: ground, size: h * 0.34, color: color)
        case .burjKhalifa:
            burj(&ctx, x: w * 0.22, ground: ground, size: h * 0.9, color: color, lit: lit)
        case .culturePalace:
            palace(&ctx, x: w * 0.2, ground: ground, size: h * 0.74, color: color)
        case .goldenDomes:
            domes(&ctx, x: w * 0.2, ground: ground, size: h * 0.46, color: color)
        case .tvTower:
            tvTower(&ctx, x: w * 0.22, ground: ground, size: h * 0.86, color: color, lit: lit)
        case .colosseum:
            colosseum(&ctx, x: w * 0.06, ground: ground, size: h * 0.32, width: w * 0.36, color: color)
        case .skyline:
            break
        }
    }

    private func eiffel(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        var p = Path()
        let b = s * 0.30
        p.move(to: CGPoint(x: x - b, y: g))
        p.addQuadCurve(to: CGPoint(x: x - s * 0.025, y: g - s * 0.86), control: CGPoint(x: x - s * 0.06, y: g - s * 0.45))
        p.addLine(to: CGPoint(x: x + s * 0.025, y: g - s * 0.86))
        p.addQuadCurve(to: CGPoint(x: x + b, y: g), control: CGPoint(x: x + s * 0.06, y: g - s * 0.45))
        p.addLine(to: CGPoint(x: x + b * 0.62, y: g))
        p.addQuadCurve(to: CGPoint(x: x - b * 0.62, y: g), control: CGPoint(x: x, y: g - s * 0.36))
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
        ctx.fill(Path(CGRect(x: x - b * 0.62, y: g - s * 0.25, width: b * 1.24, height: s * 0.035)), with: .color(color))
        ctx.fill(Path(CGRect(x: x - b * 0.32, y: g - s * 0.55, width: b * 0.64, height: s * 0.03)), with: .color(color))
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.86)); $0.addLine(to: CGPoint(x: x, y: g - s)) },
                   with: .color(color), lineWidth: 2)
    }

    private func bigBen(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color, face: Color) {
        let tw = s * 0.15
        ctx.fill(Path(CGRect(x: x - tw / 2, y: g - s * 0.72, width: tw, height: s * 0.72)), with: .color(color))
        var roof = Path()
        roof.move(to: CGPoint(x: x - tw * 0.6, y: g - s * 0.72))
        roof.addLine(to: CGPoint(x: x, y: g - s))
        roof.addLine(to: CGPoint(x: x + tw * 0.6, y: g - s * 0.72))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: x - tw * 0.36, y: g - s * 0.64, width: tw * 0.72, height: tw * 0.72)), with: .color(face))
        ctx.fill(Path(CGRect(x: x + tw / 2, y: g - s * 0.2, width: s * 0.55, height: s * 0.2)), with: .color(color))
    }

    private func londonEye(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        let r = s * 0.46
        let c = CGPoint(x: x, y: g - r - s * 0.06)
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color), lineWidth: 3)
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            ctx.stroke(Path { $0.move(to: c); $0.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))) },
                       with: .color(color.opacity(0.7)), lineWidth: 0.8)
        }
        ctx.stroke(Path { $0.move(to: CGPoint(x: c.x - r * 0.35, y: g)); $0.addLine(to: c); $0.addLine(to: CGPoint(x: c.x + r * 0.35, y: g)) },
                   with: .color(color), lineWidth: 3)
    }

    private func empire(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color, lit: Bool) {
        let steps: [(CGFloat, CGFloat)] = [(0.30, 0.45), (0.22, 0.70), (0.14, 0.82), (0.08, 0.90)]
        for (wid, top) in steps {
            ctx.fill(Path(CGRect(x: x - s * wid / 2, y: g - s * top, width: s * wid, height: s * top)), with: .color(color))
        }
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.9)); $0.addLine(to: CGPoint(x: x, y: g - s)) }, with: .color(color), lineWidth: 2.5)
        if lit {
            ctx.fill(Path(CGRect(x: x - s * 0.04, y: g - s * 0.88, width: s * 0.08, height: s * 0.05)),
                     with: .color(Color(red: 1, green: 0.8, blue: 0.4)))
        }
    }

    private func chrysler(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        ctx.fill(Path(CGRect(x: x - s * 0.08, y: g - s * 0.78, width: s * 0.16, height: s * 0.78)), with: .color(color))
        var crown = Path()
        crown.move(to: CGPoint(x: x - s * 0.08, y: g - s * 0.78))
        crown.addQuadCurve(to: CGPoint(x: x, y: g - s), control: CGPoint(x: x - s * 0.07, y: g - s * 0.92))
        crown.addQuadCurve(to: CGPoint(x: x + s * 0.08, y: g - s * 0.78), control: CGPoint(x: x + s * 0.07, y: g - s * 0.92))
        crown.closeSubpath()
        ctx.fill(crown, with: .color(color))
    }

    private func tokyoTower(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, light: CityLight) {
        let red = light.blend((0.91, 0.29, 0.17), (0.95, 0.45, 0.20))
        var p = Path()
        p.move(to: CGPoint(x: x - s * 0.2, y: g))
        p.addLine(to: CGPoint(x: x - s * 0.03, y: g - s * 0.82))
        p.addLine(to: CGPoint(x: x + s * 0.03, y: g - s * 0.82))
        p.addLine(to: CGPoint(x: x + s * 0.2, y: g))
        p.addLine(to: CGPoint(x: x + s * 0.11, y: g))
        p.addQuadCurve(to: CGPoint(x: x - s * 0.11, y: g), control: CGPoint(x: x, y: g - s * 0.2))
        p.closeSubpath()
        ctx.fill(p, with: .color(red))
        for (y, wid) in [(0.38, 0.17), (0.66, 0.10)] {
            ctx.fill(Path(CGRect(x: x - s * wid / 2, y: g - s * y, width: s * wid, height: s * 0.05)), with: .color(Color(white: 0.95)))
        }
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.82)); $0.addLine(to: CGPoint(x: x, y: g - s)) }, with: .color(red), lineWidth: 2)
    }

    private func goldenGate(_ ctx: inout GraphicsContext, w: CGFloat, ground g: CGFloat, size s: CGFloat, light: CityLight) {
        let red = light.blend((0.75, 0.21, 0.17), (0.55, 0.18, 0.16))
        let deck = g - s * 0.22
        let t1 = w * 0.12, t2 = w * 0.70
        for tx in [t1, t2] {
            ctx.fill(Path(CGRect(x: tx - s * 0.05, y: g - s, width: s * 0.03, height: s)), with: .color(red))
            ctx.fill(Path(CGRect(x: tx + s * 0.02, y: g - s, width: s * 0.03, height: s)), with: .color(red))
            for f in [0.35, 0.62, 0.9] {
                ctx.fill(Path(CGRect(x: tx - s * 0.05, y: g - s * f, width: s * 0.10, height: s * 0.025)), with: .color(red))
            }
        }
        ctx.fill(Path(CGRect(x: -w, y: deck, width: w * 3, height: s * 0.035)), with: .color(red))
        var cable = Path()
        cable.move(to: CGPoint(x: -w * 0.3, y: deck))
        cable.addQuadCurve(to: CGPoint(x: t1, y: g - s), control: CGPoint(x: (t1 - w * 0.3) / 2, y: deck - s * 0.1))
        cable.addQuadCurve(to: CGPoint(x: t2, y: g - s), control: CGPoint(x: (t1 + t2) / 2, y: deck + s * 0.55))
        cable.addQuadCurve(to: CGPoint(x: w * 1.3, y: deck), control: CGPoint(x: (t2 + w * 1.3) / 2, y: deck - s * 0.1))
        ctx.stroke(cable, with: .color(red), lineWidth: 2)
    }

    private func opera(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, lit: Bool) {
        let shell = lit ? Color(red: 0.98, green: 0.88, blue: 0.70) : Color(red: 0.95, green: 0.94, blue: 0.90)
        ctx.fill(Path(CGRect(x: x - s * 0.2, y: g - s * 0.15, width: s * 2.2, height: s * 0.15)), with: .color(Color(red: 0.55, green: 0.45, blue: 0.38)))
        for (i, scale) in [1.0, 0.85, 0.7, 0.55].enumerated() {
            let sx = x + CGFloat(i) * s * 0.45
            var p = Path()
            p.move(to: CGPoint(x: sx, y: g - s * 0.15))
            p.addQuadCurve(to: CGPoint(x: sx + s * 0.55 * scale, y: g - s * 0.15 - s * scale), control: CGPoint(x: sx + s * 0.05, y: g - s * scale))
            p.addQuadCurve(to: CGPoint(x: sx + s * 0.6 * scale, y: g - s * 0.15), control: CGPoint(x: sx + s * 0.62 * scale, y: g - s * 0.6 * scale))
            p.closeSubpath()
            ctx.fill(p, with: .color(shell))
        }
    }

    private func harbourBridge(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        var arch = Path()
        arch.move(to: CGPoint(x: x - s * 1.2, y: g))
        arch.addQuadCurve(to: CGPoint(x: x + s * 1.2, y: g), control: CGPoint(x: x, y: g - s * 1.6))
        ctx.stroke(arch, with: .color(color), lineWidth: 4)
        ctx.fill(Path(CGRect(x: x - s * 1.4, y: g - s * 0.35, width: s * 2.8, height: s * 0.07)), with: .color(color))
    }

    private func burj(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color, lit: Bool) {
        let steps: [(CGFloat, CGFloat)] = [(0.13, 0.35), (0.10, 0.55), (0.07, 0.72), (0.045, 0.84), (0.025, 0.92)]
        for (wid, top) in steps {
            ctx.fill(Path(CGRect(x: x - s * wid / 2, y: g - s * top, width: s * wid, height: s * top)), with: .color(color))
        }
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.92)); $0.addLine(to: CGPoint(x: x, y: g - s)) }, with: .color(color), lineWidth: 1.5)
        if lit {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: g - s - 2, width: 4, height: 4)), with: .color(Color(red: 1, green: 0.4, blue: 0.3)))
        }
    }

    private func palace(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        let steps: [(CGFloat, CGFloat)] = [(0.55, 0.22), (0.32, 0.42), (0.22, 0.6), (0.14, 0.74), (0.08, 0.84)]
        for (wid, top) in steps {
            ctx.fill(Path(CGRect(x: x - s * wid / 2, y: g - s * top, width: s * wid, height: s * top)), with: .color(color))
        }
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.84)); $0.addLine(to: CGPoint(x: x, y: g - s)) }, with: .color(color), lineWidth: 2)
    }

    private func domes(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color) {
        let gold = Color(red: 0.89, green: 0.70, blue: 0.24)
        ctx.fill(Path(CGRect(x: x - s * 0.1, y: g - s * 0.45, width: s * 1.6, height: s * 0.45)), with: .color(Color(white: 0.92)))
        for (i, hgt) in [0.75, 1.0, 0.75].enumerated() {
            let cx = x + s * 0.12 + CGFloat(i) * s * 0.55
            let base = g - s * 0.45
            ctx.fill(Path(CGRect(x: cx - s * 0.1, y: base - s * 0.22 * hgt, width: s * 0.2, height: s * 0.22 * hgt)), with: .color(Color(white: 0.92)))
            var dome = Path()
            let top = base - s * 0.22 * hgt
            dome.move(to: CGPoint(x: cx - s * 0.13, y: top))
            dome.addQuadCurve(to: CGPoint(x: cx, y: top - s * 0.32 * hgt), control: CGPoint(x: cx - s * 0.2, y: top - s * 0.22 * hgt))
            dome.addQuadCurve(to: CGPoint(x: cx + s * 0.13, y: top), control: CGPoint(x: cx + s * 0.2, y: top - s * 0.22 * hgt))
            dome.closeSubpath()
            ctx.fill(dome, with: .color(gold))
            ctx.stroke(Path { $0.move(to: CGPoint(x: cx, y: top - s * 0.32 * hgt)); $0.addLine(to: CGPoint(x: cx, y: top - s * 0.44 * hgt)) },
                       with: .color(gold), lineWidth: 2)
        }
    }

    private func tvTower(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, color: Color, lit: Bool) {
        ctx.fill(Path(CGRect(x: x - s * 0.025, y: g - s * 0.66, width: s * 0.05, height: s * 0.66)), with: .color(color))
        ctx.fill(Path(ellipseIn: CGRect(x: x - s * 0.08, y: g - s * 0.74, width: s * 0.16, height: s * 0.16)), with: .color(lit ? Color(white: 0.75) : Color(white: 0.85)))
        ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: g - s * 0.74)); $0.addLine(to: CGPoint(x: x, y: g - s)) }, with: .color(color), lineWidth: 2.5)
    }

    private func colosseum(_ ctx: inout GraphicsContext, x: CGFloat, ground g: CGFloat, size s: CGFloat, width: CGFloat, color: Color) {
        let stone = Color(red: 0.80, green: 0.66, blue: 0.48)
        var body = Path()
        body.move(to: CGPoint(x: x, y: g))
        body.addLine(to: CGPoint(x: x, y: g - s * 0.75))
        body.addQuadCurve(to: CGPoint(x: x + width, y: g - s), control: CGPoint(x: x + width * 0.5, y: g - s * 0.95))
        body.addLine(to: CGPoint(x: x + width, y: g))
        body.closeSubpath()
        ctx.fill(body, with: .color(stone))
        for row in 0..<3 {
            let y = g - s * (0.2 + CGFloat(row) * 0.25)
            var ax = x + 4
            while ax < x + width - 8 {
                ctx.fill(Path(roundedRect: CGRect(x: ax, y: y - s * 0.14, width: 6, height: s * 0.14), cornerRadius: 3), with: .color(color.opacity(0.8)))
                ax += 11
            }
        }
    }
}

/// The window on the wall: a city panorama in a wooden frame, its name and local time,
/// and a swipe to pan to the next city.
struct CityWindow: View {
    var store: TimeOSStore
    @State private var pan: CGFloat = 0
    @State private var width: CGFloat = 300

    private var cities: [TempoWorldCity] {
        store.worldCities.isEmpty
            ? [TempoWorldCity(cityName: TimeZone.current.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? "Here",
                              timeZoneIdentifier: TimeZone.current.identifier)]
            : store.worldCities
    }

    private var city: TempoWorldCity {
        cities.first { $0.id == store.focusedCityID } ?? cities[0]
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let c = city.localComponents(at: context.date)
            let hour = Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60
            let night = CityLight(hour: hour).night
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    CityPanorama(
                        name: city.cityName,
                        landmark: CityLandmark.forCity(name: city.cityName, timeZone: city.timeZoneIdentifier),
                        hour: hour,
                        pan: pan
                    )
                    .opacity(1 - min(0.65, abs(pan) / max(1, geo.size.width)))

                    // City name and its time, painted on the glass.
                    VStack(alignment: .leading, spacing: 0) {
                        Text(city.cityName.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                        Text(city.formattedLocalTime(at: context.date))
                            .font(.tempoNumerals(34))
                    }
                    .foregroundStyle(night > 0.45 ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.1))
                    .shadow(color: Color.black.opacity(night > 0.45 ? 0.4 : 0), radius: 3)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .offset(x: pan * 0.4)
                    .opacity(1 - min(1, abs(pan) / max(1, geo.size.width) * 1.6))

                    if cities.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(cities) { item in
                                Circle()
                                    .fill(Color.white.opacity(item.id == city.id ? 0.95 : 0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                    }
                }
                .onAppear { width = geo.size.width }
                .onChange(of: geo.size.width) { _, new in width = new }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        // Window frame and sill, in the desk's wood.
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(DeskPalette.edge, lineWidth: 7))
        .shadow(color: Color.black.opacity(0.18), radius: 8, y: 4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    let atEnd = (value.translation.width < 0 && index == cities.count - 1) || (value.translation.width > 0 && index == 0)
                    pan = atEnd ? value.translation.width * 0.25 : value.translation.width
                }
                .onEnded { value in
                    let dir = value.predictedEndTranslation.width < -width * 0.3 ? 1 : (value.predictedEndTranslation.width > width * 0.3 ? -1 : 0)
                    move(dir)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Swipe to see another city")
    }

    private var index: Int { cities.firstIndex { $0.id == city.id } ?? 0 }

    /// Slide the old city out, swap, slide the new one in from the other side.
    private func move(_ dir: Int) {
        let target = index + dir
        guard dir != 0, cities.indices.contains(target) else {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { pan = 0 }
            return
        }
        withAnimation(.easeIn(duration: 0.16)) { pan = -CGFloat(dir) * width }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            store.focusCity(cities[target])
            pan = CGFloat(dir) * width
            withAnimation(.spring(duration: 0.5, bounce: 0.12)) { pan = 0 }
        }
    }
}
