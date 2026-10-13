import SwiftUI

// MARK: - Bubble shape

/// Rounded bubble with a small tail pointing at the mascot (above it, or to its left).
struct SpeechBubbleShape: Shape {
    enum Tail { case top, leading }

    static let tailHeight: CGFloat = 8
    var tail: Tail = .top
    private let radius: CGFloat = 18
    private let tailWidth: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let t = Self.tailHeight
        let body = tail == .top
            ? CGRect(x: rect.minX, y: rect.minY + t, width: rect.width, height: rect.height - t)
            : CGRect(x: rect.minX + t, y: rect.minY, width: rect.width - t, height: rect.height)
        let r = min(radius, body.height / 2, body.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        if tail == .top {
            p.addLine(to: CGPoint(x: rect.midX - tailWidth / 2, y: body.minY))
            p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.midX - 3, y: body.minY))
            p.addQuadCurve(to: CGPoint(x: rect.midX + tailWidth / 2, y: body.minY), control: CGPoint(x: rect.midX + 3, y: body.minY))
        }
        p.addLine(to: CGPoint(x: body.maxX - r, y: body.minY))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + r), radius: r)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - r))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - r, y: body.maxY), radius: r)
        p.addLine(to: CGPoint(x: body.minX + r, y: body.maxY))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - r), radius: r)
        if tail == .leading {
            let tipY = min(body.maxY - r - tailWidth / 2, max(body.minY + r + tailWidth / 2, body.midY))
            p.addLine(to: CGPoint(x: body.minX, y: tipY + tailWidth / 2))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: tipY), control: CGPoint(x: body.minX, y: tipY + 3))
            p.addQuadCurve(to: CGPoint(x: body.minX, y: tipY - tailWidth / 2), control: CGPoint(x: body.minX, y: tipY - 3))
        }
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + r))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + r, y: body.minY), radius: r)
        p.closeSubpath()
        return p
    }
}

// MARK: - Talking text

/// Shows a quick "typing" beat before each new line, so the mascot feels like it's answering you.
struct MascotSpeechText: View {
    let text: String
    var alignment: TextAlignment = .center

    @State private var shown = ""
    @State private var typing = false

    var body: some View {
        ZStack {
            if typing {
                MascotTypingDots()
                    .transition(.opacity)
            } else {
                Text(shown)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.tempoInk.opacity(0.88))
                    .multilineTextAlignment(alignment)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(minHeight: 20)
        .task(id: text) {
            // First appearance: no typing beat, just say it.
            guard !shown.isEmpty else {
                shown = text
                return
            }
            guard shown != text else { return }
            withAnimation(.easeOut(duration: 0.15)) { typing = true }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                shown = text
                typing = false
            }
        }
        .accessibilityElement()
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Three bouncing dots, iMessage style.
struct MascotTypingDots: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.tempoMuted)
                    .frame(width: 7, height: 7)
                    .offset(y: phase ? -3 : 3)
                    .animation(
                        .easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(Double(i) * 0.13),
                        value: phase
                    )
            }
        }
        .frame(height: 20)
        .onAppear { phase = true }
        .accessibilityHidden(true)
    }
}

// MARK: - Bubble

/// The mascot's chat bubble. Reads `TimeOSStore.mascotVoiceMessage` on every screen, so there is one voice.
struct MascotSpeechBubble: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var tail: SpeechBubbleShape.Tail = .top

    var body: some View {
        MascotSpeechText(text: text, alignment: tail == .top ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: tail == .top ? .center : .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .padding(tail == .top ? .top : .leading, SpeechBubbleShape.tailHeight)
            .background(
                SpeechBubbleShape(tail: tail)
                    .fill(TempoSurface.card(colorScheme))
                    .overlay(SpeechBubbleShape(tail: tail).stroke(TempoSurface.border(colorScheme), lineWidth: 1))
            )
    }
}

/// Mini mascot with its bubble to the right, for screens that are mostly lists.
struct MascotChatHeader: View {
    let regime: TempoMascotRegime
    let text: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            TempoInteractiveMascotView(
                size: 66,
                onBodyTap: onTap,
                live: { _ in TempoMascotLive(regime: regime) }
            )
            .frame(width: 70, height: 70)
            MascotSpeechBubble(text: text, tail: .leading)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Bubbles") {
    VStack(spacing: 24) {
        MascotSpeechBubble(text: "Morning! What's on your plate today?")
        MascotChatHeader(regime: .worldLocalDay, text: "It's 3:12 AM in Tokyo. They're probably asleep.")
    }
    .padding()
}
