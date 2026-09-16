//
//  SharedBackground.swift
//  Actual
//
//  Metal Shader UI System:
//  - Metal-powered Mesh Gradient & Grain Canvas
//  - Moody Frosted Glass Card & Tactile Chip Modifiers (matching Shader Studio style)
//

import SwiftUI

// MARK: - Metal-Powered Mesh Gradient Background
struct SharedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        ZStack {
            // Base background
            if colorScheme == .dark {
                Color(red: 0.03, green: 0.04, blue: 0.06).ignoresSafeArea()
            } else {
                Color(red: 0.86, green: 0.89, blue: 0.94).ignoresSafeArea()
            }
            
            // Metal Shader Mesh Gradient Canvas
            if !reduceMotion {
                let c0 = color0
                let c1 = color1
                let c2 = color2
                let c3 = color3
                let c4 = color4
                let c5 = color5
                
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    let time = Float(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000.0))
                    
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.black : Color(red: 0.84, green: 0.87, blue: 0.92))
                        .visualEffect { content, proxy in
                            content.colorEffect(
                                ShaderLibrary.meshGradientShader(
                                    .float2(proxy.size),
                                    .float(time * 0.35),
                                    .float(0.85), // distortion
                                    .float(0.60), // swirl
                                    .float(0.30), // grainMixer
                                    .float(0.18), // grainOverlay
                                    .color(c0),
                                    .color(c1),
                                    .color(c2),
                                    .color(c3),
                                    .color(c4),
                                    .color(c5)
                                )
                            )
                        }
                        .opacity(colorScheme == .dark ? 0.95 : 0.90)
                        .ignoresSafeArea()
                }
            } else {
                // Static elegant gradient when Reduce Motion is enabled
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.05, green: 0.08, blue: 0.14), Color(red: 0.08, green: 0.06, blue: 0.16)]
                        : [Color(red: 0.82, green: 0.87, blue: 0.94), Color(red: 0.76, green: 0.80, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Vibrant Harmonic Mesh Color Palettes
    private var color0: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.18, blue: 0.42) // Deep electric sapphire
            : Color(red: 0.52, green: 0.70, blue: 0.94)  // Vibrant Sky Azure
    }
    
    private var color1: Color {
        colorScheme == .dark
            ? Color(red: 0.14, green: 0.10, blue: 0.40) // Cosmic indigo
            : Color(red: 0.65, green: 0.60, blue: 0.92)  // Soft Royal Lavender
    }
    
    private var color2: Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.22, blue: 0.32) // Dark cyan slate
            : Color(red: 0.42, green: 0.76, blue: 0.84)  // Fresh Cyan Teal
    }
    
    private var color3: Color {
        colorScheme == .dark
            ? Color(red: 0.03, green: 0.05, blue: 0.12) // Midnight abyssal
            : Color(red: 0.82, green: 0.85, blue: 0.92)  // Cool Slate Mist
    }
    
    private var color4: Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.12, blue: 0.28) // Deep twilight blue
            : Color(red: 0.58, green: 0.72, blue: 0.92)  // Deep Ocean Azure
    }
    
    private var color5: Color {
        colorScheme == .dark
            ? Color(red: 0.04, green: 0.06, blue: 0.10) // Obsidian base
            : Color(red: 0.78, green: 0.82, blue: 0.88)  // Platinum Steel Base
    }
}

// MARK: - Moody Frosted Glass Card Modifier (Shader Studio Aesthetic)
struct MoodyGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var isProminent: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Deep moody slate-cyan frosted base (matching rgba(15, 23, 42, 0.75))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color(red: 0.06, green: 0.09, blue: 0.165).opacity(0.82)
                                : Color(red: 0.94, green: 0.96, blue: 0.99).opacity(0.88)
                        )
                    
                    // Subtle specular gradient sheen
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.cyan.opacity(0.08), Color.blue.opacity(0.04), Color.clear]
                                    : [Color.white.opacity(0.60), Color.blue.opacity(0.03), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color.white.opacity(0.28), Color.cyan.opacity(0.22), Color.white.opacity(0.08)]
                                : [Color.white.opacity(0.95), Color.blue.opacity(0.20), Color.white.opacity(0.40)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08),
                radius: isProminent ? 24 : 16,
                x: 0,
                y: isProminent ? 10 : 6
            )
    }
}

// MARK: - Tactile Frosted Glass Chip Modifier
struct MoodyGlassChipModifier: ViewModifier {
    var isProminent: Bool = false
    
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if isProminent {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.52, blue: 0.98), Color(red: 0.02, green: 0.38, blue: 0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    ZStack {
                        Capsule()
                            .fill(
                                colorScheme == .dark
                                    ? Color(red: 0.09, green: 0.13, blue: 0.22).opacity(0.85)
                                    : Color(red: 0.93, green: 0.95, blue: 0.98).opacity(0.92)
                            )
                    }
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isProminent
                            ? LinearGradient(colors: [Color.white.opacity(0.45), Color.cyan.opacity(0.60)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: colorScheme == .dark
                                    ? [Color.white.opacity(0.24), Color.cyan.opacity(0.18), Color.white.opacity(0.06)]
                                    : [Color.white.opacity(0.90), Color.blue.opacity(0.18), Color.white.opacity(0.40)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: isProminent ? Color.blue.opacity(0.35) : Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
                radius: isProminent ? 8 : 4,
                y: isProminent ? 2 : 1
            )
    }
}

// MARK: - View Extension Helpers
extension View {
    func moodyGlassCard(cornerRadius: CGFloat = 24, isProminent: Bool = false) -> some View {
        modifier(MoodyGlassCardModifier(cornerRadius: cornerRadius, isProminent: isProminent))
    }
    
    func moodyGlassChip(isProminent: Bool = false) -> some View {
        modifier(MoodyGlassChipModifier(isProminent: isProminent))
    }
    
    // Backwards compatibility alias
    func liquidMetalCard(cornerRadius: CGFloat = 24, isProminent: Bool = false) -> some View {
        modifier(MoodyGlassCardModifier(cornerRadius: cornerRadius, isProminent: isProminent))
    }
    
    func liquidMetalChip(isProminent: Bool = false) -> some View {
        modifier(MoodyGlassChipModifier(isProminent: isProminent))
    }
}

// MARK: - Glassmorphism Constants
struct GlassStyles {
    static func borderGradient(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark 
                ? [Color.white.opacity(0.28), Color.cyan.opacity(0.18), Color.white.opacity(0.08)]
                : [Color.white.opacity(0.85), Color.blue.opacity(0.15), Color.white.opacity(0.40)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
