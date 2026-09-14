import SwiftUI

struct SharedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                let lightColors: [Color] = [
                    Color(white: 0.95), Color(red: 0.92, green: 0.95, blue: 0.98), Color(white: 0.95),
                    Color(red: 0.95, green: 0.92, blue: 0.96), Color(white: 0.98), Color(red: 0.92, green: 0.98, blue: 0.95),
                    Color(white: 0.95), Color(red: 0.9, green: 0.95, blue: 0.98), Color(white: 0.95)
                ]
                let darkColors: [Color] = [
                    Color(white: 0.1), Color(red: 0.05, green: 0.1, blue: 0.15), Color(white: 0.1),
                    Color(red: 0.1, green: 0.05, blue: 0.1), Color(white: 0.05), Color(red: 0.05, green: 0.15, blue: 0.1),
                    Color(white: 0.1), Color(red: 0.05, green: 0.1, blue: 0.15), Color(white: 0.1)
                ]
                
                TimelineView(.animation) { timeline in
                    let time = Float(timeline.date.timeIntervalSinceReferenceDate * 0.4)
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                            [0.0, 0.5 + sin(time) * 0.05], [0.5, 0.5 + cos(time) * 0.05], [1.0, 0.5 - sin(time) * 0.05],
                            [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                        ],
                        colors: colorScheme == .dark ? darkColors : lightColors
                    )
                }
            } else {
                Color(UIColor.systemBackground)
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
                ? [.white.opacity(0.3), .white.opacity(0.05), .white.opacity(0.1)]
                : [.white.opacity(0.8), .white.opacity(0.1), .white.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
