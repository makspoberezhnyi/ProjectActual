import Foundation
import SwiftData
import SwiftUI

@Model
final class Session {
    var rawText: String
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var startedAt: Date?
    var endedAt: Date?
    var tempoResponse: String?
    var tempoEndResponse: String?
    var endCommandText: String?
    var isRetroactive: Bool?
    var isScheduleQuery: Bool?
    var schedulePayload: String?
    var integrationSource: String?
    var createdAt: Date?
    
    init(
        rawText: String,
        estimatedMinutes: Int? = nil,
        startedAt: Date? = nil,
        tempoResponse: String? = nil,
        tempoEndResponse: String? = nil,
        endCommandText: String? = nil,
        isRetroactive: Bool? = nil,
        isScheduleQuery: Bool? = nil,
        schedulePayload: String? = nil,
        integrationSource: String? = nil,
        createdAt: Date? = Date()
    ) {
        self.rawText = rawText
        self.estimatedMinutes = estimatedMinutes
        self.startedAt = startedAt
        self.tempoResponse = tempoResponse
        self.tempoEndResponse = tempoEndResponse
        self.endCommandText = endCommandText
        self.isRetroactive = isRetroactive
        self.isScheduleQuery = isScheduleQuery
        self.schedulePayload = schedulePayload
        self.integrationSource = integrationSource
        self.createdAt = createdAt ?? Date()
    }
    
    var timestamp: Date {
        createdAt ?? startedAt ?? Date()
    }
    
    var scheduleItems: [ScheduleItem] {
        guard let payload = schedulePayload,
              let data = payload.data(using: .utf8),
              let items = try? JSONDecoder().decode([ScheduleItem].self, from: data) else {
            return []
        }
        return items
    }
    
    var isRunning: Bool {
        startedAt != nil && endedAt == nil && !(isScheduleQuery ?? false)
    }
    
    var biasRatio: Double? {
        guard let actual = actualMinutes, let est = estimatedMinutes, est > 0 else { return nil }
        return Double(actual) / Double(est)
    }
}

enum PetTier: String {
    case starving = "Starving"
    case dizzy = "Dizzy"
    case healthy = "Healthy"
    case thriving = "Thriving"
    case eating = "Eating"
    
    var color: Color {
        switch self {
        case .starving: return Color.gray
        case .dizzy: return Color.orange
        case .healthy: return Theme.brandMint
        case .thriving: return Theme.brandCoral
        case .eating: return Theme.brandCoral.opacity(0.8)
        }
    }
}

struct ActionCard: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let minutes: Int
    let icon: String
}

final class BiasEngine {
    static func calculateOverallCalibration(sessions: [Session]) -> Double {
        let closed = sessions.filter { $0.biasRatio != nil }
        guard !closed.isEmpty else { return 0.5 } // Neutral start
        
        let totalDeviation = closed.reduce(0.0) { sum, session in
            let ratio = session.biasRatio!
            return sum + abs(1.0 - ratio)
        }
        
        let avgDeviation = totalDeviation / Double(closed.count)
        let score = max(0.0, 1.0 - avgDeviation)
        return score
    }
    
    static func currentPetTier(sessions: [Session]) -> PetTier {
        if sessions.contains(where: { $0.isRunning }) {
            return .eating
        }
        
        let todaySessions = sessions.filter { Calendar.current.isDateInToday($0.startedAt ?? Date()) }
        let totalMinutes = todaySessions.compactMap { $0.actualMinutes }.reduce(0, +)
        
        if totalMinutes == 0 {
            return .starving
        }
        
        let calibration = calculateOverallCalibration(sessions: sessions)
        
        if calibration < 0.6 {
            return .dizzy
        } else if calibration > 0.85 && totalMinutes > 60 {
            return .thriving
        } else {
            return .healthy
        }
    }
}
