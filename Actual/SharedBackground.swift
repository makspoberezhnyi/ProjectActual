import SwiftUI

struct SharedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if colorScheme == .dark {
                // Sleek deep obsidian background with subtle dark slate depth
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.06, blue: 0.08),
                        Color(red: 0.08, green: 0.09, blue: 0.12),
                        Color(red: 0.05, green: 0.06, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Crisp, elegant Apple light background (clean neutral canvas)
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.965, blue: 0.98),
                        Color(red: 0.93, green: 0.94, blue: 0.96),
                        Color(red: 0.95, green: 0.955, blue: 0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glassmorphism Constants
struct GlassStyles {
    static func borderGradient(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark 
                ? [Color.white.opacity(0.18), Color.white.opacity(0.04), Color.white.opacity(0.08)]
                : [Color.black.opacity(0.08), Color.black.opacity(0.02), Color.black.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
