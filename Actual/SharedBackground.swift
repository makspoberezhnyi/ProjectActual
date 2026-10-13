//
//  SharedBackground.swift
//  Actual
//
//  Adaptive Tactile Horological Surface System:
//  - Light Mode: Warm Alabaster (#F6F4F0) background, Crisp White (#FFFFFF) cards, Carbon (#1A1A1A) ink
//  - Dark Mode: Deep Midnight (#11182B) background, Moody Midnight Blue (#1E2B4F) cards, Alabaster (#F6F4F0) ink
//

import SwiftUI

public enum TempoSurface {
    public static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.067, green: 0.094, blue: 0.169) // #11182B Deep Midnight Blue
            : TempoMascotPalette.alabaster                 // #F6F4F0 Warm Alabaster
    }
    
    public static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? TempoMascotPalette.moodyMidnightBlue         // #1E2B4F Moody Midnight Blue
            : Color.white                                  // #FFFFFF Crisp White
    }
    
    public static func cardElevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? TempoMascotPalette.moodyDuskBlue             // #283862 Moody Dusk Blue
            : TempoMascotPalette.alabaster                 // #F6F4F0 Subtle Recessed Alabaster
    }
    
    public static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? TempoMascotPalette.alabaster                 // #F6F4F0 Crisp Light Ink
            : TempoMascotPalette.carbon                    // #1A1A1A Matte Carbon Ink
    }
    
    public static func inkSecondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.68, green: 0.74, blue: 0.88)    // Soft Moonlight Slate
            : Color(red: 0.45, green: 0.44, blue: 0.41)    // Warm Braun Grey
    }
    
    public static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : TempoMascotPalette.carbon.opacity(0.08)
    }
}

// MARK: - Tactile Flat Horological Background (No Shaders)
struct SharedBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TempoSurface.background(colorScheme)
            .ignoresSafeArea()
    }
}

// MARK: - Tactile Horological Card Modifier
struct MoodyGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var isProminent: Bool = false

    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(TempoSurface.card(colorScheme))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        TempoSurface.border(colorScheme),
                        lineWidth: isProminent ? 1.5 : 1.0
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.04),
                radius: isProminent ? 14 : 8,
                x: 0,
                y: isProminent ? 5 : 3
            )
    }
}

// MARK: - Tactile Horological Chip Modifier
struct MoodyGlassChipModifier: ViewModifier {
    var isProminent: Bool = false

    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                if isProminent {
                    Capsule()
                        .fill(TempoMascotPalette.orange)
                } else {
                    Capsule()
                        .fill(TempoSurface.cardElevated(colorScheme))
                }
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isProminent ? TempoMascotPalette.orange : TempoSurface.border(colorScheme),
                        lineWidth: 1.0
                    )
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

    func liquidMetalCard(cornerRadius: CGFloat = 24, isProminent: Bool = false) -> some View {
        modifier(MoodyGlassCardModifier(cornerRadius: cornerRadius, isProminent: isProminent))
    }

    func liquidMetalChip(isProminent: Bool = false) -> some View {
        modifier(MoodyGlassChipModifier(isProminent: isProminent))
    }
}

// MARK: - Card Border Constants
struct GlassStyles {
    static func borderGradient(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [TempoSurface.border(colorScheme), TempoSurface.border(colorScheme)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
