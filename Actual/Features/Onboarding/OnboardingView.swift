import SwiftUI

/// The quiet opening: a mark, then the tagline. Two screens, no carousel, no feature
/// tour. The product's argument is made in one line.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var stage: Stage = .mark

    private enum Stage { case mark, tagline }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            switch stage {
            case .mark:
                markScreen
                    .transition(.opacity)
            case .tagline:
                taglineScreen
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeInOut(duration: 0.6)) { stage = .tagline }
        }
    }

    // MARK: - 01, the mark

    private var markScreen: some View {
        VStack {
            Spacer()
            ActualMark()
                .frame(width: 30, height: 30)
            Spacer()
            Text("Actual")
                .font(Typeface.body(15))
                .tracking(0.3)
                .foregroundStyle(Theme.inkFaint)
                .padding(.bottom, 90)
        }
    }

    // MARK: - 02, the tagline

    private var taglineScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Know your\ntime.")
                .font(Typeface.title(38))
                .tracking(-0.38)
                .lineSpacing(4)
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 40)
            Spacer()

            VStack(spacing: 14) {
                PrimaryButton(title: "Continue with email", height: 54, action: onFinish)

                Text("By continuing, you agree to our ")
                    .foregroundStyle(Theme.inkFaint)
                + Text("Terms").foregroundStyle(Theme.inkSoft)
                + Text(" and ").foregroundStyle(Theme.inkFaint)
                + Text("Privacy Policy").foregroundStyle(Theme.inkSoft)
            }
            .font(Typeface.body(12))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The app mark: a ring with a single stroke at twelve, a clock reduced to the one
/// gesture that still reads as one.
struct ActualMark: View {
    var lineWidth: CGFloat = 1.8

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let scale = side / 30

            ZStack {
                Circle()
                    .strokeBorder(Theme.ink, lineWidth: lineWidth)
                    .frame(width: 26 * scale, height: 26 * scale)

                Path { path in
                    path.move(to: CGPoint(x: side / 2, y: 10 * scale))
                    path.addLine(to: CGPoint(x: side / 2, y: 6 * scale))
                }
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            .frame(width: side, height: side)
        }
    }
}
