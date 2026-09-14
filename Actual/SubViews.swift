import SwiftUI
import SwiftData
import EventKit
import WidgetKit
import UniformTypeIdentifiers

// MARK: - HISTORY TAB
struct HistoryTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    @State private var sessionToEdit: Session?
    
    var taskSessions: [Session] {
        sessions.filter { $0.isActualTask }
    }
    
    var groupedSessions: [(Date, [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: taskSessions) { session in
            calendar.startOfDay(for: session.startedAt ?? Date())
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // Stats calculations
    var totalFocusMinutesToday: Int {
        let todaySessions = taskSessions.filter {
            Calendar.current.isDateInToday($0.startedAt ?? Date()) && !$0.isRunning
        }
        return todaySessions.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes ?? 0) }
    }
    
    var completedCount: Int {
        taskSessions.filter { !$0.isRunning && $0.endedAt != nil }.count
    }
    
    private func dayString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                List {
                    // Summary Glass Card at Top
                    Section {
                        summaryHeaderCard
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    
                    if taskSessions.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: "hourglass.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.primary.opacity(0.4))
                                Text("No sessions yet")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.8))
                                Text("Start a focus session in the Log tab to see your time calibration.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .padding(.horizontal, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } else {
                        ForEach(groupedSessions, id: \.0) { (day, dailySessions) in
                            Section {
                                ForEach(dailySessions) { session in
                                    sessionRow(session)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                                                )
                                        )
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                context.delete(session)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            .tint(.red)
                                        }
                                }
                            } header: {
                                HStack {
                                    Text(dayString(for: day))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.7))
                                    Spacer()
                                    let dayTotal = dailySessions.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes ?? 0) }
                                    if dayTotal > 0 {
                                        Text("\(dayTotal)m total")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary.opacity(0.4))
                                    }
                                }
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 6, trailing: 20))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $sessionToEdit) { session in
                EditSessionView(session: session)
            }
        }
    }
    
    // Top Summary Card
    private var summaryHeaderCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TODAY'S FOCUS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    let hours = totalFocusMinutesToday / 60
                    let mins = totalFocusMinutesToday % 60
                    if hours > 0 {
                        Text("\(hours)")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                        Text("h")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    Text("\(mins)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    Text("m")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 36)
                .opacity(0.2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                
                Text("\(completedCount)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 36)
                .opacity(0.2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ACCURACY")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                
                let score = Int(BiasEngine.calculateOverallCalibration(sessions: taskSessions) * 100)
                Text("\(score)%")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(score >= 80 ? Theme.brandMint : (score >= 60 ? Color.orange : Theme.brandCoral))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // Sleek Session Row
    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        HStack(spacing: 14) {
            // Category / Status Dot
            ZStack {
                Circle()
                    .fill(session.isRunning ? Theme.brandMint.opacity(0.2) : Color.primary.opacity(0.06))
                    .frame(width: 36, height: 36)
                
                Image(systemName: session.isRunning ? "timer" : "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(session.isRunning ? Theme.brandMint : .primary.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.rawText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.95))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let est = session.estimatedMinutes {
                        HStack(spacing: 3) {
                            Text("Est")
                                .foregroundStyle(.primary.opacity(0.35))
                            Text("\(est)m")
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                    }
                    
                    if let act = session.actualMinutes {
                        Text("•")
                            .foregroundStyle(.primary.opacity(0.2))
                        HStack(spacing: 3) {
                            Text("Act")
                                .foregroundStyle(.primary.opacity(0.35))
                            Text("\(act)m")
                                .foregroundStyle(.primary.opacity(0.6))
                        }
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            
            Spacer()
            
            if session.isRunning {
                Text("Running")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.brandMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.brandMint.opacity(0.15), in: Capsule())
            } else {
                HStack(spacing: 8) {
                    if let ratio = session.biasRatio {
                        Text(String(format: "%.1fx", ratio))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Color.orange : Theme.brandMint))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Color.orange : Theme.brandMint)).opacity(0.12),
                                in: Capsule()
                            )
                    }
                    
                    Button {
                        sessionToEdit = session
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                            .frame(width: 28, height: 28)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - INSIGHTS TAB
struct InsightsTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    var calibrationScore: Double
    
    var completedSessions: [Session] {
        sessions.filter { $0.biasRatio != nil }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Glowing Circular Gauge Card
                        calibrationGaugeCard
                            .padding(.top, 16)
                        
                        // 3-Metric Glass Grid
                        metricsGrid
                        
                        // Discovered Routines & Habits Section
                        habitsSection
                        
                        // Recent Calibration Performance Cards
                        recentLogsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    // Circular Glowing Calibration Gauge
    private var calibrationGaugeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background Track Ring
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)
                    .frame(width: 170, height: 170)
                
                // Active Score Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, calibrationScore))))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.brandCoral, Color.orange, Theme.brandMint, Theme.brandMint],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: calibrationScore)
                
                // Center Score Display
                VStack(spacing: 2) {
                    Text("\(Int(calibrationScore * 100))%")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(calibrationScore >= 0.8 ? "Synchronized" : (calibrationScore >= 0.6 ? "Calibrating" : "Discrepancy"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(calibrationScore >= 0.8 ? Theme.brandMint : (calibrationScore >= 0.6 ? Color.orange : Theme.brandCoral))
                }
            }
            .padding(.top, 8)
            
            Text("Your perceived time vs actual reality. 100% represents zero estimation distortion.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // 3-Metric Glass Grid
    private var metricsGrid: some View {
        HStack(spacing: 12) {
            metricTile(
                title: "BIAS PATTERN",
                value: biasSummaryText,
                icon: "arrow.left.and.right",
                color: Theme.brandMint
            )
            
            let avgDelta = calculateAverageDelta()
            metricTile(
                title: "AVG DRIFT",
                value: avgDelta,
                icon: "waveform.path.ecg",
                color: Color.purple
            )
            
            let totalHours = completedSessions.reduce(0) { $0 + ($1.actualMinutes ?? 0) } / 60
            metricTile(
                title: "TOTAL LOGGED",
                value: "\(totalHours)h",
                icon: "hourglass",
                color: Color.blue
            )
        }
    }
    
    @ViewBuilder
    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
            
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    private var biasSummaryText: String {
        let ratios = completedSessions.compactMap { $0.biasRatio }
        guard !ratios.isEmpty else { return "Neutral" }
        let avg = ratios.reduce(0.0, +) / Double(ratios.count)
        if avg > 1.2 { return "Over-est" }
        if avg < 0.8 { return "Under-est" }
        return "Calibrated"
    }
    
    private func calculateAverageDelta() -> String {
        let diffs = completedSessions.compactMap { s -> Int? in
            guard let est = s.estimatedMinutes, let act = s.actualMinutes else { return nil }
            return abs(act - est)
        }
        guard !diffs.isEmpty else { return "±0m" }
        let avg = diffs.reduce(0, +) / diffs.count
        return "±\(avg)m"
    }
    
    // Discovered Habits & Recurring Patterns
    private var habitsSection: some View {
        let patterns = RoutineEngine.shared.minePatterns(from: sessions)
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Discovered Routines & Habits")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.9))
                Spacer()
                if !patterns.isEmpty {
                    Text("\(patterns.count) active")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.brandMint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.brandMint.opacity(0.12), in: Capsule())
                }
            }
            .padding(.leading, 4)
            
            if patterns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.waveform")
                        .font(.system(size: 24))
                        .foregroundStyle(.primary.opacity(0.3))
                    Text("Learning your schedule")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                    Text("Log regular activities like meals or workouts at consistent times. Tempo will automatically recognize recurring habits and prompt you when it's time.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                )
            } else {
                ForEach(patterns) { pattern in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 38, height: 38)
                            Image(systemName: pattern.isDayOfWeekSpecific ? "figure.run" : "bolt.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pattern.taskTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.95))
                            
                            Text(pattern.recurrenceDescription)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.55))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(pattern.typicalMinutes)m")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.brandMint)
                            
                            Text("\(pattern.occurrencesCount)x logged")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.35))
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                    )
                }
            }
        }
    }
    
    // Recent Logs Breakdown
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Calibration Logs")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary.opacity(0.9))
                .padding(.leading, 4)
            
            if completedSessions.isEmpty {
                VStack(spacing: 8) {
                    Text("No calibration history")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                    Text("Complete a session with an estimate and actual duration.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                )
            } else {
                ForEach(Array(completedSessions.reversed().prefix(8))) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.rawText)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.95))
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                Text("Est: \(session.estimatedMinutes ?? 0)m")
                                Text("•")
                                Text("Act: \(session.actualMinutes ?? 0)m")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        let ratio = session.biasRatio ?? 1.0
                        HStack(spacing: 4) {
                            Text(String(format: "%.1fx", ratio))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Color.orange : Theme.brandMint))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            (ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Color.orange : Theme.brandMint)).opacity(0.12),
                            in: Capsule()
                        )
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                    )
                }
            }
        }
    }
}

// Helper for History Edit
struct EditSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Name", text: $session.rawText)
                }
                
                Section("Estimates (Minutes)") {
                    HStack {
                        Text("Estimated:")
                        Spacer()
                        TextField("Estimated", value: $session.estimatedMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Actual:")
                        Spacer()
                        TextField("Actual", value: $session.actualMinutes, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    
    @AppStorage("tempo_default_duration") private var defaultDuration: Int = 25
    @AppStorage("tempo_smart_routines_enabled") private var smartRoutinesEnabled: Bool = true
    
    @State private var showClearChatAlert = false
    @State private var showResetAllAlert = false
    @State private var calendarAuthStatus: String = "Checking..."
    @State private var remindersAuthStatus: String = "Checking..."
    
    // Import / Export State
    @State private var exportURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var importAlertTitle: String = ""
    @State private var importAlertMessage: String = ""
    @State private var showImportResultAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Section 1: Preferences
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Preferences")
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Default Duration")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Picker("Default Duration", selection: $defaultDuration) {
                                        Text("15 mins").tag(15)
                                        Text("25 mins").tag(25)
                                        Text("45 mins").tag(45)
                                        Text("60 mins").tag(60)
                                    }
                                    .pickerStyle(.menu)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Divider().opacity(0.15)
                                
                                Toggle(isOn: $smartRoutinesEnabled) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Smart Routine Suggestions")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("Proactively suggest tasks based on your logged patterns")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tint(Color.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                        }
                        
                        // Section 2: Integrations Submenu
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Connected Apps & Integrations")
                            
                            NavigationLink {
                                IntegrationsView(calendarAuthStatus: calendarAuthStatus, remindersAuthStatus: remindersAuthStatus)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(width: 34, height: 34)
                                        Image(systemName: "app.connected.to.app.below.fill")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Color.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Integrations & Services")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text("Apple Calendar, Reminders, and external tools")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 6) {
                                        if calendarAuthStatus == "Connected" || remindersAuthStatus == "Connected" {
                                            Circle()
                                                .fill(Theme.brandSuccess)
                                                .frame(width: 6, height: 6)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Section 3: Data Transfer & Backup
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Data Transfer & Backup")
                            
                            VStack(spacing: 0) {
                                Button {
                                    exportData()
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "square.and.arrow.up.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Export Data & Chats")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text("Transfer chats and focus history to another device")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.3))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                
                                Divider().opacity(0.15)
                                
                                Button {
                                    showFileImporter = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.15))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "square.and.arrow.down.fill")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.blue)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Import Data & Chats")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text("Restore sessions from a Tempo JSON backup")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.primary.opacity(0.3))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                            
                            Text("Exported JSON backups can be AirDropped, saved to Files, or imported on another iPhone.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.4))
                                .padding(.horizontal, 4)
                        }
                        
                        // Section 4: About
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("About")
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Version")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("1.0")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Divider().opacity(0.15)
                                
                                HStack {
                                    Text("Engine")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("Tempo Adaptive Bias Engine")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                        }
                        
                        // Section 5: Data Management (Refined, High Legibility, Not Harsh)
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("Data Management")
                            
                            VStack(spacing: 0) {
                                Button {
                                    showClearChatAlert = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.orange.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "trash")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.orange)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Clean Chat History")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.primary)
                                            Text("Clear chat messages and queries from stream")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .alert("Clean Chat History?", isPresented: $showClearChatAlert) {
                                    Button("Cancel", role: .cancel) {}
                                    Button("Clean Chat", role: .destructive) {
                                        cleanChatHistory()
                                    }
                                } message: {
                                    Text("This will remove chat questions and schedule query bubbles from the Log tab while keeping your tracked focus tasks and history intact.")
                                }
                                
                                Divider().opacity(0.15)
                                
                                Button {
                                    showResetAllAlert = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.red.opacity(0.12))
                                                .frame(width: 32, height: 32)
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Color.red)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Reset All Data")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(Color.red)
                                            Text("Wipe all sessions, calibration scores, and widgets")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "exclamationmark.circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.red.opacity(0.6))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                .alert("Reset All Tempo Data?", isPresented: $showResetAllAlert) {
                                    Button("Cancel", role: .cancel) {}
                                    Button("Reset Everything", role: .destructive) {
                                        resetAllData()
                                    }
                                } message: {
                                    Text("Are you sure you want to reset everything? All tracked sessions, calibration scores, routine patterns, and widgets will be permanently erased. This action cannot be undone.")
                                }
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                }
            }
            .onAppear {
                checkPermissions()
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ActivityViewController(activityItems: [exportURL])
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert(importAlertTitle, isPresented: $showImportResultAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importAlertMessage)
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.leading, 4)
    }
    
    private func checkPermissions() {
        let calStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            calendarAuthStatus = (calStatus == .fullAccess) ? "Connected" : "Access Needed"
        } else {
            calendarAuthStatus = (calStatus == .authorized) ? "Connected" : "Access Needed"
        }
        
        let remStatus = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            remindersAuthStatus = (remStatus == .fullAccess) ? "Connected" : "Access Needed"
        } else {
            remindersAuthStatus = (remStatus == .authorized) ? "Connected" : "Access Needed"
        }
    }
    
    private func exportData() {
        if let url = TempoBackupManager.exportBackup(sessions: sessions) {
            exportURL = url
            showShareSheet = true
        } else {
            importAlertTitle = "Export Failed"
            importAlertMessage = "Could not generate backup JSON file."
            showImportResultAlert = true
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        do {
            let selectedURLs = try result.get()
            guard let selectedURL = selectedURLs.first else { return }
            
            let isAccessing = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let data = try Data(contentsOf: selectedURL)
            let count = try TempoBackupManager.importBackup(data: data, context: context)
            
            importAlertTitle = "Import Successful"
            importAlertMessage = "Successfully imported \(count) sessions into Tempo!"
            showImportResultAlert = true
        } catch {
            importAlertTitle = "Import Failed"
            importAlertMessage = error.localizedDescription
            showImportResultAlert = true
        }
    }
    
    private func cleanChatHistory() {
        for session in sessions {
            if session.isScheduleQuery == true || session.startedAt == nil {
                context.delete(session)
            }
        }
        try? context.save()
        WidgetDataStore.shared.clearPendingSessions()
        LiveActivityManager.shared.cancelAllLiveActivities()
        dismiss()
    }
    
    private func resetAllData() {
        for session in sessions {
            context.delete(session)
        }
        try? context.save()
        WidgetDataStore.shared.clearPendingSessions()
        LiveActivityManager.shared.cancelAllLiveActivities()
        WidgetDataStore.shared.saveSnapshot(WidgetSnapshotData())
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

// MARK: - INTEGRATIONS & CONNECTED APPS VIEW
struct IntegrationsView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var calendarAuthStatus: String = "Connected"
    var remindersAuthStatus: String = "Connected"
    
    @AppStorage("integration_calendar_enabled") private var calendarEnabled: Bool = true
    @AppStorage("integration_reminders_enabled") private var remindersEnabled: Bool = true
    @AppStorage("integration_health_enabled") private var healthEnabled: Bool = true
    @AppStorage("integration_maps_enabled") private var mapsEnabled: Bool = true
    
    @AppStorage("integration_notion_enabled") private var notionEnabled: Bool = false
    @AppStorage("integration_todoist_enabled") private var todoistEnabled: Bool = false
    @AppStorage("integration_google_calendar_enabled") private var googleCalendarEnabled: Bool = false
    @AppStorage("integration_slack_enabled") private var slackEnabled: Bool = false
    @AppStorage("integration_github_enabled") private var githubEnabled: Bool = false
    @AppStorage("integration_music_enabled") private var musicEnabled: Bool = false
    @Bindable private var healthKit = HealthKitManager.shared
    
    var body: some View {
        ZStack {
            SharedBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Apple Ecosystem
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Apple Ecosystem")
                        
                        VStack(spacing: 0) {
                            integrationCustomIconToggleRow(
                                title: "Apple Calendar",
                                subtitle: "Read meetings, focus events, and auto-detect schedules",
                                isOn: $calendarEnabled
                            ) {
                                RealCalendarAppIcon(size: 28)
                            }
                            .onChange(of: calendarEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_calendar_enabled")
                                if newValue {
                                    EventKitManager.shared.requestAccessAndFetch()
                                } else {
                                    EventKitManager.shared.suggestions.removeAll()
                                }
                            }
                            
                            Divider().opacity(0.15)
                            
                            integrationCustomIconToggleRow(
                                title: "Apple Reminders",
                                subtitle: "Sync due tasks, checklists, and complete on focus finish",
                                isOn: $remindersEnabled
                            ) {
                                RealRemindersAppIcon(size: 28)
                            }
                            .onChange(of: remindersEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_reminders_enabled")
                                if newValue {
                                    EventKitManager.shared.requestAccessAndFetch()
                                } else {
                                    EventKitManager.shared.suggestions.removeAll()
                                }
                            }
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Apple Health & Fitness",
                                subtitle: "Log workouts (running, gym, cycling, sports) & mindful sessions",
                                icon: "heart.fill",
                                iconColor: Color(red: 1.0, green: 0.18, blue: 0.33),
                                isOn: $healthEnabled
                            )
                            .onChange(of: healthEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_health_enabled")
                                if newValue {
                                    Task {
                                        _ = await healthKit.requestAuthorization()
                                    }
                                }
                            }
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Apple Maps",
                                subtitle: "Live commute ETAs and navigation buttons",
                                icon: "map.fill",
                                iconColor: Color(red: 0.2, green: 0.78, blue: 0.35),
                                isOn: $mapsEnabled
                            )
                            .onChange(of: mapsEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_maps_enabled")
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                        
                        Text("Toggle any integration off to disconnect it from Tempo.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                            .padding(.leading, 4)
                    }
                    
                    // Productivity & Workspaces (Non-Apple Apps)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Productivity & Task Apps")
                        
                        VStack(spacing: 0) {
                            integrationToggleRow(
                                title: "Notion",
                                subtitle: "Sync task databases and log focus session summaries",
                                icon: "doc.text.fill",
                                iconColor: Color(red: 0.15, green: 0.15, blue: 0.18),
                                isOn: $notionEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Todoist",
                                subtitle: "Bidirectional sync with today's Todoist project items",
                                icon: "checklist",
                                iconColor: Color(red: 0.88, green: 0.28, blue: 0.22),
                                isOn: $todoistEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Google Calendar",
                                subtitle: "Pull Google Workspace events and calendar timeblocks",
                                icon: "calendar.badge.clock",
                                iconColor: Color(red: 0.26, green: 0.52, blue: 0.96),
                                isOn: $googleCalendarEnabled
                            )
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                    }
                    
                    // Developer, Workspace & Media
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Communication & Developer Tools")
                        
                        VStack(spacing: 0) {
                            integrationToggleRow(
                                title: "Slack",
                                subtitle: "Auto-set 'Focusing with Tempo' status & snooze notifications",
                                icon: "bubble.left.and.bubble.right.fill",
                                iconColor: Color(red: 0.38, green: 0.15, blue: 0.45),
                                isOn: $slackEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "GitHub & Linear",
                                subtitle: "Track focus on active pull requests and assigned issues",
                                icon: "chevron.left.forwardslash.chevron.right",
                                iconColor: Color(red: 0.35, green: 0.40, blue: 0.95),
                                isOn: $githubEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Spotify & Apple Music",
                                subtitle: "Trigger focus binaural beats & ambient playlists",
                                icon: "music.note",
                                iconColor: Color(red: 0.12, green: 0.84, blue: 0.38),
                                isOn: $musicEnabled
                            )
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.leading, 4)
    }
    
    @ViewBuilder
    private func integrationRow<Content: View>(
        title: String,
        subtitle: String,
        status: String,
        isConnected: Bool,
        @ViewBuilder icon: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            icon()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(status)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(isConnected ? Theme.brandSuccess : Color.orange)
                Image(systemName: isConnected ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isConnected ? Theme.brandSuccess : Color.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func integrationCustomIconToggleRow<Content: View>(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        @ViewBuilder icon: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            icon()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func integrationToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func integrationStaticRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        status: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Text(status)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.brandSuccess)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
    


// MARK: - Activity View Controller Representable
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
