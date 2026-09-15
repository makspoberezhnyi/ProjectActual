import SwiftUI

// MARK: - DYNAMIC MESH GRADIENT & GRAIN BACKGROUND
struct SharedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate * 0.25
            
            ZStack {
                // 1. Native Animated Mesh Gradient
                meshGradientView(time: time)
                
                // 2. Procedural Tactile Film Grain Overlay
                GrainNoiseOverlay(intensity: colorScheme == .dark ? 0.032 : 0.018)
                    .blendMode(colorScheme == .dark ? .plusLighter : .multiply)
            }
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func meshGradientView(time: Double) -> some View {
        if #available(iOS 18.0, *) {
            let t = Float(time)
            let p1x: Float = 0.5 + sin(t * 0.7) * 0.08
            let p1y: Float = 0.0 + max(0.0, cos(t * 0.5) * 0.04)
            let p4x: Float = 0.5 + cos(t * 0.6) * 0.08
            let p4y: Float = 0.5 + sin(t * 0.8) * 0.08
            let p7x: Float = 0.5 - sin(t * 0.9) * 0.08
            let p7y: Float = 1.0 - max(0.0, cos(t * 0.4) * 0.04)
            
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [p1x, p1y], [1.0, 0.0],
                    [0.0, 0.5], [p4x, p4y], [1.0, 0.5],
                    [0.0, 1.0], [p7x, p7y], [1.0, 1.0]
                ],
                colors: meshColors
            )
        } else {
            fallbackGradient
        }
    }
    
    private var meshColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.04, green: 0.05, blue: 0.09),
                Color(red: 0.06, green: 0.12, blue: 0.22),
                Color(red: 0.04, green: 0.06, blue: 0.11),
                
                Color(red: 0.05, green: 0.07, blue: 0.14),
                Color(red: 0.07, green: 0.16, blue: 0.28),
                Color(red: 0.05, green: 0.08, blue: 0.16),
                
                Color(red: 0.03, green: 0.04, blue: 0.08),
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.04, green: 0.05, blue: 0.09)
            ]
        } else {
            return [
                Color(red: 0.96, green: 0.97, blue: 0.99),
                Color(red: 0.91, green: 0.94, blue: 0.98),
                Color(red: 0.95, green: 0.96, blue: 0.98),
                
                Color(red: 0.93, green: 0.95, blue: 0.97),
                Color(red: 0.89, green: 0.93, blue: 0.98),
                Color(red: 0.94, green: 0.95, blue: 0.97),
                
                Color(red: 0.95, green: 0.96, blue: 0.98),
                Color(red: 0.92, green: 0.94, blue: 0.97),
                Color(red: 0.96, green: 0.97, blue: 0.99)
            ]
        }
    }
    
    private var fallbackGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.05, green: 0.06, blue: 0.09), Color(red: 0.07, green: 0.11, blue: 0.18)]
                : [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.92, green: 0.94, blue: 0.97)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - PROCEDURAL TACTILE GRAIN NOISE OVERLAY
struct GrainNoiseOverlay: View {
    var intensity: Double = 0.03
    
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard w > 0, h > 0 else { return }
            
            let step: CGFloat = 4.0
            var x: CGFloat = 0
            while x < w {
                var y: CGFloat = 0
                while y < h {
                    let pseudoRandom = sin(x * 12.9898 + y * 78.233).truncatingRemainder(dividingBy: 1.0)
                    if abs(pseudoRandom) > 0.4 {
                        let dotRect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                        context.fill(Path(dotRect), with: .color(Color.white.opacity(intensity * abs(pseudoRandom))))
                    }
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - LIQUID METAL & LIQUID GLASS CARDS
struct LiquidMetalGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 20
    var isProminent: Bool = false
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Refractive Glass Base
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color(red: 0.10, green: 0.12, blue: 0.17).opacity(0.85)
                                : Color(red: 0.97, green: 0.98, blue: 1.0).opacity(0.88)
                        )
                    
                    // Liquid Metal Specular Sheen Gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [
                                        Color.white.opacity(0.08),
                                        Color.blue.opacity(0.06),
                                        Color.clear,
                                        Color.white.opacity(0.03)
                                    ]
                                    : [
                                        Color.white.opacity(0.6),
                                        Color.blue.opacity(0.04),
                                        Color.clear,
                                        Color.white.opacity(0.3)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                // Specular Metallic Rim
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [
                                    Color.white.opacity(0.32),
                                    Color.white.opacity(0.06),
                                    Color.blue.opacity(0.28),
                                    Color.white.opacity(0.14)
                                ]
                                : [
                                    Color.white.opacity(0.85),
                                    Color.white.opacity(0.25),
                                    Color.blue.opacity(0.20),
                                    Color.white.opacity(0.60)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: isProminent 
                    ? Color.blue.opacity(colorScheme == .dark ? 0.32 : 0.18) 
                    : Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                radius: isProminent ? 16 : 10,
                x: 0,
                y: isProminent ? 6 : 4
            )
    }
}

extension View {
    func liquidMetalGlass(cornerRadius: CGFloat = 20, isProminent: Bool = false) -> some View {
        self.modifier(LiquidMetalGlassModifier(cornerRadius: cornerRadius, isProminent: isProminent))
    }
}

// MARK: - Glassmorphism Constants
struct GlassStyles {
    static func borderGradient(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark 
                ? [Color.white.opacity(0.22), Color.white.opacity(0.04), Color.blue.opacity(0.20), Color.white.opacity(0.10)]
                : [Color.white.opacity(0.85), Color.black.opacity(0.02), Color.blue.opacity(0.15), Color.white.opacity(0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
