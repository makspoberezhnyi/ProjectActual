import SwiftUI

public enum Theme {
    public static let text = Color.primary
    public static let textDim = Color.secondary
    
    public static let auraCalibrated = Color(hex: 0x2A3E59)
    public static let auraUncalibrated = Color(hex: 0x8C3A3A)
    public static let auraLearning = Color(hex: 0x4A4A4A)
    
    // Unified Apple Design Palette
    public static let brandPrimary = Color(red: 0.05, green: 0.52, blue: 1.0)
    public static let brandCoral = Color(red: 1.0, green: 0.4, blue: 0.3)
    public static let brandSuccess = Color(red: 0.2, green: 0.78, blue: 0.35)
    public static let brandMint = Color(red: 0.05, green: 0.52, blue: 1.0) // Harmonized to Apple Blue
    public static let brandBackground = Color(UIColor.systemGroupedBackground)
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

// MARK: - Motion System (transitions.dev & transitions-polish)

public enum AppMotion {
    // Durations
    public static let stagger: Double = 0.04    // 40ms per-item stagger
    public static let micro: Double = 0.08      // 80ms micro-interaction / intent delay
    public static let quick: Double = 0.15      // 150ms modal/dropdown close, text swap
    public static let fast: Double = 0.25       // 250ms modal/dropdown open, tabs sliding
    public static let medium: Double = 0.35     // 350ms panel close, card transitions
    public static let slow: Double = 0.40       // 400ms panel open, skeleton reveal
    public static let verySlow: Double = 0.50   // 500ms emphasis / celebration
    
    // Springs & Easings
    public static let smoothOut = Animation.spring(response: 0.35, dampingFraction: 0.82)
    public static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.75)
    public static let pop = Animation.spring(response: 0.30, dampingFraction: 0.60)
    public static let bounce = Animation.spring(response: 0.38, dampingFraction: 0.65)
    public static let exit = Animation.easeOut(duration: quick)
    public static let linear = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
    
    // Scale & Distance Tokens
    public static let scaleCard: CGFloat = 0.96
    public static let scaleSmall: CGFloat = 0.98
    public static let distanceMicro: CGFloat = 4
    public static let distanceBase: CGFloat = 8
    public static let distanceMedium: CGFloat = 12
    
    // iMessage-Style Spring Physics (high frame rate, fluid ProMotion)
    public static let messageFly = Animation.spring(response: 0.32, dampingFraction: 0.74)
    public static let messageAIPop = Animation.spring(response: 0.30, dampingFraction: 0.78)
    public static let messageScroll = Animation.spring(response: 0.32, dampingFraction: 0.82)
}

// MARK: - iMessage-Style Fluid Transitions (swiftui-animation)

@MainActor
public extension AnyTransition {
    static var iMessageUserFly: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.82, anchor: .bottomTrailing)
                .combined(with: .offset(y: 18))
                .combined(with: .opacity)
                .animation(AppMotion.messageFly),
            removal: .scale(scale: 0.85)
                .combined(with: .opacity)
                .animation(.easeOut(duration: AppMotion.quick))
        )
    }
    
    static var iMessageAIPop: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.82, anchor: .bottomLeading)
                .combined(with: .offset(y: 14))
                .combined(with: .opacity)
                .animation(AppMotion.messageAIPop),
            removal: .scale(scale: 0.85)
                .combined(with: .opacity)
                .animation(.easeOut(duration: AppMotion.quick))
        )
    }
}

// MARK: - Tactile Press Button Style (transitions.dev scale & spring return)
public struct PressableScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = AppMotion.scaleCard
    
    public init(scale: CGFloat = AppMotion.scaleCard) {
        self.scale = scale
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(AppMotion.snappy, value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == PressableScaleButtonStyle {
    static var pressable: PressableScaleButtonStyle {
        PressableScaleButtonStyle()
    }
    static func pressable(scale: CGFloat) -> PressableScaleButtonStyle {
        PressableScaleButtonStyle(scale: scale)
    }
}

// MARK: - Shimmer Text & Thinking States (15-shimmer-text & 28-thinking-states)
public struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1.0
    var isActive: Bool = true
    
    public func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                Color.white.opacity(0.4),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 1.5)
                        .offset(x: phase * geo.size.width * 1.5)
                    }
                    .mask(content)
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                        phase = 1.0
                    }
                }
        } else {
            content
        }
    }
}

public extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
    
    func pressable(scale: CGFloat = AppMotion.scaleCard) -> some View {
        buttonStyle(PressableScaleButtonStyle(scale: scale))
    }
}

// MARK: - Error Shake Modifier (12-error-state-shake)
public struct ShakeEffect: GeometryEffect {
    public var amount: CGFloat = 8
    public var shakesPerUnit: CGFloat = 3
    public var animatableData: CGFloat

    public init(shakes: CGFloat, amount: CGFloat = 8) {
        self.animatableData = shakes
        self.amount = amount
    }

    public func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amount * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

public extension View {
    func shake(trigger: CGFloat, amount: CGFloat = 8) -> some View {
        modifier(ShakeEffect(shakes: trigger, amount: amount))
    }
}

// MARK: - Staggered Typing Dots using PhaseAnimator (iOS 17+ swiftui-animation)
public struct TypingDotsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                PhaseAnimator([0.0, 1.0, 0.0]) { phase in
                    Circle()
                        .frame(width: 6, height: 6)
                        .scaleEffect(reduceMotion ? 1.0 : (1.0 + phase * 0.35))
                        .opacity(reduceMotion ? 0.8 : (0.4 + phase * 0.5))
                } animation: { _ in
                    .easeInOut(duration: 0.5).delay(Double(index) * 0.16)
                }
            }
        }
        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.5))
    }
}

// MARK: - Performance Formatters (swiftui-performance)
public enum TempoFormatters {
    public static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
    
    public static let dayJumpFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()
    
    public static let calendarDayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    public static let calendarMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
    
    public static let backupFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter
    }()
}



