import SwiftUI
import WatchKit

struct WatchRootView: View {
    @State private var store = WatchSessionStore.shared
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    
    @State private var showCustomSheet: Bool = false
    @State private var countdownTarget: (title: String, minutes: Int)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                if !isLuminanceReduced {
                    TempoWatchMeshBackground()
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
                
                if let target = countdownTarget {
                    FitnessCountdownView(
                        title: target.title,
                        minutes: target.minutes,
                        onComplete: {
                            let title = target.title
                            let mins = target.minutes
                            countdownTarget = nil
                            store.startSession(title: title, minutes: mins)
                        },
                        onCancel: {
                            countdownTarget = nil
                        }
                    )
                    .transition(.opacity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            if store.isRunning {
                                CompactRunningFocusView(store: store)
                            } else {
                                CompactIdleHomeView(
                                    store: store,
                                    onSelectPreset: { title, minutes in
                                        startWithCountdown(title: title, minutes: minutes)
                                    },
                                    onOpenCustom: {
                                        showCustomSheet = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.top, 2)
                        .padding(.bottom, 10)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle(isLuminanceReduced ? "" : "Tempo")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCustomSheet) {
                CustomFocusSheet { title, minutes in
                    showCustomSheet = false
                    startWithCountdown(title: title, minutes: minutes)
                }
            }
        }
        .onAppear {
            store.activate()
        }
    }
    
    private func startWithCountdown(title: String, minutes: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            countdownTarget = (title: title, minutes: minutes)
        }
    }
}

// MARK: - Ambient Watch Background
struct TempoWatchMeshBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.09)
            
            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.24, blue: 0.48).opacity(0.70),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 5,
                endRadius: 140
            )
            
            RadialGradient(
                colors: [
                    Color(red: 0.24, green: 0.10, blue: 0.40).opacity(0.55),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 130
            )
            
            RadialGradient(
                colors: [
                    Color(red: 0.05, green: 0.38, blue: 0.55).opacity(0.40),
                    Color.clear
                ],
                center: .center,
                startRadius: 1,
                endRadius: 100
            )
        }
    }
}

// MARK: - 3-2-1 Fitness Style Countdown View
struct FitnessCountdownView: View {
    let title: String
    let minutes: Int
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var count: Int = 3
    @State private var scale: CGFloat = 0.6
    @State private var ringTrim: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.2), lineWidth: 7)
                        .frame(width: 96, height: 96)
                    
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, Color(red: 0.2, green: 0.5, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                    
                    Text("\(count)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .scaleEffect(scale)
                }
                .padding(.vertical, 4)
                
                Text("Tap to skip")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            WKInterfaceDevice.current().play(.start)
            onComplete()
        }
        .onAppear {
            triggerCountAnimation()
        }
    }
    
    private func triggerCountAnimation() {
        WKInterfaceDevice.current().play(.click)
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.1
            ringTrim = 0.33
        }
        withAnimation(.easeInOut(duration: 0.7)) {
            scale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            count = 2
            scale = 0.6
            WKInterfaceDevice.current().play(.click)
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.1
                ringTrim = 0.66
            }
            withAnimation(.easeInOut(duration: 0.7)) {
                scale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            count = 1
            scale = 0.6
            WKInterfaceDevice.current().play(.click)
            withAnimation(.easeOut(duration: 0.3)) {
                scale = 1.1
                ringTrim = 1.0
            }
            withAnimation(.easeInOut(duration: 0.7)) {
                scale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            WKInterfaceDevice.current().play(.start)
            onComplete()
        }
    }
}

// MARK: - Custom Focus Creation Sheet
struct CustomFocusSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (String, Int) -> Void
    
    @State private var taskTitle: String = ""
    @State private var minutes: Int = 25
    
    private let presetDurations = [15, 25, 30, 45, 60, 90]
    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Compact Task Name Field
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 11, weight: .semibold))
                    
                    TextField("Task name...", text: $taskTitle)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                // Duration Selection Label + Grid of Big Buttons
                VStack(spacing: 5) {
                    HStack {
                        Text("Duration")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(minutes) min")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 2)
                    
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(presetDurations, id: \.self) { duration in
                            Button {
                                WKInterfaceDevice.current().play(.click)
                                minutes = duration
                            } label: {
                                Text("\(duration)m")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(minutes == duration ? .black : .white)
                                    .frame(maxWidth: .infinity, minHeight: 32)
                                    .background(
                                        minutes == duration
                                            ? AnyShapeStyle(Color.cyan)
                                            : AnyShapeStyle(Color.white.opacity(0.14))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                minutes == duration ? Color.cyan.opacity(0.8) : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Start Button
                Button {
                    let title = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus Session" : taskTitle
                    onStart(title, minutes)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Start (\(minutes)m)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        LinearGradient(
                            colors: [.cyan, Color(red: 0.2, green: 0.7, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Compact Running Focus View with Always-On Display (AOD) Support
struct CompactRunningFocusView: View {
    var store: WatchSessionStore
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let startDate = store.startDate ?? now
            let totalSeconds = Double(store.estimatedMinutes * 60)
            let elapsedSeconds = max(0, now.timeIntervalSince(startDate))
            let progress = min(1.0, elapsedSeconds / max(1.0, totalSeconds))
            let remainingSeconds = max(0, totalSeconds - elapsedSeconds)
            let isOvertime = elapsedSeconds > totalSeconds
            let overtimeSeconds = max(0, elapsedSeconds - totalSeconds)
            
            VStack(spacing: isLuminanceReduced ? 6 : 8) {
                // Focus Ring
                FocusRingMetricView(
                    progress: progress,
                    isOvertime: isOvertime,
                    displaySeconds: isOvertime ? overtimeSeconds : remainingSeconds,
                    isLuminanceReduced: isLuminanceReduced
                )
                .padding(.top, 2)
                
                // Task Title
                Text(store.taskTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isLuminanceReduced ? .secondary : .primary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                
                // Interactive Buttons (Hidden in AOD to match Apple Workout)
                if !isLuminanceReduced {
                    RunningControlButtons(store: store)
                }
            }
        }
    }
}

struct FocusRingMetricView: View {
    let progress: Double
    let isOvertime: Bool
    let displaySeconds: Double
    let isLuminanceReduced: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(isLuminanceReduced ? 0.08 : 0.12), lineWidth: 4.5)
                .frame(width: 84, height: 84)
            
            if isLuminanceReduced {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Color.cyan.opacity(0.75), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 84, height: 84)
            } else {
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(
                            colors: isOvertime ? [.orange, .red] : [.cyan, Color(red: 0.2, green: 0.5, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 84, height: 84)
            }
            
            VStack(spacing: 1) {
                Text(formatTime(displaySeconds))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isLuminanceReduced ? Color.cyan.opacity(0.9) : (isOvertime ? .orange : .white))
                
                Text(isOvertime ? "Overtime" : "Remaining")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isLuminanceReduced ? Color.secondary.opacity(0.6) : Color.secondary)
                    .textCase(.uppercase)
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct RunningControlButtons: View {
    var store: WatchSessionStore
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: {
                    store.extendSession(by: 5)
                }) {
                    Text("+5m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                Button(action: {
                    store.extendSession(by: 15)
                }) {
                    Text("+15m")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 2)
            
            Button(action: {
                store.stopSession()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("End Focus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.85), Color(red: 0.8, green: 0.15, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.top, 2)
        }
    }
}

// MARK: - Compact Idle Home View with Custom Focus Force Button
struct CompactIdleHomeView: View {
    var store: WatchSessionStore
    let onSelectPreset: (String, Int) -> Void
    let onOpenCustom: () -> Void
    
    private let presets: [(title: String, icon: String, minutes: Int, color: Color)] = [
        ("Quick Sprint", "bolt.fill", 15, .cyan),
        ("Pomodoro", "timer", 25, .orange),
        ("Deep Focus", "brain.head.profile", 45, .purple),
        ("Flow State", "waveform.path.ecg", 60, .blue)
    ]
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                onOpenCustom()
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1))
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Custom Focus")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Voice name & time")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.85))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.18), Color.blue.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("Quick Presets")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
            
            ForEach(presets, id: \.title) { preset in
                Button(action: {
                    onSelectPreset(preset.title, preset.minutes)
                }) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(preset.color.opacity(0.22))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: preset.icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(preset.color)
                        }
                        
                        Text(preset.title)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(preset.minutes)m")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 38)
                    .background(Color.white.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
