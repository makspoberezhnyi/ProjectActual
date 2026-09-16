import SwiftUI
import SwiftData
import EventKit
import WidgetKit
import UniformTypeIdentifiers
import Charts

// MARK: - HISTORY TAB
struct HistoryTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    @State private var sessionToEdit: Session?
    @State private var expandedSessionIds: Set<String> = []
    
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
        return TempoFormatters.dayHeaderFormatter.string(from: date)
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
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary.opacity(0.8))
                                Text("Start a focus session in the Log tab to see your time calibration.")
                                    .font(.system(size: 13, weight: .regular))
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
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary.opacity(0.7))
                                    Spacer()
                                    let dayTotal = dailySessions.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes ?? 0) }
                                    if dayTotal > 0 {
                                        Text("\(dayTotal)m total")
                                            .font(.system(size: 11, weight: .medium))
                                            .monospacedDigit()
                                            .foregroundStyle(.primary.opacity(0.45))
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
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.primary.opacity(0.45))
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    let hours = totalFocusMinutesToday / 60
                    let mins = totalFocusMinutesToday % 60
                    if hours > 0 {
                        Text("\(hours)")
                            .font(.system(size: 24, weight: .semibold))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: false))
                            .animation(.snappy, value: hours)
                        Text("h")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                    Text("\(mins)")
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: false))
                        .animation(.snappy, value: mins)
                    Text("m")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 36)
                .opacity(0.15)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.primary.opacity(0.45))
                
                Text("\(completedCount)")
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.snappy, value: completedCount)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .frame(height: 36)
                .opacity(0.15)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("ACCURACY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.primary.opacity(0.45))
                
                let score = Int(BiasEngine.calculateOverallCalibration(sessions: taskSessions) * 100)
                Text("\(score)%")
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(score >= 80 ? Theme.brandMint : (score >= 60 ? Theme.brandCyan : Theme.brandCoral))
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
    
    // Sleek Expandable Session Row
    @ViewBuilder
    private func sessionRow(_ session: Session) -> some View {
        let isExpanded = expandedSessionIds.contains(session.sessionIdentifier)
        
        VStack(alignment: .leading, spacing: 10) {
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
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.95))
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let est = session.estimatedMinutes {
                            HStack(spacing: 3) {
                                Text("Est")
                                    .foregroundStyle(.primary.opacity(0.35))
                                Text("\(est)m")
                                    .monospacedDigit()
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
                                    .monospacedDigit()
                                    .foregroundStyle(.primary.opacity(0.6))
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .regular))
                }
                
                Spacer()
                
                if session.isRunning {
                    Text("Running")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.brandMint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.brandMint.opacity(0.15), in: Capsule())
                } else {
                    HStack(spacing: 8) {
                        if let ratio = session.biasRatio {
                            Text(String(format: "%.1fx", ratio))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Theme.brandCyan : Theme.brandMint))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    (ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Theme.brandCyan : Theme.brandMint)).opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(AppMotion.cardExpand) {
                    if isExpanded {
                        expandedSessionIds.remove(session.sessionIdentifier)
                    } else {
                        expandedSessionIds.insert(session.sessionIdentifier)
                    }
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().opacity(0.15)
                    
                    // Session Details Breakdown
                    HStack(spacing: 12) {
                        if let start = session.startedAt {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("STARTED")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(start.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12, weight: .medium))
                                    .monospacedDigit()
                            }
                        }
                        
                        if let end = session.endedAt {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("COMPLETED")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(end.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 12, weight: .medium))
                                    .monospacedDigit()
                            }
                        }
                        
                        if let est = session.estimatedMinutes, let act = session.actualMinutes {
                            let diff = act - est
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DELTA")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(diff == 0 ? "Exact match" : (diff > 0 ? "+\(diff)m overrun" : "\(diff)m ahead"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(diff == 0 ? Theme.brandMint : (diff > 0 ? Theme.brandCoral : Theme.brandCyan))
                            }
                        }
                        
                        Spacer()
                    }
                    
                    if let dest = session.destinationTitle {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.teal)
                            Text("Destination: \(dest)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.75))
                        }
                        .padding(.vertical, 2)
                    }
                    
                    // Quick Action Buttons
                    HStack(spacing: 8) {
                        Button {
                            sessionToEdit = session
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                Text("Edit Estimate / Duration")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                        .pressable(scale: 0.94)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation(AppMotion.smoothOut) {
                                context.delete(session)
                                try? context.save()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .padding(7)
                        }
                        .pressable(scale: 0.90)
                    }
                }
                .transition(.cardExpandTransition)
            }
        }
    }
}

// MARK: - INSIGHTS & ANALYTICS TAB (Swift Charts)

enum InsightsSegment: String, CaseIterable, Identifiable, Sendable {
    case overview = "Overview"
    case patterns = "Patterns"
    
    var id: String { rawValue }
}

enum AnalyticsTimeframe: String, CaseIterable, Identifiable, Sendable {
    case week = "7D"
    case month = "30D"
    case all = "All"
    
    var id: String { rawValue }
}

struct DailyFocusTrendData: Identifiable, Sendable {
    let id: Date
    let date: Date
    let dayShortLabel: String
    let minutes: Int
    let completedCount: Int
    let avgRatio: Double?
}

struct BiasDistributionSlice: Identifiable, Sendable {
    let id: String
    let category: String
    let count: Int
    let percentage: Double
    let color: Color
    let icon: String
}

struct HourlyFocusDistribution: Identifiable, Sendable {
    let id: Int
    let hour: Int
    let hourLabel: String
    let minutes: Int
}

struct InsightsTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var sessions: [Session]
    var calibrationScore: Double
    
    @State private var selectedSegment: InsightsSegment = .overview
    @State private var selectedTimeframe: AnalyticsTimeframe = .week
    @State private var selectedDate: Date? = nil
    @State private var selectedHour: Int? = nil
    
    var completedSessions: [Session] {
        sessions.filter { $0.biasRatio != nil }
    }
    
    var taskSessions: [Session] {
        sessions.filter { $0.isActualTask && $0.actualMinutes != nil }
    }
    
    // MARK: - Filtered Timeframe Sessions
    var timeframeFilteredSessions: [Session] {
        let cal = Calendar.current
        let now = Date()
        switch selectedTimeframe {
        case .week:
            let weekAgo = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
            return taskSessions.filter { ($0.startedAt ?? $0.timestamp) >= weekAgo }
        case .month:
            let monthAgo = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
            return taskSessions.filter { ($0.startedAt ?? $0.timestamp) >= monthAgo }
        case .all:
            return taskSessions
        }
    }
    
    // MARK: - Daily Trend Data
    var dailyTrendData: [DailyFocusTrendData] {
        let cal = Calendar.current
        let now = Date()
        let daysCount = (selectedTimeframe == .week ? 7 : (selectedTimeframe == .month ? 30 : 14))
        var list: [DailyFocusTrendData] = []
        
        for offset in (0..<daysCount).reversed() {
            guard let dayDate = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: now)) else { continue }
            let matching = taskSessions.filter { cal.isDate($0.startedAt ?? $0.timestamp, inSameDayAs: dayDate) }
            let totalMins = matching.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
            let ratios = matching.compactMap { $0.biasRatio }
            let avgRatio = ratios.isEmpty ? nil : (ratios.reduce(0.0, +) / Double(ratios.count))
            
            list.append(
                DailyFocusTrendData(
                    id: dayDate,
                    date: dayDate,
                    dayShortLabel: TempoFormatters.chartShortDayFormatter.string(from: dayDate),
                    minutes: totalMins,
                    completedCount: matching.count,
                    avgRatio: avgRatio
                )
            )
        }
        return list
    }
    
    var selectedDayData: DailyFocusTrendData? {
        guard let selectedDate else { return nil }
        let cal = Calendar.current
        return dailyTrendData.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }
    
    var dailyAverageMinutes: Int {
        let total = dailyTrendData.reduce(0) { $0 + $1.minutes }
        guard !dailyTrendData.isEmpty else { return 0 }
        return total / dailyTrendData.count
    }
    
    // MARK: - Bias Distribution
    var biasDistribution: [BiasDistributionSlice] {
        let total = max(1, completedSessions.count)
        var accurateCount = 0
        var underCount = 0
        var overCount = 0
        
        for s in completedSessions {
            guard let r = s.biasRatio else { continue }
            if r >= 0.8 && r <= 1.2 {
                accurateCount += 1
            } else if r < 0.8 {
                underCount += 1
            } else {
                overCount += 1
            }
        }
        
        return [
            BiasDistributionSlice(
                id: "accurate",
                category: "Calibrated",
                count: accurateCount,
                percentage: Double(accurateCount) / Double(total) * 100.0,
                color: Theme.brandMint,
                icon: "checkmark.circle.fill"
            ),
            BiasDistributionSlice(
                id: "under",
                category: "Underestimated",
                count: underCount,
                percentage: Double(underCount) / Double(total) * 100.0,
                color: Theme.brandCoral,
                icon: "arrow.up.right.circle.fill"
            ),
            BiasDistributionSlice(
                id: "over",
                category: "Overestimated",
                count: overCount,
                percentage: Double(overCount) / Double(total) * 100.0,
                color: Theme.brandCyan,
                icon: "arrow.down.right.circle.fill"
            )
        ].filter { $0.count > 0 || completedSessions.isEmpty }
    }
    
    // MARK: - Hourly Productivity Distribution
    var hourlyDistribution: [HourlyFocusDistribution] {
        let cal = Calendar.current
        var hourBuckets: [Int: Int] = [:]
        for h in 6...23 { hourBuckets[h] = 0 }
        
        for s in timeframeFilteredSessions {
            guard let start = s.startedAt ?? s.endedAt else { continue }
            let hour = cal.component(.hour, from: start)
            let mins = s.actualMinutes ?? 0
            if hour >= 6 && hour <= 23 {
                hourBuckets[hour, default: 0] += mins
            }
        }
        
        return (6...23).map { hour in
            let label = hour == 12 ? "12PM" : (hour > 12 ? "\(hour - 12)PM" : "\(hour)AM")
            return HourlyFocusDistribution(
                id: hour,
                hour: hour,
                hourLabel: label,
                minutes: hourBuckets[hour] ?? 0
            )
        }
    }
    
    var peakHourString: String {
        let sorted = hourlyDistribution.sorted { $0.minutes > $1.minutes }
        guard let top = sorted.first, top.minutes > 0 else { return "9 AM – 11 AM" }
        let nextHour = (top.hour + 1) % 24
        let nextLabel = nextHour == 12 ? "12PM" : (nextHour > 12 ? "\(nextHour - 12)PM" : "\(nextHour)AM")
        return "\(top.hourLabel) – \(nextLabel)"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Segmented Control (Overview vs Patterns)
                        Picker("Insights View", selection: $selectedSegment) {
                            ForEach(InsightsSegment.allCases) { seg in
                                Text(seg.rawValue).tag(seg)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 8)
                        
                        if selectedSegment == .overview {
                            // 1. Hero Gauge
                            calibrationGaugeCard
                            
                            // 2. Metrics 3-Grid
                            metricsGrid
                            
                            // 3. Focus Activity Chart
                            focusTrendChartCard
                        } else {
                            // 4. Estimation Breakdown Donut
                            biasDistributionChartCard
                            
                            // 5. Hourly Peak Distribution
                            peakHoursChartCard
                            
                            // 6. Recent Logs
                            recentLogsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
    
    // MARK: - 1. Hero Calibration Gauge Card
    private var calibrationGaugeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 12)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.02, calibrationScore))))
                    .stroke(
                        AngularGradient(
                            colors: [Theme.brandCoral, Theme.brandCyan, Theme.brandMint, Theme.brandMint],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(AppMotion.smoothOut, value: calibrationScore)
                
                VStack(spacing: 2) {
                    Text("\(Int(calibrationScore * 100))%")
                        .font(.system(size: 44, weight: .semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.primary)
                    
                    Text(calibrationScore >= 0.8 ? "Synchronized" : (calibrationScore >= 0.6 ? "Calibrating" : "Discrepancy"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(calibrationScore >= 0.8 ? Theme.brandMint : (calibrationScore >= 0.6 ? Theme.brandCyan : Theme.brandCoral))
                }
            }
            .padding(.top, 4)
            
            Text("Your perceived time vs actual reality. 100% represents zero estimation distortion.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // MARK: - 2. Metrics Grid
    private var metricsGrid: some View {
        HStack(spacing: 10) {
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
                color: Theme.brandIndigo
            )
            
            let totalHours = completedSessions.reduce(0) { $0 + ($1.actualMinutes ?? 0) } / 60
            metricTile(
                title: "TOTAL LOGGED",
                value: "\(totalHours)h",
                icon: "hourglass",
                color: Theme.brandCyan
            )
        }
    }
    
    @ViewBuilder
    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.primary.opacity(0.45))
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // MARK: - 3. Interactive Focus Trend Chart (Swift Charts)
    private var focusTrendChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header & Timeframe Picker
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus Activity")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.95))
                    
                    if let sel = selectedDayData {
                        HStack(spacing: 6) {
                            Text(TempoFormatters.chartDayFormatter.string(from: sel.date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.brandMint)
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text("\(sel.minutes)m (\(sel.completedCount) tasks)")
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.primary.opacity(0.7))
                        }
                    } else {
                        Text("Daily average: \(dailyAverageMinutes)m")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
                
                Spacer()
                
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(AnalyticsTimeframe.allCases) { tf in
                        Text(tf.rawValue).tag(tf)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }
            
            // Swift Chart Container
            Chart {
                if dailyAverageMinutes > 0 {
                    RuleMark(y: .value("Average", dailyAverageMinutes))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.primary.opacity(0.2))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Avg \(dailyAverageMinutes)m")
                                .font(.system(size: 9, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                }
                
                ForEach(dailyTrendData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: selectedDate == nil || Calendar.current.isDate(item.date, inSameDayAs: selectedDate!)
                                ? [Theme.brandMint, Theme.brandCyan]
                                : [Theme.brandMint.opacity(0.35), Theme.brandCyan.opacity(0.25)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                    .accessibilityLabel(TempoFormatters.chartDayFormatter.string(from: item.date))
                    .accessibilityValue("\(item.minutes) minutes focused across \(item.completedCount) tasks")
                }
                
                if let selectedDate {
                    RuleMark(x: .value("Selected", selectedDate, unit: .day))
                        .foregroundStyle(Theme.brandMint.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                        .offset(yStart: -6)
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: selectedTimeframe == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(TempoFormatters.chartShortDayFormatter.string(from: date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.5))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(Color.primary.opacity(0.08))
                    if let mins = value.as(Int.self) {
                        AxisValueLabel {
                            Text("\(mins)m")
                                .font(.system(size: 10, weight: .regular))
                                .monospacedDigit()
                                .foregroundStyle(.primary.opacity(0.4))
                        }
                    }
                }
            }
            .frame(height: 170)
            
            // Interaction Hint
            HStack {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary.opacity(0.35))
                Text("Touch and drag on the chart to inspect daily focus details.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.45))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // MARK: - 4. Time Distortion & Bias Distribution (Swift Charts Donut)
    private var biasDistributionChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimation Accuracy Breakdown")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.95))
                Text("How your planned estimates compare against elapsed reality.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary.opacity(0.5))
            }
            
            HStack(spacing: 20) {
                // Donut Chart
                ZStack {
                    Chart(biasDistribution) { slice in
                        SectorMark(
                            angle: .value("Count", slice.count),
                            innerRadius: .ratio(0.64),
                            outerRadius: .inset(4),
                            angularInset: 2.0
                        )
                        .cornerRadius(4)
                        .foregroundStyle(slice.color)
                        .accessibilityLabel(slice.category)
                        .accessibilityValue("\(slice.count) sessions, \(Int(slice.percentage)) percent")
                    }
                    .frame(width: 120, height: 120)
                    
                    VStack(spacing: 1) {
                        let accurate = biasDistribution.first(where: { $0.id == "accurate" })?.percentage ?? 0
                        Text("\(Int(accurate))%")
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("Accurate")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.brandMint)
                    }
                }
                
                // Legend Details
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(biasDistribution) { slice in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(slice.category)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary.opacity(0.9))
                                Text("\(slice.count) tasks (\(Int(slice.percentage))%)")
                                    .font(.system(size: 10, weight: .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary.opacity(0.5))
                            }
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    // MARK: - 5. Peak Productivity Hours (Swift Charts)
    private var peakHoursChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Productivity Peak Hours")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.95))
                    Text("Focus distribution across hours of the day.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.5))
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.brandCyan)
                    Text(peakHourString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.brandCyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.brandCyan.opacity(0.12), in: Capsule())
            }
            
            Chart(hourlyDistribution) { item in
                BarMark(
                    x: .value("Hour", item.hour),
                    y: .value("Minutes", item.minutes)
                )
                .foregroundStyle(
                    item.minutes > 0
                        ? LinearGradient(colors: [Theme.brandCyan.opacity(0.6), Theme.brandCyan], startPoint: .bottom, endPoint: .top)
                        : LinearGradient(colors: [Color.primary.opacity(0.06), Color.primary.opacity(0.06)], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(3)
                .accessibilityLabel("\(item.hourLabel)")
                .accessibilityValue("\(item.minutes) minutes focused")
            }
            .chartXAxis {
                AxisMarks(values: [6, 9, 12, 15, 18, 21]) { value in
                    if let hour = value.as(Int.self) {
                        let label = hour == 12 ? "12P" : (hour > 12 ? "\(hour-12)P" : "\(hour)A")
                        AxisValueLabel {
                            Text(label)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.primary.opacity(0.45))
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 90)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
    
    // MARK: - 6. Recent Logs Section
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Calibration Logs")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.9))
                .padding(.leading, 2)
            
            if completedSessions.isEmpty {
                VStack(spacing: 8) {
                    Text("No calibration history")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.6))
                    Text("Complete a session with an estimate and actual duration.")
                        .font(.system(size: 12, weight: .regular))
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
                ForEach(Array(completedSessions.reversed().prefix(6))) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.rawText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary.opacity(0.95))
                                .lineLimit(1)
                            
                            HStack(spacing: 8) {
                                Text("Est: \(session.estimatedMinutes ?? 0)m")
                                Text("•")
                                Text("Act: \(session.actualMinutes ?? 0)m")
                            }
                            .font(.system(size: 11, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(.primary.opacity(0.45))
                        }
                        
                        Spacer()
                        
                        let ratio = session.biasRatio ?? 1.0
                        HStack(spacing: 4) {
                            Text(String(format: "%.1fx", ratio))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Theme.brandCyan : Theme.brandMint))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            (ratio > 1.2 ? Theme.brandCoral : (ratio < 0.8 ? Theme.brandCyan : Theme.brandMint)).opacity(0.12),
                            in: Capsule()
                        )
                    }
                    .padding(13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                    )
                }
            }
        }
    }
}


// MARK: - PROFILE TAB
struct ProfileTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    
    var sessions: [Session]
    var calibrationScore: Double
    
    @AppStorage("tempo_default_duration") private var defaultDuration: Int = 25
    @AppStorage("tempo_smart_routines_enabled") private var smartRoutinesEnabled: Bool = true
    
    @State private var showClearChatAlert = false
    @State private var showResetAllAlert = false
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportResultAlert = false
    
    var completedSessions: [Session] {
        sessions.filter { $0.isActualTask && $0.actualMinutes != nil }
    }
    
    var totalHours: Double {
        let mins = completedSessions.reduce(0) { $0 + ($1.actualMinutes ?? 0) }
        return Double(mins) / 60.0
    }
    
    var masteryTitle: (tier: String, description: String, icon: String, tint: Color) {
        if calibrationScore >= 0.85 {
            return ("Synchronized Master", "Time perception matches reality within ±10%", "sparkles", Theme.brandMint)
        } else if calibrationScore >= 0.70 {
            return ("Intuitive Focus", "Strong consistency with minor estimation variance", "gauge.with.dots.needle.bottom.50percent", Theme.brandCyan)
        } else if calibrationScore >= 0.50 {
            return ("Adaptive Explorer", "Actively calibrating cognitive time distortion", "chart.line.uptrend.xyaxis", Theme.brandIndigo)
        } else {
            return ("Calibrating", "Gathering focus patterns to reduce planning fallacy", "clock.arrow.circlepath", Theme.brandSlate)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SharedBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Hero Card
                        heroMasteryCard
                            .padding(.top, 8)
                        
                        // 2. Preferences
                        preferencesCard
                        
                        // 3. Discovered Habits & Routines
                        habitsCard
                        
                        // 4. Connected Integrations Submenu Card
                        integrationsCard
                        
                        // 5. Data Management & Backups Card
                        dataTransferCard
                        
                        // 6. About Card
                        aboutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
    
    // MARK: - Hero Mastery Card
    private var heroMasteryCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [masteryTitle.tint.opacity(0.25), masteryTitle.tint.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .overlay(Circle().strokeBorder(masteryTitle.tint.opacity(0.35), lineWidth: 1.0))
                    
                    Image(systemName: masteryTitle.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(masteryTitle.tint)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(masteryTitle.tier)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        
                        Text("\(Int(calibrationScore * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(masteryTitle.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(masteryTitle.tint.opacity(0.12), in: Capsule())
                    }
                    
                    Text(masteryTitle.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            Divider().opacity(0.15)
            
            HStack(spacing: 12) {
                statBox(title: "LIFETIME FOCUS", value: String(format: "%.1fh", totalHours))
                Divider().frame(height: 28).opacity(0.15)
                statBox(title: "COMPLETED", value: "\(completedSessions.count)")
                Divider().frame(height: 28).opacity(0.15)
                statBox(title: "ACCURACY", value: "\(Int(calibrationScore * 100))%")
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
        )
    }
    
    @ViewBuilder
    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.primary.opacity(0.45))
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Preferences Card
    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferences")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Default Duration")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("Default Duration", selection: $defaultDuration) {
                        Text("15 mins").tag(15)
                        Text("25 mins").tag(25)
                        Text("45 mins").tag(45)
                        Text("60 mins").tag(60)
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().opacity(0.15)
                
                Toggle(isOn: $smartRoutinesEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Routine Suggestions")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Proactively suggest tasks based on your logged patterns")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Theme.brandCyan)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
            )
        }
    }
    
    // MARK: - Habits Card
    private var habitsCard: some View {
        let patterns = RoutineEngine.shared.minePatterns(from: sessions)
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Discovered Routines", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.75))
                Spacer()
                if !patterns.isEmpty {
                    Text("\(patterns.count) active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.brandMint)
                }
            }
            .padding(.leading, 2)
            
            if patterns.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.35))
                    Text("Log regular activities to discover automated routines and time habits.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(patterns.prefix(4)) { pattern in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.brandCyan.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: pattern.isDayOfWeekSpecific ? "figure.run" : "bolt.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.brandCyan)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern.taskTitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                
                                Text(pattern.recurrenceDescription)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(pattern.typicalMinutes)m")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.brandMint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Integrations Card
    private var integrationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ecosystem & Integrations")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.leading, 4)
            
            NavigationLink {
                IntegrationsView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.brandCyan.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "app.connected.to.app.below.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected Apps & Services")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Apple Watch, Calendar, Reminders & Maps")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.3))
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
    }
    
    // MARK: - Data Management & Backup Card
    private var dataTransferCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data Management")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Button {
                    exportData()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brandCyan)
                            .frame(width: 28)
                        
                        Text("Export Backup (JSON)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider().opacity(0.12)
                
                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brandCyan)
                            .frame(width: 28)
                        
                        Text("Import Backup (JSON)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.primary.opacity(0.25))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                
                Divider().opacity(0.12)
                
                Button {
                    showClearChatAlert = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brandSlate)
                            .frame(width: 28)
                        
                        Text("Clean Chat History")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
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
                    Text("This removes conversational and schedule query bubbles from the Log stream while preserving all focus metrics.")
                }
                
                Divider().opacity(0.12)
                
                Button {
                    showResetAllAlert = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.brandCoral)
                            .frame(width: 28)
                        
                        Text("Reset All Data")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.brandCoral)
                        
                        Spacer()
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
    
    // MARK: - About Card
    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.6))
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("1.0")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().opacity(0.15)
                
                HStack {
                    Text("Engine")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Tempo Adaptive Bias Engine")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.brandCyan)
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

// MARK: - INTEGRATIONS & CONNECTED APPS VIEW
struct IntegrationsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var watchManager = WatchConnectivityManager.shared
    
    var calendarAuthStatus: String = "Connected"
    var remindersAuthStatus: String = "Connected"
    
    @AppStorage("integration_watch_enabled") private var watchEnabled: Bool = true
    @AppStorage("integration_watch_haptics_enabled") private var watchHapticsEnabled: Bool = true
    @AppStorage("integration_watch_smart_stack_enabled") private var watchSmartStackEnabled: Bool = true
    @AppStorage("integration_watch_health_sync_enabled") private var watchHealthSyncEnabled: Bool = true
    
    @AppStorage("integration_calendar_enabled") private var calendarEnabled: Bool = true
    @AppStorage("integration_reminders_enabled") private var remindersEnabled: Bool = true
    @AppStorage("integration_maps_enabled") private var mapsEnabled: Bool = true
    @AppStorage("integration_notifications_enabled") private var notificationsEnabled: Bool = true
    
    var body: some View {
        ZStack {
            SharedBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Apple Watch Integration Spotlight Card
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Apple Watch")
                        
                        VStack(spacing: 0) {
                            // Watch Connection Hero Banner
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.brandCyan.opacity(0.25), Theme.brandMint.opacity(0.12)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 44, height: 44)
                                        .overlay(Circle().strokeBorder(Theme.brandCyan.opacity(0.35), lineWidth: 1.0))
                                    
                                    Image(systemName: "applewatch.side.right")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Theme.brandCyan)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("Apple Watch Sync")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Theme.brandMint)
                                                .frame(width: 6, height: 6)
                                            Text("Active")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(Theme.brandMint)
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Theme.brandMint.opacity(0.12), in: Capsule())
                                    }
                                    
                                    Text("Bidirectional live timer syncing, wrist haptics & Smart Stack")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Watch Companion",
                                subtitle: "Sync live focus sessions and timer controls with Apple Watch",
                                icon: "applewatch",
                                iconColor: Theme.brandCyan,
                                isOn: $watchEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Haptic Wrist Prompts",
                                subtitle: "Gentle wrist taps when entering focus, halfway marks, and completion",
                                icon: "waveform",
                                iconColor: Theme.brandMint,
                                isOn: $watchHapticsEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Smart Stack & Complications",
                                subtitle: "Auto-surface running focus timers in watchOS Smart Stack",
                                icon: "square.stack.3d.up.fill",
                                iconColor: Theme.brandIndigo,
                                isOn: $watchSmartStackEnabled
                            )
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Mindful Focus (Apple Health)",
                                subtitle: "Automatically record logged focus sessions as Mindful Minutes",
                                icon: "heart.fill",
                                iconColor: Color(red: 1.0, green: 0.32, blue: 0.45),
                                isOn: $watchHealthSyncEnabled
                            )
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                    }
                    
                    // Apple Ecosystem Section
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
                                title: "Apple Maps",
                                subtitle: "Live commute ETAs and navigation buttons",
                                icon: "map.fill",
                                iconColor: Color(red: 0.2, green: 0.78, blue: 0.35),
                                isOn: $mapsEnabled
                            )
                            .onChange(of: mapsEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_maps_enabled")
                            }
                            
                            Divider().opacity(0.15)
                            
                            integrationToggleRow(
                                title: "Notifications & Timer Alerts",
                                subtitle: "Alerts when estimated focus or workout finishes, and routine reminders",
                                icon: "bell.badge.fill",
                                iconColor: Color.red,
                                isOn: $notificationsEnabled
                            )
                            .onChange(of: notificationsEnabled) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "integration_notifications_enabled")
                                if newValue {
                                    Task {
                                        _ = await NotificationManager.shared.requestAuthorization()
                                    }
                                }
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(GlassStyles.borderGradient(colorScheme: colorScheme), lineWidth: 1.0)
                        )
                        
                        Text("All integrations run privately on-device without cloud servers or accounts.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.primary.opacity(0.4))
                            .padding(.leading, 4)
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.6))
            .padding(.leading, 4)
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
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.brandCyan)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.brandCyan)
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

