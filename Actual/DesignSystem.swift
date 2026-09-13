import SwiftUI

public enum Theme {
    public static let text = Color.white
    public static let textDim = Color.white.opacity(0.6)
    
    public static let auraCalibrated = Color(hex: 0x2A3E59)
    public static let auraUncalibrated = Color(hex: 0x8C3A3A)
    public static let auraLearning = Color(hex: 0x4A4A4A)
    
    // New Brand Colors
    public static let brandCoral = Color(red: 1.0, green: 0.4, blue: 0.3)
    public static let brandMint = Color(red: 0.3, green: 0.9, blue: 0.6)
    public static let brandBackground = Color(red: 0.96, green: 0.95, blue: 0.93) // Very soft off-white/cream
}

extension Color {
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

public struct LiquidEnvironment: View {
    var calibrationScore: Double

    public init(calibrationScore: Double) {
        self.calibrationScore = calibrationScore
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let speed = 1.0 - (calibrationScore * 0.7)
            let angle1 = now * 0.02 * speed
            let angle2 = now * 0.03 * speed
            
            let baseColor = calibrationScore > 0.8 ? Theme.auraCalibrated : 
                            (calibrationScore < 0.4 ? Theme.auraUncalibrated : Theme.auraLearning)

            ZStack {
                Color.black.ignoresSafeArea()
                
                AngularGradient(
                    colors: [baseColor, .clear, baseColor.opacity(0.5), .clear, baseColor],
                    center: .center,
                    angle: .degrees(angle1 * 30)
                )
                .opacity(0.6)
                .blur(radius: 60)
                
                RadialGradient(
                    colors: [baseColor.opacity(0.8), .clear],
                    center: UnitPoint(x: 0.5 + sin(angle2)*0.3, y: 0.5 + cos(angle2)*0.3),
                    startRadius: 0,
                    endRadius: 400
                )
                .blur(radius: 40)
            }
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2.0), value: calibrationScore)
        }
    }
}

public struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    public var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    }
            }
    }
}
