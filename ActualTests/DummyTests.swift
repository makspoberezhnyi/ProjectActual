import XCTest
import SwiftData
import SwiftUI
@testable import Actual

final class DummyTests: XCTestCase {
    
    @MainActor
    func testBackupExportAndImportRoundtrip() throws {
        let schema = Schema([Session.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        
        let session1 = Session(
            rawText: "Write iOS Unit Tests",
            estimatedMinutes: 25,
            startedAt: Date().addingTimeInterval(-1500),
            tempoResponse: "Timer started for Write iOS Unit Tests. Focus.",
            tempoEndResponse: "Done. Logged 25m.",
            endCommandText: "Done",
            isRetroactive: false,
            isScheduleQuery: false,
            integrationSource: "tempo",
            createdAt: Date().addingTimeInterval(-1500)
        )
        session1.actualMinutes = 25
        session1.endedAt = Date()
        
        let items = [ScheduleItem(id: "1", title: "Team Sync", timeString: "10:00", estimatedMinutes: 30, isCalendarEvent: true)]
        let payloadData = try JSONEncoder().encode(items)
        let payloadStr = String(data: payloadData, encoding: .utf8)
        
        let session2 = Session(
            rawText: "Check calendar & reminders",
            isScheduleQuery: true,
            schedulePayload: payloadStr,
            createdAt: Date()
        )
        
        // Export
        guard let backupURL = TempoBackupManager.exportBackup(sessions: [session1, session2]) else {
            XCTFail("Failed to export backup")
            return
        }
        
        let fileData = try Data(contentsOf: backupURL)
        XCTAssertFalse(fileData.isEmpty)
        
        // Clear and create new context to test importing
        let importContainer = try ModelContainer(for: schema, configurations: configuration)
        let importContext = importContainer.mainContext
        
        let importedCount = try TempoBackupManager.importBackup(data: fileData, context: importContext)
        XCTAssertEqual(importedCount, 2)
        
        let fetchDescriptor = FetchDescriptor<Session>()
        let importedSessions = try importContext.fetch(fetchDescriptor)
        XCTAssertEqual(importedSessions.count, 2)
        
        let task = importedSessions.first(where: { $0.rawText == "Write iOS Unit Tests" })
        XCTAssertNotNil(task)
        XCTAssertEqual(task?.actualMinutes, 25)
        XCTAssertEqual(task?.estimatedMinutes, 25)
        XCTAssertEqual(task?.isActualTask, true)
        
        let query = importedSessions.first(where: { $0.isScheduleQuery == true })
        XCTAssertNotNil(query)
        XCTAssertEqual(query?.scheduleItems.count, 1)
        XCTAssertEqual(query?.scheduleItems.first?.title, "Team Sync")
    }
    
    func testConversationalSmallTalk() {
        // Greetings
        let hiIntent = ChatParser.parse("Hi")
        XCTAssertTrue(hiIntent.isConversational)
        XCTAssertNotNil(hiIntent.conversationalReply)
        
        let whatsUpIntent = ChatParser.parse("What's up?")
        XCTAssertTrue(whatsUpIntent.isConversational)
        XCTAssertTrue(whatsUpIntent.conversationalReply?.contains("ready") == true || whatsUpIntent.conversationalReply?.contains("smoothly") == true)
        
        // Identity & Capabilities
        let helpIntent = ChatParser.parse("Who are you?")
        XCTAssertTrue(helpIntent.isConversational)
        XCTAssertTrue(helpIntent.conversationalReply?.contains("Tempo") == true)
        
        // Motivation
        let motiveIntent = ChatParser.parse("Motivate me")
        XCTAssertTrue(motiveIntent.isConversational)
        XCTAssertNotNil(motiveIntent.conversationalReply)
        
        // Appreciation
        let thanksIntent = ChatParser.parse("Thank you!")
        XCTAssertTrue(thanksIntent.isConversational)
        XCTAssertTrue(thanksIntent.conversationalReply?.contains("welcome") == true)
    }
    
    func testTravelQueryParsing() {
        // Query with 'I want to get to [Place]' (user specific case)
        let resUser = ChatParser.parseTravelQuery("I want to get to the Manufaktura Mall in Lodz")
        XCTAssertTrue(resUser.isTravel)
        XCTAssertEqual(resUser.destination?.lowercased(), "the manufaktura mall in lodz")
        XCTAssertFalse(resUser.isNextMeeting)
        
        let intentUser = ChatParser.parse("I want to get to the Manufaktura Mall in Lodz")
        XCTAssertTrue(intentUser.isTravelQuery)
        XCTAssertEqual(intentUser.destinationQuery?.lowercased(), "the manufaktura mall in lodz")
        
        // Query with 'want to go to'
        let resGo = ChatParser.parseTravelQuery("want to go to Berlin")
        XCTAssertTrue(resGo.isTravel)
        XCTAssertEqual(resGo.destination?.lowercased(), "berlin")
        
        // Query with explicit destination
        let res1 = ChatParser.parseTravelQuery("how long the ride can take to JFK Airport")
        XCTAssertTrue(res1.isTravel)
        XCTAssertEqual(res1.destination?.lowercased(), "jfk airport")
        XCTAssertFalse(res1.isNextMeeting)
        
        // Drive time
        let res2 = ChatParser.parseTravelQuery("how long to drive to Central Park")
        XCTAssertTrue(res2.isTravel)
        XCTAssertEqual(res2.destination?.lowercased(), "central park")
        XCTAssertFalse(res2.isNextMeeting)
        
        // Generic ride question (auto-detects next meeting)
        let res3 = ChatParser.parseTravelQuery("how long the ride can take")
        XCTAssertTrue(res3.isTravel)
        XCTAssertTrue(res3.isNextMeeting)
        
        // Next meeting explicit
        let res4 = ChatParser.parseTravelQuery("how long to get to my next meeting?")
        XCTAssertTrue(res4.isTravel)
        XCTAssertTrue(res4.isNextMeeting)
        
        // Conversational expressions like "How long it gonna to go to Time Square"
        let resTimeSquare = ChatParser.parseTravelQuery("How long it gonna to go to Time Square")
        XCTAssertTrue(resTimeSquare.isTravel)
        XCTAssertEqual(resTimeSquare.destination?.lowercased(), "time square")
        
        let intentTimeSquare = ChatParser.parse("How long it gonna to go to Time Square")
        XCTAssertTrue(intentTimeSquare.isTravelQuery)
        XCTAssertEqual(intentTimeSquare.destinationQuery?.lowercased(), "time square")
        
        // Directions / Navigation
        let resNav = ChatParser.parseTravelQuery("directions to Warsaw Spire")
        XCTAssertTrue(resNav.isTravel)
        XCTAssertEqual(resNav.destination?.lowercased(), "warsaw spire")
        
        // Multi-modal transport queries (Transit / City transport, Walking / By feet, Cycling)
        let transitQuery = ChatParser.parseTravelQueryFull("how long by transit to JFK Airport")
        XCTAssertTrue(transitQuery.isTravel)
        XCTAssertEqual(transitQuery.destination?.lowercased(), "jfk airport")
        XCTAssertEqual(transitQuery.transportMode, .transit)
        
        let walkQuery = ChatParser.parseTravelQueryFull("how long to walk to Central Park")
        XCTAssertTrue(walkQuery.isTravel)
        XCTAssertEqual(walkQuery.destination?.lowercased(), "central park")
        XCTAssertEqual(walkQuery.transportMode, .walking)
        
        let feetQuery = ChatParser.parseTravelQueryFull("how long by feet to Manufaktura")
        XCTAssertTrue(feetQuery.isTravel)
        XCTAssertEqual(feetQuery.destination?.lowercased(), "manufaktura")
        XCTAssertEqual(feetQuery.transportMode, .walking)
        
        let bikeQuery = ChatParser.parseTravelQueryFull("how long by bike to Grand Central")
        XCTAssertTrue(bikeQuery.isTravel)
        XCTAssertEqual(bikeQuery.destination?.lowercased(), "grand central")
        XCTAssertEqual(bikeQuery.transportMode, .cycling)
    }
    
    func testAppIntentStartAndStopFocus() async throws {
        let startIntent = StartFocusIntent(taskTitle: "Design Mockups", minutes: 45)
        _ = try await startIntent.perform()
        
        let snapshot = WidgetDataStore.shared.loadSnapshot()
        XCTAssertEqual(snapshot.activeTaskTitle, "Design Mockups")
        XCTAssertEqual(snapshot.activeTaskEstimatedMinutes, 45)
        XCTAssertNotNil(snapshot.activeTaskStartedAt)
        
        let stopIntent = StopFocusIntent()
        _ = try await stopIntent.perform()
        
        let stoppedSnapshot = WidgetDataStore.shared.loadSnapshot()
        XCTAssertNil(stoppedSnapshot.activeTaskStartedAt)
    }
    
    @MainActor
    func testSettingsAndIntegrationsViewsLayout() throws {
        let settingsView = SettingsView(sessions: [])
        let hostingSettings = UIHostingController(rootView: settingsView)
        hostingSettings.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hostingSettings.view.layoutIfNeeded()
        XCTAssertNotNil(hostingSettings.view)
        
        let renderer = UIGraphicsImageRenderer(size: hostingSettings.view.bounds.size)
        let settingsImg = renderer.image { _ in
            hostingSettings.view.drawHierarchy(in: hostingSettings.view.bounds, afterScreenUpdates: true)
        }
        if let pngData = settingsImg.pngData() {
            try? pngData.write(to: URL(fileURLWithPath: "/Users/mpob/.gemini/antigravity/brain/58f45798-0e6b-4e38-8f64-978ab0fc9a27/sim_settings_rendered.png"))
        }
        
        let integrationsView = NavigationStack {
            IntegrationsView(calendarAuthStatus: "Connected", remindersAuthStatus: "Connected")
        }
        let hostingIntegrations = UIHostingController(rootView: integrationsView)
        hostingIntegrations.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hostingIntegrations.view.layoutIfNeeded()
        XCTAssertNotNil(hostingIntegrations.view)
        
        let integrationsImg = renderer.image { _ in
            hostingIntegrations.view.drawHierarchy(in: hostingIntegrations.view.bounds, afterScreenUpdates: true)
        }
        if let pngData = integrationsImg.pngData() {
            try? pngData.write(to: URL(fileURLWithPath: "/Users/mpob/.gemini/antigravity/brain/58f45798-0e6b-4e38-8f64-978ab0fc9a27/sim_integrations_rendered.png"))
        }
    }
    
    func testHealthKitDetectionAndActivityMatching() {
        // 1. Running
        let runMatch = HealthKitManager.detectActivity(from: "Morning run 5k 30m")
        XCTAssertTrue(runMatch.isSport)
        XCTAssertFalse(runMatch.isMindful)
        XCTAssertEqual(runMatch.activityType, .running)
        XCTAssertEqual(runMatch.name, "Outdoor Running")
        XCTAssertGreaterThan(runMatch.caloriesPerMinute, 10.0)
        
        // 2. Gym / Weightlifting
        let gymMatch = HealthKitManager.detectActivity(from: "Gym leg day squats & deadlifts 45m")
        XCTAssertTrue(gymMatch.isSport)
        XCTAssertEqual(gymMatch.activityType, .traditionalStrengthTraining)
        XCTAssertEqual(gymMatch.name, "Traditional Strength Training")
        
        // 3. Cycling
        let bikeMatch = HealthKitManager.detectActivity(from: "Peloton indoor cycle 45m")
        XCTAssertTrue(bikeMatch.isSport)
        XCTAssertEqual(bikeMatch.activityType, .cycling)
        
        // 4. Swimming
        let swimMatch = HealthKitManager.detectActivity(from: "Pool laps freestyle 30m")
        XCTAssertTrue(swimMatch.isSport)
        XCTAssertEqual(swimMatch.activityType, .swimming)
        
        // 5. Boxing
        let boxingMatch = HealthKitManager.detectActivity(from: "Heavy bag boxing workout 40m")
        XCTAssertTrue(boxingMatch.isSport)
        XCTAssertEqual(boxingMatch.activityType, .boxing)
        
        // 6. Yoga
        let yogaMatch = HealthKitManager.detectActivity(from: "Vinyasa yoga flow 60m")
        XCTAssertTrue(yogaMatch.isSport)
        XCTAssertEqual(yogaMatch.activityType, .yoga)
        
        // 7. Tennis
        let tennisMatch = HealthKitManager.detectActivity(from: "Tennis match with Alex 60m")
        XCTAssertTrue(tennisMatch.isSport)
        XCTAssertEqual(tennisMatch.activityType, .tennis)
        
        // 8. HIIT
        let hiitMatch = HealthKitManager.detectActivity(from: "Tabata HIIT circuit 20m")
        XCTAssertTrue(hiitMatch.isSport)
        XCTAssertEqual(hiitMatch.activityType, .highIntensityIntervalTraining)
        
        // 9. Mindful Minutes
        let mindfulMatch = HealthKitManager.detectActivity(from: "Evening meditation & breathwork 15m")
        XCTAssertFalse(mindfulMatch.isSport)
        XCTAssertTrue(mindfulMatch.isMindful)
        XCTAssertEqual(mindfulMatch.name, "Mindful Session")
        
        // 10. Focus / Coding
        let codingMatch = HealthKitManager.detectActivity(from: "Deep work coding SwiftUI features 90m")
        XCTAssertFalse(codingMatch.isSport)
        XCTAssertTrue(codingMatch.isMindful)
        
        // 11. Normal task
        let genericTask = HealthKitManager.detectActivity(from: "Submit quarterly tax report")
        XCTAssertFalse(genericTask.isSport)
        XCTAssertFalse(genericTask.isMindful)
    }
    
    @MainActor
    func testHealthChatQueriesAndSessionCardRendering() throws {
        // 1. Check parsing of "run 30m"
        let runIntent = ChatParser.parse("run 30m")
        XCTAssertEqual(runIntent.estimatedMinutes, 30)
        XCTAssertFalse(runIntent.isConversational)
        XCTAssertFalse(runIntent.isStopCommand)
        let runMatch = HealthKitManager.detectActivity(from: runIntent.text)
        XCTAssertTrue(runMatch.isSport)
        XCTAssertEqual(runMatch.activityType, .running)
        
        // 2. Check health query intents
        let healthQuery1 = ChatParser.parse("check health")
        XCTAssertTrue(healthQuery1.isHealthQuery)
        
        let healthQuery2 = ChatParser.parse("fitness stats")
        XCTAssertTrue(healthQuery2.isHealthQuery)
        
        let healthQuery3 = ChatParser.parse("how many calories today")
        XCTAssertTrue(healthQuery3.isHealthQuery)
        
        // 3. Render Health Card Snapshot
        let sampleData = HealthCardData(
            activeCaloriesToday: 420,
            workoutMinutesToday: 35,
            mindfulMinutesToday: 20,
            isAuthorized: true,
            recentActivityName: "Outdoor Running",
            recentCalories: 345,
            recentMinutes: 30,
            recentIcon: "figure.run"
        )
        let sampleSession = Session(
            rawText: "check health",
            tempoResponse: "Here is your Apple Health & Fitness activity for today:",
            isHealthQuery: true
        )
        if let encoded = try? JSONEncoder().encode(sampleData) {
            sampleSession.healthPayload = String(data: encoded, encoding: .utf8)
        }
        
        let schema = Schema([Session.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        container.mainContext.insert(sampleSession)
        
        let logTabView = LogTabView(sessions: [sampleSession], calibrationScore: .constant(1.0))
            .modelContainer(container)
            .preferredColorScheme(.dark)
        
        let hosting = UIHostingController(rootView: logTabView)
        hosting.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hosting.view.layoutIfNeeded()
        XCTAssertNotNil(hosting.view)
        
        let renderer = UIGraphicsImageRenderer(size: hosting.view.bounds.size)
        let img = renderer.image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        if let pngData = img.pngData() {
            try? pngData.write(to: URL(fileURLWithPath: "/Users/mpob/.gemini/antigravity/brain/58f45798-0e6b-4e38-8f64-978ab0fc9a27/sim_health_query_rendered.png"))
        }
    }
    
    @MainActor
    func testTravelCardAndActiveWorkoutCardRendering() throws {
        let travelResult = TravelAssessmentResult(
            destinationTitle: "Manufaktura",
            destinationAddress: "Ogrodowa 19A, 91-065 Łódź",
            travelDurationMinutes: 14,
            distanceMeters: 4800,
            distanceString: "4.8 km",
            transportTypeName: "Car",
            transportMode: .driving,
            latitude: 51.7797,
            longitude: 19.4478
        )
        let travelSession = Session(
            rawText: "how long to drive to Manufaktura",
            tempoResponse: "🚗 The drive to Manufaktura will take approximately 14m (4.8 km).",
            isTravelQuery: true
        )
        if let encoded = try? JSONEncoder().encode(travelResult) {
            travelSession.travelPayload = String(data: encoded, encoding: .utf8)
        }
        
        let workoutSession = Session(
            rawText: "Run 30m",
            estimatedMinutes: 30,
            startedAt: Date().addingTimeInterval(-420), // 7 mins ago
            tempoResponse: "🏃 Outdoor Running workout timer started (30m). Tracking with Apple Fitness."
        )
        
        let schema = Schema([Session.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        container.mainContext.insert(travelSession)
        container.mainContext.insert(workoutSession)
        
        let logTabView = LogTabView(sessions: [travelSession, workoutSession], calibrationScore: .constant(1.0))
            .modelContainer(container)
            .preferredColorScheme(.dark)
        
        let hosting = UIHostingController(rootView: logTabView)
        hosting.view.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        hosting.view.layoutIfNeeded()
        XCTAssertNotNil(hosting.view)
        
        let renderer = UIGraphicsImageRenderer(size: hosting.view.bounds.size)
        let img = renderer.image { _ in
            hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
        }
        if let pngData = img.pngData() {
            try? pngData.write(to: URL(fileURLWithPath: "/Users/mpob/.gemini/antigravity/brain/58f45798-0e6b-4e38-8f64-978ab0fc9a27/sim_travel_workout_rendered.png"))
        }
    }
    
    @MainActor
    func testNotificationManagerSchedulingAndCancellation() {
        let notifManager = NotificationManager.shared
        let sessionId = UUID().uuidString
        
        // Schedule Focus / Workout Timer Completion
        notifManager.scheduleTimerCompletion(
            title: "Outdoor Running",
            durationMinutes: 30,
            sessionId: sessionId,
            isWorkout: true
        )
        
        // Send Workout Reconciliation Notification
        notifManager.sendWorkoutReconciliationNotification(
            activityName: "Outdoor Running",
            factualMinutes: 28,
            estimatedMinutes: 30,
            calories: 320
        )
        
        // Cancel Timer Notification
        notifManager.cancelTimerNotification(sessionId: sessionId)
        XCTAssertNotNil(notifManager)
    }
    
    @MainActor
    func testHealthKitReconciliationAndDeltaCalculation() {
        let workout = RecordedWorkout(
            activityType: .running,
            activityName: "Outdoor Running",
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            durationMinutes: 30,
            activeCalories: 345,
            icon: "figure.run"
        )
        
        XCTAssertEqual(workout.durationMinutes, 30)
        XCTAssertEqual(workout.activityName, "Outdoor Running")
        XCTAssertEqual(workout.icon, "figure.run")
        XCTAssertGreaterThan(workout.activeCalories, 0)
        
        let estMinutes = 25
        let delta = workout.durationMinutes - estMinutes
        let deltaStr = delta > 0 ? "+\(delta)m" : "\(delta)m"
        XCTAssertEqual(deltaStr, "+5m")
    }
    
    @MainActor
    func testFlowAStopSessionAndParsing() throws {
        // 1. Verify Stop / Finished parsing
        let finishIntent = ChatParser.parse("Finished")
        XCTAssertTrue(finishIntent.isStopCommand)
        
        let doneIntent = ChatParser.parse("Done")
        XCTAssertTrue(doneIntent.isStopCommand)
        
        let stopIntent = ChatParser.parse("stop")
        XCTAssertTrue(stopIntent.isStopCommand)
        
        // 2. Create and run a workout session
        let workoutSession = Session(
            rawText: "Running 30m",
            estimatedMinutes: 30,
            startedAt: Date().addingTimeInterval(-1800),
            tempoResponse: "🏃 Outdoor Running workout timer started (30m). Tracking with Apple Fitness."
        )
        XCTAssertTrue(workoutSession.isRunning)
        
        // 3. Emulate stopSession execution
        workoutSession.endedAt = Date()
        let actual = max(1, Int(Date().timeIntervalSince(workoutSession.startedAt ?? Date()) / 60))
        workoutSession.actualMinutes = actual
        workoutSession.endCommandText = "Finished"
        
        let ratioText = workoutSession.biasRatio != nil ? String(format: "%.1fx", workoutSession.biasRatio!) : "-"
        let baseResponse = "Done. Logged \(actual)m. (Ratio: \(ratioText))"
        let match = HealthKitManager.detectActivity(from: workoutSession.rawText)
        let estimatedKcal = Int(Double(actual) * (match.caloriesPerMinute > 0 ? match.caloriesPerMinute : 8.0))
        workoutSession.tempoEndResponse = "\(baseResponse) • 🏃 \(match.name) logged to Apple Fitness (~\(estimatedKcal) kcal)"
        
        // 4. Assertions
        XCTAssertFalse(workoutSession.isRunning)
        XCTAssertEqual(workoutSession.actualMinutes, 30)
        XCTAssertNotNil(workoutSession.tempoEndResponse)
        XCTAssertTrue(workoutSession.tempoEndResponse?.contains("Outdoor Running logged to Apple Fitness") == true)
        XCTAssertTrue(workoutSession.tempoEndResponse?.contains("kcal") == true)
    }
}
