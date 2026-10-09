import Foundation
import SwiftUI

// MARK: - Tempo UX Copy Architecture
/// Centralized, type-safe UX copy system across iOS, watchOS, Widgets, and Live Activities.
public enum TempoUXCopy {
    
    // MARK: - Chat & Assistant
    public enum Chat {
        public static let emptyStateGreeting = "What are you focusing on next?"
        public static let returningTodayGreeting = "Welcome back. What's on your mind?"
        public static let typingIndicator = "Thinking..."
        
        public static func proactiveRoutinePrompt(title: String, minutes: Int) -> String {
            "Ready for your usual \(title) (\(minutes)m)?"
        }
        
        public static func morningGreeting(name: String? = nil) -> String {
            if let name = name, !name.isEmpty {
                return "Good morning, \(name). What's on your focus list today?"
            }
            return "Good morning. What are we tackling first?"
        }
        
        public static func afternoonGreeting() -> String {
            "Good afternoon. Ready to keep the momentum going?"
        }
        
        public static func eveningGreeting() -> String {
            "Good evening. Ready for your evening wind-down or final focus block?"
        }
        
        public static let defaultQuickActions = [
            "Check calendar & reminders",
            "Deep Work (25m)",
            "Ride to Airport?"
        ]
        
        public static let identityHelpText = """
        I'm **Tempo** — your ambient focus & time calibration companion.
        
        ⏱ **Focus Timers**: Type a task with a duration (e.g. *"Design mockups for 30m"*) to start a session.
        📅 **Calendar & Tasks**: Type *"Check my schedule"* to see your upcoming events and to-dos.
        🚗 **Travel Time**: Ask *"How long is the ride to the airport?"* for real-time traffic ETAs.
        📊 **Calibration**: I learn your focus velocity over time to eliminate planning bias.
        """
    }
    
    // MARK: - Session Configuration & Flow
    public enum Session {
        public static let estimatePrompt = "How long will this take?"
        public static let customDurationPlaceholder = "Custom minutes"
        
        public static let startAction = "Start Focus"
        public static let startNow = "Start Now"
        public static let pauseAction = "Pause"
        public static let resumeAction = "Resume"
        public static let completeAction = "Complete"
        public static let cancelAction = "Cancel"
        public static let editEstimate = "Edit Estimate"
        public static let addNotes = "Add reflection..."
        
        public static let stateInFlow = "In Flow"
        public static let statePaused = "Paused"
        public static let stateCompleted = "Session Completed"
        
        public static func elapsedString(minutes: Int) -> String {
            "\(minutes)m elapsed"
        }
        
        public static func remainingString(minutes: Int) -> String {
            "\(minutes)m remaining"
        }
        
        public static func overtimeString(minutes: Int) -> String {
            "+\(minutes)m over estimate"
        }
    }
    
    // MARK: - Calibration Feedback
    public enum Calibration {
        public static let reflectionHeader = "How did this session feel?"
        
        public static let feelingEnergized = "Energized"
        public static let feelingFocused = "Focused"
        public static let feelingFatigued = "Fatigued"
        
        public static func feedback(estimated: Int, actual: Int) -> String {
            let diff = actual - estimated
            let tolerance = max(2, Int(Double(estimated) * 0.15))
            
            if abs(diff) <= tolerance {
                return "Spot on — estimated \(estimated)m, finished in \(actual)m."
            } else if diff > tolerance {
                return "Deep in flow — took \(actual)m on a \(estimated)m estimate."
            } else {
                return "Finished early — wrapped up in \(actual)m (\(estimated)m estimated)."
            }
        }
        
        public static func accuracyScoreSummary(percentage: Int) -> String {
            "Your planning accuracy is at \(percentage)%. Every session sharpens your time calibration."
        }
    }
    
    // MARK: - Live Activities & Dynamic Island
    public enum LiveActivity {
        public static let compactPrefix = "●"
        public static let inFlowHeader = "In Flow"
        public static let pausedHeader = "Paused"
        public static let finishedHeader = "Done"
        
        public static func dynamicIslandExpandedTitle(taskTitle: String) -> String {
            taskTitle.isEmpty ? "Focus Session" : taskTitle
        }
        
        public static func dynamicIslandSubtitle(remainingMinutes: Int, isOvertime: Bool) -> String {
            if isOvertime {
                return "+\(remainingMinutes)m in the zone"
            } else {
                return "\(remainingMinutes)m remaining"
            }
        }
    }
    
    // MARK: - Glanceable Widgets
    public enum Widgets {
        public static let idleTitle = "Ready to Focus"
        public static let idleSubtitle = "Tap to launch a session"
        public static let activeSessionPrefix = "●"
        public static let noUpcomingEvents = "No upcoming events"
        public static let lockScreenPlaceholder = "Tempo Focus"
    }
    
    // MARK: - Apple Watch
    public enum Watch {
        public static let appName = "Tempo"
        public static let readyToStart = "Ready to Start"
        public static let quickRoutinesHeader = "Routines"
        public static let endSessionButton = "End Session"
        public static let sessionActiveHeader = "In Progress"
        public static let sessionCompleted = "Session Completed"
        public static let syncedToPhone = "Synced to iPhone"
    }
    
    // MARK: - Permissions & Integrations
    public enum Permissions {
        public static let calendarTitle = "Apple Calendar"
        public static let calendarDescription = "Suggests focus blocks and travel buffers between your scheduled events."
        
        public static let remindersTitle = "Apple Reminders"
        public static let remindersDescription = "Transforms your pending to-dos into timed focus sessions."
        
        public static let liveActivitiesTitle = "Live Activities & Dynamic Island"
        public static let liveActivitiesDescription = "Keeps your active session glanceable on your Lock Screen and Dynamic Island."
        
        public static let locationTitle = "Location & Travel"
        public static let locationDescription = "Calculates commute times to help you leave on time."
    }
    
    // MARK: - Insights & Analytics
    public enum Analytics {
        public static let biasDistributionTitle = "Time Estimation Velocity"
        public static let habitsTitle = "Routines & Patterns"
        public static let weeklyVelocity = "Weekly Focus Velocity"
        public static let highConfidence = "High Accuracy"
        public static let calibrating = "Calibrating"
    }
}
