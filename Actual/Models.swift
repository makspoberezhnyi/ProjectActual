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
    var travelPayload: String?
    var isTravelQuery: Bool?
    var integrationSource: String?
    var linkedEventIdentifier: String?
    var isLinkedToCalendar: Bool?
    var isLinkedToReminders: Bool?
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
        travelPayload: String? = nil,
        isTravelQuery: Bool? = nil,
        integrationSource: String? = nil,
        linkedEventIdentifier: String? = nil,
        isLinkedToCalendar: Bool? = nil,
        isLinkedToReminders: Bool? = nil,
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
        self.travelPayload = travelPayload
        self.isTravelQuery = isTravelQuery
        self.integrationSource = integrationSource
        self.linkedEventIdentifier = linkedEventIdentifier
        self.isLinkedToCalendar = isLinkedToCalendar
        self.isLinkedToReminders = isLinkedToReminders
        self.createdAt = createdAt ?? Date()
    }
    
    var sessionIdentifier: String {
        "\(persistentModelID)"
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
    
    var travelResult: TravelAssessmentResult? {
        guard let payload = travelPayload,
              let data = payload.data(using: .utf8),
              let result = try? JSONDecoder().decode(TravelAssessmentResult.self, from: data) else {
            return nil
        }
        return result
    }
    
    var isRunning: Bool {
        startedAt != nil && endedAt == nil && !(isScheduleQuery ?? false) && !(isTravelQuery ?? false)
    }
    
    var isActualTask: Bool {
        startedAt != nil && !(isScheduleQuery ?? false) && !(isTravelQuery ?? false)
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

// MARK: - Data Backup & Transfer (Import / Export)

struct TempoBackup: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var appVersion: String = "1.0"
    var sessions: [SessionDTO]
}

struct SessionDTO: Codable {
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
    var travelPayload: String?
    var isTravelQuery: Bool?
    var integrationSource: String?
    var linkedEventIdentifier: String?
    var isLinkedToCalendar: Bool?
    var isLinkedToReminders: Bool?
    var createdAt: Date?
    
    init(from session: Session) {
        self.rawText = session.rawText
        self.estimatedMinutes = session.estimatedMinutes
        self.actualMinutes = session.actualMinutes
        self.startedAt = session.startedAt
        self.endedAt = session.endedAt
        self.tempoResponse = session.tempoResponse
        self.tempoEndResponse = session.tempoEndResponse
        self.endCommandText = session.endCommandText
        self.isRetroactive = session.isRetroactive
        self.isScheduleQuery = session.isScheduleQuery
        self.schedulePayload = session.schedulePayload
        self.travelPayload = session.travelPayload
        self.isTravelQuery = session.isTravelQuery
        self.integrationSource = session.integrationSource
        self.linkedEventIdentifier = session.linkedEventIdentifier
        self.isLinkedToCalendar = session.isLinkedToCalendar
        self.isLinkedToReminders = session.isLinkedToReminders
        self.createdAt = session.createdAt
    }
    
    func toSession() -> Session {
        let session = Session(
            rawText: rawText,
            estimatedMinutes: estimatedMinutes,
            startedAt: startedAt,
            tempoResponse: tempoResponse,
            tempoEndResponse: tempoEndResponse,
            endCommandText: endCommandText,
            isRetroactive: isRetroactive,
            isScheduleQuery: isScheduleQuery,
            schedulePayload: schedulePayload,
            travelPayload: travelPayload,
            isTravelQuery: isTravelQuery,
            integrationSource: integrationSource,
            linkedEventIdentifier: linkedEventIdentifier,
            isLinkedToCalendar: isLinkedToCalendar,
            isLinkedToReminders: isLinkedToReminders,
            createdAt: createdAt
        )
        session.actualMinutes = actualMinutes
        session.endedAt = endedAt
        return session
    }
}

enum TempoBackupManager {
    static func exportBackup(sessions: [Session]) -> URL? {
        let dtos = sessions.map { SessionDTO(from: $0) }
        let backup = TempoBackup(sessions: dtos)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(backup) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = formatter.string(from: Date())
        let filename = "Tempo_Backup_\(dateStr).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }
    
    static func importBackup(data: Data, context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var dtos: [SessionDTO] = []
        if let backup = try? decoder.decode(TempoBackup.self, from: data) {
            dtos = backup.sessions
        } else if let array = try? decoder.decode([SessionDTO].self, from: data) {
            dtos = array
        } else {
            throw NSError(
                domain: "TempoBackup",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid backup format. Expected a valid Tempo JSON file."]
            )
        }
        
        guard !dtos.isEmpty else {
            throw NSError(
                domain: "TempoBackup",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Backup file contains no sessions."]
            )
        }
        
        for dto in dtos {
            let session = dto.toSession()
            context.insert(session)
        }
        
        try context.save()
        return dtos.count
    }
}

