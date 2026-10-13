import Foundation

/// Everything the mascot says. Short, casual, a few variants per moment so it never sounds canned.
/// Lines are picked at random but never the same one twice in a row.
@MainActor
enum TempoVoice {
    private static var lastLine = ""

    static func pick(_ lines: [String]) -> String {
        let fresh = lines.filter { $0 != lastLine }
        let line = (fresh.isEmpty ? lines : fresh).randomElement() ?? ""
        lastLine = line
        return line
    }

    // MARK: - Opening the app

    static func greeting(
        at now: Date = Date(),
        runningTitle: String?,
        remaining: TimeInterval?,
        todayMinutes: Int,
        nextEvent: String?,
        nextAlarm: (label: String, date: Date)?
    ) -> String {
        if let runningTitle, let remaining {
            if remaining > 0 {
                return pick([
                    "Still on \(runningTitle). \(TempoFormat.minutes(Int(remaining))) to go, you got this.",
                    "Welcome back. \(runningTitle) has \(TempoFormat.minutes(Int(remaining))) left.",
                    "Hey, \(runningTitle) is still ticking. \(TempoFormat.minutes(Int(remaining))) left."
                ])
            }
            return pick([
                "\(runningTitle) ran over by \(TempoFormat.minutes(Int(-remaining))). Done yet? Tap the check.",
                "You're in overtime on \(runningTitle). No shame, just tell me when it's done."
            ])
        }

        let hour = Calendar.current.component(.hour, from: now)
        let hello: String
        switch hour {
        case 5..<12: hello = pick(["Morning!", "Good morning.", "Morning, sunshine."])
        case 12..<17: hello = pick(["Hey!", "Afternoon!", "What's up?"])
        case 17..<22: hello = pick(["Evening!", "Hey there.", "Good evening."])
        default: hello = pick(["Up late, huh?", "Hey, night owl.", "Still awake?"])
        }

        if let nextEvent {
            return "\(hello) \(nextEvent) is up next. Want a timer for it?"
        }
        if hour >= 20, let alarm = nextAlarm {
            let time = alarm.date.formatted(date: .omitted, time: .shortened)
            return "\(hello) \(alarm.label) is set for \(time). Sleep well when you're ready."
        }
        if todayMinutes > 0 {
            return "\(hello) You've logged \(TempoFormat.minutes(todayMinutes * 60)) today. What's next?"
        }
        return hello + " " + pick([
            "What's on your plate today?",
            "What are we working on?",
            "What should we time first?",
            "Tell me what you're up to and I'll time it."
        ])
    }

    // MARK: - Switching tabs

    static func focusTab(isRunning: Bool, title: String) -> String {
        isRunning
            ? pick(["Back to \(title). Still going strong.", "\(title) is ticking. I'm watching the clock."])
            : pick(["What are we working on?", "Pick a task, I'll time it.", "Type a task, or tap play and go."])
    }

    static func alarmsTab(next: (label: String, date: Date)?) -> String {
        guard let next else {
            return pick([
                "No alarms on. Tap plus and I'll wake you up.",
                "Nothing set. Want me to ring you tomorrow?"
            ])
        }
        let time = next.date.formatted(date: .omitted, time: .shortened)
        let left = TempoFormat.minutes(Int(next.date.timeIntervalSinceNow))
        return pick([
            "\(next.label) rings at \(time). That's in \(left).",
            "Next up, \(next.label) at \(time). Tap me to hear the bells."
        ])
    }

    static func stopwatchTab(isRunning: Bool, elapsed: TimeInterval) -> String {
        if isRunning {
            return "Still running, \(TempoFormat.minutes(Int(elapsed))) so far."
        }
        if elapsed > 0 {
            return "Paused at \(TempoFormat.minutes(Int(elapsed))). Save it, or keep going?"
        }
        return pick([
            "Orange ear starts me, black ear marks a lap.",
            "Ready when you are. Tap play.",
            "Let's see how long it really takes."
        ])
    }

    static func worldTab(cities: [TempoWorldCity], now: Date = Date()) -> String {
        if let sleeping = cities.first(where: { $0.isMoodyNight(at: now) }) {
            return "It's \(sleeping.formattedLocalTime(at: now)) in \(sleeping.cityName). They're probably asleep."
        }
        if let city = cities.first(where: { $0.timeZoneIdentifier != TimeZone.current.identifier }) {
            return "It's \(city.formattedLocalTime(at: now)) in \(city.cityName). Long press a city for a sync timer."
        }
        return "Add a city and I'll keep its clock for you."
    }

    static func logbookTab(score: Double, sessions: Int) -> String {
        guard sessions > 0 else {
            return "Nothing logged yet. Finish one timer and I'll start learning your pace."
        }
        let pct = Int(score * 100)
        if pct >= 85 { return pick(["Your guesses are \(pct)% on target. That's sharp.", "\(pct)% accurate. You really know your time."]) }
        if pct >= 65 { return pick(["\(pct)% on target. Getting better every block.", "Your guesses are \(pct)% right. Nice and steady."]) }
        return pick(["\(pct)% on target so far. Every logged block makes the next guess better.", "We're still calibrating, \(pct)% so far. Keep logging."])
    }

    // MARK: - Timer

    static func start(title: String, minutes: Int, history: (average: Int, runs: Int)?, usedAverage: Bool) -> String {
        if let history, usedAverage {
            return "\(title) usually takes you \(history.average)m, so I set \(history.average)m. Let's go!"
        }
        if let history, abs(history.average - minutes) >= 5 {
            return "Let's go! Heads up, \(title) usually takes you \(history.average)m, not \(minutes)."
        }
        return pick([
            "Let's go! \(minutes)m on \(title).",
            "Okay, \(title), \(minutes) minutes. Starting now.",
            "\(minutes)m for \(title). Let's do this.",
            "Clock's running. \(title), \(minutes)m."
        ])
    }

    static func pause() -> String { pick(["Paused. I'll wait right here.", "Taking a breather? I'll hold the clock.", "Paused. Tap play when you're back."]) }
    static func resume() -> String { pick(["Back at it!", "And we're rolling again.", "Let's keep going."]) }
    static func reset() -> String { pick(["Cleared. Fresh start.", "Reset. What's next?", "Wiped the bezel clean."]) }
    static func extend(_ minutes: Int, total: Int) -> String { pick(["+\(minutes)m, no problem. Now \(TempoFormat.minutes(total)).", "Sure, \(minutes) more minutes.", "Added \(minutes)m. Take your time."]) }

    static func preset(_ title: String, seconds: Int) -> String {
        pick([
            "\(title), \(TempoFormat.minutes(seconds)). Tap play when ready.",
            "\(title) it is. \(TempoFormat.minutes(seconds)) on the bezel.",
            "Got it, \(title). Hit play and we go."
        ])
    }

    static func finished(title: String, actual: Int, estimate: Int, history: (average: Int, runs: Int)?) -> String {
        let diff = actual - estimate
        let verdict: String
        if abs(diff) <= 2 {
            verdict = pick(["Bullseye! \(title) took \(actual)m, right on your guess.", "Nailed it. \(actual)m, just like you said."])
        } else if diff > 0 {
            verdict = pick(["Done! \(title) took \(actual)m, \(diff)m more than planned. That's useful to know.", "Logged \(actual)m for \(title). A bit over, and that's fine."])
        } else {
            verdict = pick(["Done early! \(actual)m, \(-diff)m under your guess.", "Quick one. \(title) took only \(actual)m."])
        }
        guard let history, history.runs >= 2 else { return verdict }
        return verdict + " Your average is now \(history.average)m over \(history.runs) runs."
    }

    // MARK: - Stopwatch

    static func chronoStart() -> String { pick(["Go go go!", "Clock's running.", "Started. Tap the black ear for a lap."]) }
    static func chronoStop(_ elapsed: TimeInterval) -> String { pick(["Stopped at \(TempoFormat.stopwatch(elapsed)). Want to save it?", "\(TempoFormat.stopwatch(elapsed)). Not bad. Save it to the logbook?"]) }
    static func lap(_ number: Int, split: TimeInterval) -> String { pick(["Lap \(number), \(TempoFormat.stopwatch(split)).", "Got it, lap \(number)."]) }
    static func chronoReset() -> String { pick(["Back to zero.", "Clean slate."]) }

    // MARK: - Alarms and world

    static func alarmOn(_ alarm: TempoAlarm) -> String { pick(["\(alarm.label) is on for \(alarm.formattedTime). I'll be loud.", "Okay, I'll ring at \(alarm.formattedTime)."]) }
    static func alarmOff(_ alarm: TempoAlarm) -> String { pick(["\(alarm.label) is off. Sleep in!", "Turned off \(alarm.formattedTime)."]) }
    static func alarmDeleted() -> String { pick(["Alarm gone.", "Deleted. One less wake up."]) }
    static func alarmSnoozed(_ minutes: Int) -> String { pick(["Fine, \(minutes) more minutes. I'm counting.", "Snoozing. Back in \(minutes)m."]) }
    static func cityAdded(_ name: String) -> String { pick(["Added \(name). I'll keep its clock.", "\(name) is on the board."]) }
    static func cityRemoved() -> String { pick(["Removed.", "City gone."]) }

    // MARK: - Tapping the mascot

    static func poke(isRunning: Bool, title: String, remaining: TimeInterval) -> String {
        if isRunning, remaining > 0 {
            return pick([
                "Hey! \(TempoFormat.minutes(Int(remaining))) left on \(title).",
                "Still focused? \(TempoFormat.minutes(Int(remaining))) to go.",
                "Hehe, that tickles. Back to \(title)!"
            ])
        }
        return pick([
            "Hey! Tap my orange ear to start, black ear to reset.",
            "Hi! Tell me a task and how long you think it takes.",
            "I learn how long your stuff really takes. Try me.",
            "Psst. Drag the numbers up or down to set the time.",
            "Ask me \"What's on my calendar?\"",
            "Boop. What are we doing next?"
        ])
    }

    static let typingPrompt = "Ooh, what is it?"
}
