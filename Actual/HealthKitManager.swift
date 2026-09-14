import Foundation
import HealthKit
import SwiftUI

public struct HealthWorkoutMatch: Sendable {
    public let isSport: Bool
    public let isMindful: Bool
    public let activityType: HKWorkoutActivityType?
    public let name: String
    public let icon: String
    public let caloriesPerMinute: Double
}

public struct RecordedWorkout: Identifiable, Sendable {
    public var id: UUID
    public var activityType: HKWorkoutActivityType
    public var activityName: String
    public var startDate: Date
    public var endDate: Date
    public var durationMinutes: Int
    public var activeCalories: Double
    public var icon: String
    
    public init(
        id: UUID = UUID(),
        activityType: HKWorkoutActivityType,
        activityName: String,
        startDate: Date,
        endDate: Date,
        durationMinutes: Int,
        activeCalories: Double,
        icon: String
    ) {
        self.id = id
        self.activityType = activityType
        self.activityName = activityName
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.activeCalories = activeCalories
        self.icon = icon
    }
}

@Observable
public final class HealthKitManager: @unchecked Sendable {
    public static let shared = HealthKitManager()
    
    public let healthStore: HKHealthStore?
    public var isAuthorized: Bool = false
    public var authStatusDescription: String = "Not Connected"
    
    public var todayActiveCalories: Double = 0
    public var todayWorkoutMinutes: Int = 0
    public var todayMindfulMinutes: Int = 0
    
    private var workoutObserverQuery: HKObserverQuery?
    private var lastObservedWorkoutDate: Date = Date().addingTimeInterval(-3600)
    
    public init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
        }
    }
    
    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // MARK: - Activity Detection
    public static func detectActivity(from rawText: String) -> HealthWorkoutMatch {
        let text = rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Running & Sprinting
        if text.contains("running") || text.contains("run") || text.contains("jog") || text.contains("sprint") || text.contains("treadmill") || text.contains("5k") || text.contains("10k") || text.contains("marathon") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .running,
                name: "Outdoor Running",
                icon: "figure.run",
                caloriesPerMinute: 11.5
            )
        }
        
        // 2. Cycling & Biking
        if text.contains("cycling") || text.contains("cycle") || text.contains("bike") || text.contains("biking") || text.contains("peloton") || text.contains("spin") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .cycling,
                name: "Cycling",
                icon: "figure.outdoor.cycle",
                caloriesPerMinute: 9.0
            )
        }
        
        // 3. Swimming
        if text.contains("swimming") || text.contains("swim") || text.contains("pool") || text.contains("laps") || text.contains("freestyle") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .swimming,
                name: "Pool Swimming",
                icon: "figure.pool.swim",
                caloriesPerMinute: 10.0
            )
        }
        
        // 4. Traditional Strength & Gym
        if text.contains("gym") || text.contains("lifting") || text.contains("lift") || text.contains("weightlifting") || text.contains("weights") || text.contains("strength") || text.contains("dumbbell") || text.contains("barbell") || text.contains("bench") || text.contains("squat") || text.contains("deadlift") || text.contains("push day") || text.contains("pull day") || text.contains("leg day") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .traditionalStrengthTraining,
                name: "Traditional Strength Training",
                icon: "figure.strengthtraining.traditional",
                caloriesPerMinute: 7.5
            )
        }
        
        // 5. Functional & Calisthenics
        if text.contains("calisthenics") || text.contains("functional") || text.contains("crossfit") || text.contains("bodyweight") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .functionalStrengthTraining,
                name: "Functional Strength Training",
                icon: "figure.strengthtraining.functional",
                caloriesPerMinute: 8.0
            )
        }
        
        // 6. HIIT & Circuit
        if text.contains("hiit") || text.contains("interval") || text.contains("tabata") || text.contains("circuit") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .highIntensityIntervalTraining,
                name: "High Intensity Interval Training",
                icon: "figure.hiit",
                caloriesPerMinute: 11.0
            )
        }
        
        // 7. Boxing & Kickboxing
        if text.contains("boxing") || text.contains("box") || text.contains("kickboxing") || text.contains("heavy bag") || text.contains("sparring") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .boxing,
                name: "Boxing",
                icon: "figure.boxing",
                caloriesPerMinute: 11.0
            )
        }
        
        // 8. Martial Arts
        if text.contains("martial arts") || text.contains("karate") || text.contains("bjj") || text.contains("jiu jitsu") || text.contains("judo") || text.contains("taekwondo") || text.contains("mma") || text.contains("muay thai") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .martialArts,
                name: "Martial Arts",
                icon: "figure.martial.arts",
                caloriesPerMinute: 10.5
            )
        }
        
        // 9. Yoga
        if text.contains("yoga") || text.contains("vinyasa") || text.contains("ashtanga") || text.contains("yin yoga") || text.contains("hatha") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .yoga,
                name: "Yoga",
                icon: "figure.yoga",
                caloriesPerMinute: 4.5
            )
        }
        
        // 10. Pilates
        if text.contains("pilates") || text.contains("reformer") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .pilates,
                name: "Pilates",
                icon: "figure.pilates",
                caloriesPerMinute: 4.5
            )
        }
        
        // 11. Rowing
        if text.contains("rowing") || text.contains("row") || text.contains("erg") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .rowing,
                name: "Rowing",
                icon: "figure.rower",
                caloriesPerMinute: 9.0
            )
        }
        
        // 12. Tennis & Racket Sports
        if text.contains("tennis") || text.contains("squash") || text.contains("badminton") || text.contains("pickleball") || text.contains("padel") || text.contains("ping pong") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .tennis,
                name: "Tennis & Racket Sports",
                icon: "figure.tennis",
                caloriesPerMinute: 8.5
            )
        }
        
        // 13. Basketball
        if text.contains("basketball") || text.contains("hoops") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .basketball,
                name: "Basketball",
                icon: "figure.basketball",
                caloriesPerMinute: 8.5
            )
        }
        
        // 14. Soccer
        if text.contains("soccer") || text.contains("football match") || text.contains("kickabout") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .soccer,
                name: "Soccer",
                icon: "figure.soccer",
                caloriesPerMinute: 9.0
            )
        }
        
        // 15. Hiking
        if text.contains("hiking") || text.contains("hike") || text.contains("trek") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .hiking,
                name: "Hiking",
                icon: "figure.hiking",
                caloriesPerMinute: 6.5
            )
        }
        
        // 16. Walking
        if text.contains("walking") || text.contains("walk") || text.contains("stroll") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .walking,
                name: "Walking",
                icon: "figure.walk",
                caloriesPerMinute: 4.0
            )
        }
        
        // 17. Dance
        if text.contains("dance") || text.contains("dancing") || text.contains("zumba") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .cardioDance,
                name: "Dance",
                icon: "figure.dance",
                caloriesPerMinute: 6.5
            )
        }
        
        // 18. Climbing
        if text.contains("climbing") || text.contains("climb") || text.contains("bouldering") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .climbing,
                name: "Climbing",
                icon: "figure.climbing",
                caloriesPerMinute: 8.0
            )
        }
        
        // 19. Generic Workout
        if text.contains("workout") || text.contains("exercise") || text.contains("training") || text.contains("fitness") || text.contains("cardio") {
            return HealthWorkoutMatch(
                isSport: true,
                isMindful: false,
                activityType: .fitnessGaming,
                name: "Fitness Workout",
                icon: "figure.cross.training",
                caloriesPerMinute: 7.0
            )
        }
        
        // 20. Mindful / Meditation / Breathing / Focus
        if text.contains("meditat") || text.contains("mindful") || text.contains("breath") || text.contains("pranayama") || text.contains("calm") || text.contains("deep work") || text.contains("focus") || text.contains("study") || text.contains("reading") || text.contains("coding") {
            return HealthWorkoutMatch(
                isSport: false,
                isMindful: true,
                activityType: nil,
                name: "Mindful Session",
                icon: "figure.mind.and.body",
                caloriesPerMinute: 0.0
            )
        }
        
        // Default standard session
        return HealthWorkoutMatch(
            isSport: false,
            isMindful: false,
            activityType: nil,
            name: "Focus Session",
            icon: "timer",
            caloriesPerMinute: 0.0
        )
    }
    
    public static func metadata(for activityType: HKWorkoutActivityType) -> (name: String, icon: String) {
        switch activityType {
        case .running: return ("Running", "figure.run")
        case .cycling: return ("Cycling", "figure.outdoor.cycle")
        case .walking: return ("Walking", "figure.walk")
        case .swimming: return ("Swimming", "figure.pool.swim")
        case .traditionalStrengthTraining, .functionalStrengthTraining: return ("Strength Training", "figure.strengthtraining.traditional")
        case .highIntensityIntervalTraining: return ("HIIT", "figure.hiit")
        case .hiking: return ("Hiking", "figure.hiking")
        case .yoga: return ("Yoga", "figure.yoga")
        case .pilates: return ("Pilates", "figure.pilates")
        case .rowing: return ("Rowing", "figure.rower")
        case .tennis: return ("Tennis", "figure.tennis")
        case .boxing, .martialArts: return ("Boxing / Martial Arts", "figure.boxing")
        default: return ("Workout", "figure.cross.training")
        }
    }
    
    // MARK: - Authorization
    public func requestAuthorization() async -> Bool {
        guard let store = healthStore else {
            await MainActor.run {
                self.authStatusDescription = "Unavailable"
                self.isAuthorized = false
            }
            return false
        }
        
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            return false
        }
        
        let typesToShare: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            energyType,
            mindfulType
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            energyType,
            mindfulType
        ]
        
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            await MainActor.run {
                self.isAuthorized = true
                self.authStatusDescription = "Connected"
            }
            await refreshTodayStats()
            return true
        } catch {
            await MainActor.run {
                self.isAuthorized = false
                self.authStatusDescription = "Not Connected"
            }
            return false
        }
    }
    
    // MARK: - Save Workout
    public func saveWorkout(
        activityType: HKWorkoutActivityType,
        title: String,
        start: Date,
        end: Date,
        durationMinutes: Int,
        caloriesPerMinute: Double
    ) async -> (success: Bool, calories: Double, message: String) {
        guard let store = healthStore else {
            return (false, 0, "HealthKit unavailable")
        }
        
        let actualMins = max(1, durationMinutes)
        let calculatedCalories = max(10.0, Double(actualMins) * caloriesPerMinute)
        let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calculatedCalories)
        
        let validStart = min(start, end.addingTimeInterval(-1))
        let validEnd = max(end, validStart.addingTimeInterval(1))
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        configuration.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        
        do {
            try await builder.beginCollection(at: validStart)
            
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let sample = HKQuantitySample(
                    type: energyType,
                    quantity: energyQuantity,
                    start: validStart,
                    end: validEnd,
                    metadata: [HKMetadataKeyWorkoutBrandName: "Tempo"]
                )
                try await builder.addSamples([sample])
            }
            
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Tempo",
                HKMetadataKeyIndoorWorkout: NSNumber(value: false)
            ])
            
            try await builder.endCollection(at: validEnd)
            _ = try await builder.finishWorkout()
            
            await refreshTodayStats()
            return (true, calculatedCalories, "Logged \(actualMins)m \(title) to Apple Fitness (~\(Int(calculatedCalories)) kcal)")
        } catch {
            return (false, calculatedCalories, "Logged \(actualMins)m \(title) (~\(Int(calculatedCalories)) kcal)")
        }
    }
    
    // MARK: - Save Mindful Session
    public func saveMindfulSession(
        start: Date,
        end: Date,
        durationMinutes: Int
    ) async -> (success: Bool, message: String) {
        guard let store = healthStore,
              let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            return (false, "HealthKit mindful tracking unavailable")
        }
        
        let validStart = min(start, end.addingTimeInterval(-1))
        let validEnd = max(end, validStart.addingTimeInterval(1))
        
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: validStart,
            end: validEnd,
            metadata: [
                HKMetadataKeyWorkoutBrandName: "Tempo"
            ]
        )
        
        do {
            try await store.save(sample)
            await refreshTodayStats()
            return (true, "Logged \(durationMinutes) mindful minutes to Apple Health")
        } catch {
            return (false, "Saved \(durationMinutes)m mindful focus")
        }
    }
    
    // MARK: - Fetch Recent Completed Workouts from HealthKit
    public func fetchRecentWorkouts(since: Date) async -> [RecordedWorkout] {
        guard let store = healthStore else { return [] }
        
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: 10,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results: [RecordedWorkout] = workouts.compactMap { workout in
                    let meta = Self.metadata(for: workout.workoutActivityType)
                    let durationMins = max(1, Int(workout.duration / 60))
                    let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
                    let cals: Double
                    if let energyType, let sum = workout.statistics(for: energyType)?.sumQuantity() {
                        cals = sum.doubleValue(for: .kilocalorie())
                    } else if let totalEnergy = workout.totalEnergyBurned {
                        cals = totalEnergy.doubleValue(for: .kilocalorie())
                    } else {
                        cals = Double(durationMins) * 7.5
                    }
                    
                    return RecordedWorkout(
                        id: workout.uuid,
                        activityType: workout.workoutActivityType,
                        activityName: meta.name,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        durationMinutes: durationMins,
                        activeCalories: cals,
                        icon: meta.icon
                    )
                }
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }
    
    // MARK: - Start HealthKit Workout Observer
    public func startWorkoutObserver(onNewWorkout: @Sendable @escaping (RecordedWorkout) -> Void) {
        guard let store = healthStore else { return }
        
        if let existing = workoutObserverQuery {
            store.stop(existing)
        }
        
        let observer = HKObserverQuery(sampleType: HKWorkoutType.workoutType(), predicate: nil) { [weak self] _, completionHandler, error in
            guard let self = self, error == nil else {
                completionHandler()
                return
            }
            
            Task {
                let checkSince = self.lastObservedWorkoutDate
                let newWorkouts = await self.fetchRecentWorkouts(since: checkSince)
                if let latest = newWorkouts.first {
                    self.lastObservedWorkoutDate = latest.endDate
                    onNewWorkout(latest)
                }
                completionHandler()
            }
        }
        
        self.workoutObserverQuery = observer
        store.execute(observer)
        
        store.enableBackgroundDelivery(for: HKWorkoutType.workoutType(), frequency: .immediate) { _, _ in }
    }
    
    // MARK: - Fetch Today Stats
    public func refreshTodayStats() async {
        guard let store = healthStore else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 1. Fetch Active Calories Today
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyQuery = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                if let sum = result?.sumQuantity() {
                    let cals = sum.doubleValue(for: .kilocalorie())
                    Task { @MainActor in
                        self.todayActiveCalories = cals
                    }
                }
            }
            store.execute(energyQuery)
        }
        
        // 2. Fetch Workouts Today
        let workoutsQuery = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, _ in
            if let workouts = samples as? [HKWorkout] {
                let totalSecs = workouts.reduce(0) { $0 + $1.duration }
                Task { @MainActor in
                    self.todayWorkoutMinutes = Int(totalSecs / 60)
                }
            }
        }
        store.execute(workoutsQuery)
    }
    
    // MARK: - Health Card Data
    public func fetchTodayHealthCardData(recentActivityText: String? = nil, recentMinutes: Int? = nil) async -> HealthCardData {
        await refreshTodayStats()
        
        var matchName: String? = nil
        var matchCals: Double? = nil
        var matchMins: Int? = recentMinutes
        var matchIcon: String? = nil
        
        if let text = recentActivityText {
            let match = HealthKitManager.detectActivity(from: text)
            if match.isSport {
                matchName = match.name
                matchIcon = match.icon
                let mins = recentMinutes ?? 30
                matchMins = mins
                matchCals = max(10, Double(mins) * match.caloriesPerMinute)
            } else if match.isMindful {
                matchName = match.name
                matchIcon = match.icon
                matchMins = recentMinutes ?? 15
            }
        }
        
        return HealthCardData(
            activeCaloriesToday: max(todayActiveCalories, matchCals ?? 0),
            workoutMinutesToday: max(todayWorkoutMinutes, (matchName != nil && matchCals != nil) ? (matchMins ?? 0) : 0),
            mindfulMinutesToday: todayMindfulMinutes,
            isAuthorized: isAuthorized || HKHealthStore.isHealthDataAvailable(),
            recentActivityName: matchName,
            recentCalories: matchCals,
            recentMinutes: matchMins,
            recentIcon: matchIcon
        )
    }
    
    public func openFitnessApp() {
        if let url = URL(string: "fitnessapp://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let healthUrl = URL(string: "x-apple-health://"), UIApplication.shared.canOpenURL(healthUrl) {
            UIApplication.shared.open(healthUrl)
        }
    }
}

public struct HealthCardData: Codable, Hashable, Sendable {
    public var activeCaloriesToday: Double
    public var workoutMinutesToday: Int
    public var mindfulMinutesToday: Int
    public var isAuthorized: Bool
    public var recentActivityName: String?
    public var recentCalories: Double?
    public var recentMinutes: Int?
    public var recentIcon: String?
    
    public init(
        activeCaloriesToday: Double = 0,
        workoutMinutesToday: Int = 0,
        mindfulMinutesToday: Int = 0,
        isAuthorized: Bool = true,
        recentActivityName: String? = nil,
        recentCalories: Double? = nil,
        recentMinutes: Int? = nil,
        recentIcon: String? = nil
    ) {
        self.activeCaloriesToday = activeCaloriesToday
        self.workoutMinutesToday = workoutMinutesToday
        self.mindfulMinutesToday = mindfulMinutesToday
        self.isAuthorized = isAuthorized
        self.recentActivityName = recentActivityName
        self.recentCalories = recentCalories
        self.recentMinutes = recentMinutes
        self.recentIcon = recentIcon
    }
}
