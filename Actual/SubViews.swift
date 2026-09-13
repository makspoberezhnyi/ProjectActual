import SwiftUI
import SwiftData

// MARK: - HISTORY TAB
struct HistoryTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    @State private var sessionToEdit: Session?
    
    var groupedSessions: [(Date, [Session])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startedAt ?? Date())
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // Stats calculations
    var totalFocusMinutesToday: Int {
        let todaySessions = sessions.filter {
            Calendar.current.isDateInToday($0.startedAt ?? Date()) && !$0.isRunning
        }
        return todaySessions.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes ?? 0) }
    }
    
    var completedCount: Int {
        sessions.filter { !$0.isRunning }.count
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
                    
                    if sessions.isEmpty {
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
                
                let score = Int(BiasEngine.calculateOverallCalibration(sessions: sessions) * 100)
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
