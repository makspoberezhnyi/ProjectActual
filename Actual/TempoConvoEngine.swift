import Foundation
import SwiftUI

struct ConversationalResponse {
    var replyText: String
    var suggestedQuickActions: [String]
    
    init(replyText: String, suggestedQuickActions: [String] = []) {
        self.replyText = replyText
        self.suggestedQuickActions = suggestedQuickActions
    }
}

final class TempoConvoEngine {
    
    static func matchConversationalIntent(_ input: String, sessions: [Session] = []) -> ConversationalResponse? {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing punctuation like '?', '!', '.'
        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,:;"))
        
        // 1. Greetings & Check-ins
        if isGreeting(clean) {
            let hour = Calendar.current.component(.hour, from: Date())
            let timeGreeting: String
            if hour < 12 {
                timeGreeting = "Good morning!"
            } else if hour < 17 {
                timeGreeting = "Good afternoon!"
            } else {
                timeGreeting = "Good evening!"
            }
            
            let replies = [
                "\(timeGreeting) Ready when you are. Tell me what you're working on, or ask about your schedule or a ride estimate.",
                "Hey there! Ready to lock in and get things done today. What's on your mind?",
                "\(timeGreeting) I'm here to keep your focus sharp and time calibrated. What task are we starting?"
            ]
            let chosen = replies[abs(clean.hashValue) % replies.count]
            return ConversationalResponse(
                replyText: chosen,
                suggestedQuickActions: ["Check calendar & reminders", "Deep Work (25m)", "Ride to Airport?"]
            )
        }
        
        // 2. "What's up" / "How are you" / "Sup"
        if isHowAreYouOrWhatsUp(clean) {
            return ConversationalResponse(
                replyText: "All systems running smoothly! I'm ready to calibrate your focus and track your tasks. What are you working on right now?",
                suggestedQuickActions: ["Check calendar & reminders", "Focus for 25m", "How's my status?"]
            )
        }
        
        // 3. Identity & Capabilities ("Who are you", "What can you do", "Help")
        if isHelpOrIdentity(clean) {
            let helpText = """
            I'm Tempo — your adaptive focus & time calibration assistant! Here is what I can do:
            
            ⏱ **Focus Timers**: Type any task with an estimate (e.g. *"Design mockups for 30m"*) to start a calibrated session.
            📅 **Apple Calendar & Reminders**: Type *"Check my schedule"* to see your upcoming events and to-dos.
            🚗 **Travel & Ride Time**: Ask *"How long is the ride to the airport?"* or *"Time to my next meeting"* for real-time traffic ETAs.
            📊 **Bias Calibration**: I learn your actual focus velocity and help eliminate planning bias.
            """
            return ConversationalResponse(
                replyText: helpText,
                suggestedQuickActions: ["Check calendar & reminders", "How long the ride can take to Airport?"]
            )
        }
        
        // 4. Motivation & Mindset Boosts ("Motivate me", "I'm tired", "I don't want to work")
        if isMotivationRequest(clean) {
            let boosts = [
                "The hardest part is always taking the first step. Commit to just 10 or 15 minutes of focused work — once you start, momentum takes over!",
                "Progress isn't about perfection; it's about showing up. Pick one small item from your to-do list and let's knock it out.",
                "Take a deep breath and start small. Focus for 20 minutes, and we'll log your calibrated victory."
            ]
            let chosen = boosts[abs(clean.hashValue) % boosts.count]
            return ConversationalResponse(
                replyText: chosen,
                suggestedQuickActions: ["Quick Focus (15m)", "Check reminders"]
            )
        }
        
        // 5. Daily Focus Status & Summary ("How am I doing", "Status", "My stats", "Summary")
        if isStatusRequest(clean) {
            let todaySessions = sessions.filter {
                Calendar.current.isDateInToday($0.startedAt ?? $0.createdAt ?? Date()) && $0.isActualTask
            }
            let completed = todaySessions.filter { $0.endedAt != nil }
            let totalMins = completed.compactMap { $0.actualMinutes ?? $0.estimatedMinutes }.reduce(0, +)
            let score = BiasEngine.calculateOverallCalibration(sessions: sessions)
            let scorePercent = Int(score * 100)
            
            let statusText: String
            if totalMins > 0 {
                statusText = "📊 **Today's Status**: You've logged **\(totalMins) mins** across **\(completed.count) tasks**. Calibration accuracy: **\(scorePercent)%**. Keep up the great pace!"
            } else {
                statusText = "📊 You haven't logged any completed focus tasks today yet. Ready to kick off your first session?"
            }
            return ConversationalResponse(
                replyText: statusText,
                suggestedQuickActions: ["Start 25m Focus", "Check schedule"]
            )
        }
        
        // 6. Gratitude / Appreciation ("Thanks", "Thank you", "Good job", "Great")
        if isAppreciation(clean) {
            return ConversationalResponse(
                replyText: "You're very welcome! Let's keep the productivity flowing. 🚀"
            )
        }
        
        return nil
    }
    
    // MARK: - Pattern Matching Helpers
    
    private static func isGreeting(_ text: String) -> Bool {
        let greetings = [
            "hi", "hello", "hey", "heyy", "yo", "good morning", "good afternoon", "good evening", "good day", "greetings", "howdy", "hiya"
        ]
        return greetings.contains(text) || text == "hi tempo" || text == "hello tempo" || text == "hey tempo"
    }
    
    private static func isHowAreYouOrWhatsUp(_ text: String) -> Bool {
        let phrases = [
            "whats up", "what's up", "what is up", "sup", "how are you", "how r u", "how are you doing", "how's it going", "hows it going", "how are things", "what's new", "whats new"
        ]
        return phrases.contains(text) || text.starts(with: "what's up") || text.starts(with: "how are you")
    }
    
    private static func isHelpOrIdentity(_ text: String) -> Bool {
        let phrases = [
            "who are you", "what are you", "what can you do", "help", "commands", "how do you work", "features", "what is tempo", "who made you"
        ]
        if phrases.contains(text) { return true }
        if text.contains("what can you do") || text.contains("who are you") || text.contains("how do i use") { return true }
        return false
    }
    
    private static func isMotivationRequest(_ text: String) -> Bool {
        let phrases = [
            "motivate me", "inspire me", "im tired", "i'm tired", "i feel lazy", "im lazy", "i don't want to work", "i dont want to work", "cant focus", "can't focus", "im stuck", "i am stuck", "give me advice"
        ]
        if phrases.contains(text) { return true }
        if text.contains("motivate") || text.contains("inspire") || text.contains("lazy") || text.contains("tired") { return true }
        return false
    }
    
    private static func isStatusRequest(_ text: String) -> Bool {
        let phrases = [
            "how am i doing", "how am i doing today", "status", "my status", "stats", "my stats", "daily summary", "how's my day", "how is my day", "summary"
        ]
        return phrases.contains(text)
    }
    
    private static func isAppreciation(_ text: String) -> Bool {
        let phrases = [
            "thanks", "thank you", "thx", "good job", "great job", "awesome", "perfect", "nice", "cool", "ty"
        ]
        return phrases.contains(text)
    }
}
