import SwiftUI

// MARK: - 5. INTERACTIVE 24-REGIME MASCOT STUDIO SHEET

public struct MascotRegimeStudioView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: TimeOSStore
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    TempoInteractiveMascotView(
                        regime: store.selectedStudioRegime,
                        size: 196
                    )
                    
                    Text(store.selectedStudioRegime.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(TempoSurface.ink(colorScheme))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .moodyGlassCard(cornerRadius: 28, isProminent: true)
                .padding(.horizontal, 20)
                
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(TempoMascotRegime.allCases) { regime in
                        let isSelected = store.selectedStudioRegime == regime
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                store.selectedStudioRegime = regime
                            }
                            TactileFeedback.selection()
                        } label: {
                            VStack(spacing: 6) {
                                TempoWatchMascotView(regime: regime, size: 78, animated: isSelected)
                                Text(regime.title)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(TempoSurface.ink(colorScheme))
                                    .lineLimit(1)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(TempoSurface.card(colorScheme))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                isSelected ? TempoMascotPalette.orange : TempoSurface.border(colorScheme),
                                                lineWidth: isSelected ? 2 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.top, 12)
        }
    }
}
