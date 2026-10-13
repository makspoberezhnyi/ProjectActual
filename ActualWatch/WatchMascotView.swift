import SwiftUI

// MARK: - Tempo Palette (Dieter Rams Braun / Teenage Engineering + Moody Midnight Blue Night)

public enum TempoMascotPalette {
    /// Warm Alabaster Daytime Dial (`#F6F4F0`)
    public static let alabaster = Color(red: 0.965, green: 0.957, blue: 0.941)
    /// Matte Carbon Black Bezel & Left Ear (`#1A1A1A`)
    public static let carbon = Color(red: 0.102, green: 0.102, blue: 0.102)
    /// International Orange Right Ear & Hour Nose-Hand (`#FF4F00`)
    public static let orange = Color(red: 1.000, green: 0.310, blue: 0.000)
    /// Moody Midnight Blue Night Dial (`#1E2B4F` — never black!)
    public static let moodyMidnightBlue = Color(red: 0.118, green: 0.169, blue: 0.310)
    /// Moody Dusk / Twilight Blue Dial (`#283862`)
    public static let moodyDuskBlue = Color(red: 0.157, green: 0.220, blue: 0.384)
    /// Soft Indigo Inner Ring for Night/Dusk Dials (`#394F86`)
    public static let moodyInnerRing = Color(red: 0.224, green: 0.310, blue: 0.525)
    /// Pale Moonlight Ticks for Night Dials (`#D8E2FF`)
    public static let moonlightTick = Color(red: 0.847, green: 0.886, blue: 1.000)
    /// Daytime Inner Ring (`#EAE6DF`)
    public static let dayInnerRing = Color(red: 0.918, green: 0.902, blue: 0.875)
    /// Ground Shadow (`#E6E2DA`)
    public static let groundShadow = Color(red: 0.902, green: 0.886, blue: 0.855)
}

// MARK: - All 24 Time OS Regimes (Unifying Alarms, Chrono, Timers, World Clock & Calibration)

public enum TempoMascotRegime: String, CaseIterable, Identifiable, Codable, Sendable {
    // Row 1: Alarms & Sleep Regime (Twin-Bell + Moody Blue Night)
    case alarmArmed = "ALARM 01"
    case alarmRinging = "ALARM 02"
    case alarmSnoozing = "ALARM 03"
    case alarmWakeStretch = "ALARM 04"
    case alarmHeavySiren = "ALARM 05"
    case alarmBedtimeMoody = "ALARM 06"
    
    // Row 2: Stopwatch / Chronograph Regime (Pusher Ears & Sweeping Nose)
    case chronoZeroed = "CHRONO 01"
    case chronoRunning = "CHRONO 02"
    case chronoLapSplit = "CHRONO 03"
    case chronoPaused = "CHRONO 04"
    case chronoSprintPB = "CHRONO 05"
    case chronoAssignTask = "CHRONO 06"
    
    // Row 3: Timers & Intervals Regime (Bezel Countdown Ring)
    case timerDialing = "TIMER 01"
    case timerActiveCountdown = "TIMER 02"
    case timerQuickKitchen = "TIMER 03"
    case timerPomodoroRest = "TIMER 04"
    case timerFinal10s = "TIMER 05"
    case timerComplete = "TIMER 06"
    
    // Row 4: World Clock & Task Calibration Regime
    case worldLocalDay = "WORLD 01"
    case worldRemoteNight = "WORLD 02"
    case worldDualGMT = "WORLD 03"
    case calibEstimating = "CALIB 01"
    case calibBullseyeJump = "CALIB 02"
    case calibOvertime = "CALIB 03"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .alarmArmed: return "Alarm Armed"
        case .alarmRinging: return "Morning Ringing!"
        case .alarmSnoozing: return "Snoozing (9m Drift)"
        case .alarmWakeStretch: return "Wake-Up Stretch"
        case .alarmHeavySiren: return "Heavy Sleeper Siren"
        case .alarmBedtimeMoody: return "Bedtime / Sleep Mode"
        case .chronoZeroed: return "Zeroed (00:00.00)"
        case .chronoRunning: return "Running Sweep"
        case .chronoLapSplit: return "Lap Split Stamp!"
        case .chronoPaused: return "Frozen / Paused Split"
        case .chronoSprintPB: return "Sprint / Personal Best"
        case .chronoAssignTask: return "Assign Split to Task"
        case .timerDialing: return "Dialing Duration"
        case .timerActiveCountdown: return "Active Countdown"
        case .timerQuickKitchen: return "Quick / Kitchen Timer"
        case .timerPomodoroRest: return "Interval / Rest Break"
        case .timerFinal10s: return "Final 10 Seconds!"
        case .timerComplete: return "Timer Complete (00:00)"
        case .worldLocalDay: return "Local Daytime City"
        case .worldRemoteNight: return "Remote Night City"
        case .worldDualGMT: return "Dual-Time GMT"
        case .calibEstimating: return "Estimating Task Time"
        case .calibBullseyeJump: return "Calibrated Bullseye!"
        case .calibOvertime: return "Overtime (+Min Over)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .alarmArmed: return "Nightstand standby · Bells set"
        case .alarmRinging: return "Twin bells vibrating + hammer strike"
        case .alarmSnoozing: return "Moody dusk blue · Squashed · zZz"
        case .alarmWakeStretch: return "Alarm dismissed · Morning energy"
        case .alarmHeavySiren: return "Urgent max-shake wakeup alert"
        case .alarmBedtimeMoody: return "Moody midnight blue dial (#1E2B4F)"
        case .chronoZeroed: return "Hands locked at 12 · Ready to start"
        case .chronoRunning: return "Orange ear clicked · 2.5D sweeping nose"
        case .chronoLapSplit: return "Black left ear clicked · Split recorded"
        case .chronoPaused: return "2.5D side look · Waiting to resume"
        case .chronoSprintPB: return "High-speed lean · Record pace"
        case .chronoAssignTask: return "Converting stopwatch run to task data"
        case .timerDialing: return "Watching bezel as you set minutes"
        case .timerActiveCountdown: return "2.5D Deep Focus · Orange ring burning"
        case .timerQuickKitchen: return "Steam puffs · Watchful utility timer"
        case .timerPomodoroRest: return "Pomodoro breather · Dashed rest bezel"
        case .timerFinal10s: return "Tiptoe tension · Tiny sliver left"
        case .timerComplete: return "Chime ring pulse · Joyful pop-up"
        case .worldLocalDay: return "Sun-ray bezel ticks · Active local hour"
        case .worldRemoteNight: return "Moody midnight blue dial (Tokyo 3AM)"
        case .worldDualGMT: return "3rd dotted GMT nose-hand tracks home"
        case .calibEstimating: return "2.5D pondering gaze · Predicting time"
        case .calibBullseyeJump: return "Estimate matched actual · 2.5D Jump"
        case .calibOvertime: return "Slumped past target tick · Recalibrating"
        }
    }
    
    public var categoryTitle: String {
        switch self {
        case .alarmArmed, .alarmRinging, .alarmSnoozing, .alarmWakeStretch, .alarmHeavySiren, .alarmBedtimeMoody:
            return "Alarms & Sleep"
        case .chronoZeroed, .chronoRunning, .chronoLapSplit, .chronoPaused, .chronoSprintPB, .chronoAssignTask:
            return "Chronograph"
        case .timerDialing, .timerActiveCountdown, .timerQuickKitchen, .timerPomodoroRest, .timerFinal10s, .timerComplete:
            return "Timers & Focus"
        case .worldLocalDay, .worldRemoteNight, .worldDualGMT, .calibEstimating, .calibBullseyeJump, .calibOvertime:
            return "World & Calibration"
        }
    }
}

// MARK: - Cross-faded overlay amounts (0...1) produced by the motion engine

public struct MascotFX: Equatable, Sendable {
    public var sunRays = 0.0
    public var zzz = 0.0
    public var steam = 0.0
    public var speedLines = 0.0
    public var sweat = 0.0
    public var ringWaves = 0.0
    public var armedDot = 0.0
    public var sweepTrail = 0.0
    public var leftSpark = 0.0
    public var targetTick = 0.0
    public var gmt = 0.0
    public init() {}
}

// MARK: - Mascot Anatomy & Pose Configuration

public struct TempoMascotConfig: Equatable, Sendable {
    public enum EyeStyle: Sendable { case idle, focus, happy, squint, wide, sleepy, wink, chill, lookup }
    public enum BrowStyle: Sendable { case none, focus, curious, worried }
    public enum MouthStyle: Sendable { case smile, orangeSmile, openHappy, determined, oSmall, oBig, smirk, squish }
    public enum DialTheme: Sendable { case dayAlabaster, moodyDuskBlue, moodyMidnightBlue }
    
    // 2.5D Body & Physics
    public var turnX: CGFloat = 0          // -10 (left) to +10 (right)
    public var turnY: CGFloat = 0          // -6 (up) to +6 (down)
    public var tiltDegrees: Double = 0
    public var scaleX: CGFloat = 1.0
    public var scaleY: CGFloat = 1.0
    public var jumpY: CGFloat = 0
    
    // Hardware Anatomy
    public var twinBells: Bool = false
    public var bellShake: Double = 0
    public var hammerAngle: Double = 0
    public var hammerDroop: Bool = false
    public var ringWaves: Bool = false
    public var leftEarClick: CGFloat = 0
    public var rightEarClick: CGFloat = 0
    public var leftEarSpark: Bool = false
    
    // Dial & Overlays
    public var dialTheme: DialTheme = .dayAlabaster
    public var sunRays: Bool = false
    public var bezelProgress: Double? = nil       // 0.0 ... 1.0
    public var bezelDashed: Bool = false
    public var bezelPulse: Bool = false
    public var targetTickAngle: Double? = nil     // Degrees (0 = 12 o'clock)
    public var steamWaves: Bool = false
    public var speedLines: Bool = false
    public var showZzz: Bool = false
    public var sweatDrop: Bool = false
    public var armedDot: Bool = false
    
    // Facial Features & Watch-Hand Nose
    public var eyes: EyeStyle = .idle
    public var brows: BrowStyle = .none
    public var minuteAngle: Double = 0            // Black vertical nose bridge (0 = 12 o'clock)
    public var hourAngle: Double = 52             // Orange nose tip
    public var gmtAngle: Double? = nil            // Optional 3rd dotted GMT hand
    public var sweepTrail: Bool = false
    public var mouth: MouthStyle = .smile
    public var showGroundShadow: Bool = true
    
    // Motion-engine outputs. Defaults render a static pose.
    public var eyeOpenness: CGFloat = 1
    public var mouthScale: CGFloat = 1
    public var fx: MascotFX? = nil
    
    /// Smoothed overlay amounts when animated; derived from the booleans for static poses.
    public var effectiveFX: MascotFX { fx ?? MascotFX.goal(for: self, spark: false) }
    
    public init() {}
    
    public static func from(regime: TempoMascotRegime) -> TempoMascotConfig {
        var c = TempoMascotConfig()
        switch regime {
        case .alarmArmed:
            c.twinBells = true; c.armedDot = true; c.eyes = .idle; c.minuteAngle = 0; c.hourAngle = 65; c.mouth = .smile
        case .alarmRinging:
            c.twinBells = true; c.bellShake = 6; c.hammerAngle = -18; c.ringWaves = true
            c.jumpY = -6; c.scaleX = 0.97; c.scaleY = 1.04; c.eyes = .wide; c.minuteAngle = 0; c.hourAngle = 55; c.mouth = .openHappy
        case .alarmSnoozing:
            c.twinBells = true; c.dialTheme = .moodyDuskBlue; c.hammerDroop = true; c.showZzz = true
            c.scaleX = 1.09; c.scaleY = 0.88; c.jumpY = 10; c.bezelProgress = 0.15; c.bezelDashed = true
            c.eyes = .sleepy; c.minuteAngle = 95; c.hourAngle = 135; c.mouth = .oSmall
        case .alarmWakeStretch:
            c.twinBells = true; c.scaleX = 0.94; c.scaleY = 1.07; c.jumpY = -8
            c.eyes = .happy; c.minuteAngle = 0; c.hourAngle = 45; c.mouth = .orangeSmile
        case .alarmHeavySiren:
            c.twinBells = true; c.bellShake = -9; c.hammerAngle = 22; c.ringWaves = true
            c.tiltDegrees = -5; c.jumpY = -10; c.eyes = .wide; c.brows = .worried; c.minuteAngle = -20; c.hourAngle = 35; c.mouth = .oBig
        case .alarmBedtimeMoody:
            c.dialTheme = .moodyMidnightBlue; c.showZzz = true; c.tiltDegrees = -4
            c.eyes = .sleepy; c.minuteAngle = 310; c.hourAngle = 240; c.mouth = .smile
        case .chronoZeroed:
            c.eyes = .focus; c.brows = .focus; c.minuteAngle = 0; c.hourAngle = 0; c.mouth = .determined
        case .chronoRunning:
            c.turnX = 6; c.turnY = -2; c.tiltDegrees = 4; c.rightEarClick = 7; c.sweepTrail = true
            c.eyes = .focus; c.brows = .focus; c.minuteAngle = 125; c.hourAngle = 35; c.mouth = .determined
        case .chronoLapSplit:
            c.turnX = -5; c.tiltDegrees = -4; c.leftEarClick = 8; c.leftEarSpark = true
            c.eyes = .wink; c.minuteAngle = 210; c.hourAngle = 60; c.mouth = .smirk
        case .chronoPaused:
            c.turnX = 9; c.eyes = .idle; c.brows = .curious; c.minuteAngle = 82; c.hourAngle = 24; c.mouth = .oSmall
        case .chronoSprintPB:
            c.turnX = 8; c.tiltDegrees = 9; c.scaleX = 1.04; c.scaleY = 0.96; c.speedLines = true; c.sweepTrail = true
            c.eyes = .happy; c.minuteAngle = 150; c.hourAngle = 45; c.mouth = .openHappy
        case .chronoAssignTask:
            c.turnX = 5; c.tiltDegrees = 3; c.targetTickAngle = 140
            c.eyes = .wink; c.minuteAngle = 140; c.hourAngle = 50; c.mouth = .orangeSmile
        case .timerDialing:
            c.turnY = -4; c.bezelProgress = 0.58; c.eyes = .lookup; c.brows = .curious; c.minuteAngle = 0; c.hourAngle = 210; c.mouth = .oSmall
        case .timerActiveCountdown:
            c.turnX = 5; c.turnY = 2; c.tiltDegrees = 3; c.rightEarClick = 5; c.bezelProgress = 0.74
            c.eyes = .focus; c.brows = .focus; c.minuteAngle = 0; c.hourAngle = 90; c.mouth = .determined
        case .timerQuickKitchen:
            c.steamWaves = true; c.bezelProgress = 0.33; c.eyes = .wide; c.minuteAngle = 35; c.hourAngle = 120; c.mouth = .smile
        case .timerPomodoroRest:
            c.turnX = -4; c.tiltDegrees = -6; c.bezelProgress = 0.5; c.bezelDashed = true
            c.eyes = .chill; c.minuteAngle = 280; c.hourAngle = 80; c.mouth = .smile
        case .timerFinal10s:
            c.scaleX = 0.93; c.scaleY = 1.08; c.jumpY = -9; c.bezelProgress = 0.06
            c.eyes = .wide; c.brows = .worried; c.minuteAngle = 12; c.hourAngle = 22; c.mouth = .oBig
        case .timerComplete:
            c.jumpY = -12; c.tiltDegrees = -5; c.bezelProgress = 0.99; c.bezelPulse = true
            c.eyes = .happy; c.minuteAngle = 0; c.hourAngle = 45; c.mouth = .openHappy
        case .worldLocalDay:
            c.sunRays = true; c.eyes = .idle; c.minuteAngle = 10; c.hourAngle = 60; c.mouth = .orangeSmile
        case .worldRemoteNight:
            c.dialTheme = .moodyMidnightBlue; c.eyes = .sleepy; c.minuteAngle = 0; c.hourAngle = 90; c.mouth = .oSmall
        case .worldDualGMT:
            c.turnX = -6; c.tiltDegrees = -3; c.gmtAngle = 235
            c.eyes = .idle; c.brows = .curious; c.minuteAngle = 0; c.hourAngle = 65; c.mouth = .smirk
        case .calibEstimating:
            c.turnX = -6; c.turnY = -4; c.tiltDegrees = -5; c.targetTickAngle = 120
            c.eyes = .lookup; c.brows = .curious; c.minuteAngle = 335; c.hourAngle = 120; c.mouth = .determined
        case .calibBullseyeJump:
            c.turnX = 4; c.tiltDegrees = -7; c.scaleX = 0.94; c.scaleY = 1.07; c.jumpY = -14; c.targetTickAngle = 60
            c.eyes = .happy; c.minuteAngle = 0; c.hourAngle = 60; c.mouth = .openHappy
        case .calibOvertime:
            c.scaleX = 1.08; c.scaleY = 0.90; c.jumpY = 10; c.sweatDrop = true; c.targetTickAngle = 90
            c.eyes = .sleepy; c.brows = .worried; c.minuteAngle = 135; c.hourAngle = 165; c.mouth = .squish
        }
        return c
    }
}

// MARK: - Core Vector Watch Mascot Renderer (Works in iOS, watchOS, Widgets & Dynamic Island)

extension MascotFX {
    /// The overlay amounts a pose is heading toward.
    static func goal(for c: TempoMascotConfig, spark: Bool) -> MascotFX {
        var f = MascotFX()
        f.sunRays = c.sunRays ? 1 : 0
        f.zzz = c.showZzz ? 1 : 0
        f.steam = c.steamWaves ? 1 : 0
        f.speedLines = c.speedLines ? 1 : 0
        f.sweat = c.sweatDrop ? 1 : 0
        f.ringWaves = (c.twinBells && c.ringWaves) ? 1 : 0
        f.armedDot = c.armedDot ? 1 : 0
        f.sweepTrail = c.sweepTrail ? 1 : 0
        f.leftSpark = (c.leftEarSpark || spark) ? 1 : 0
        f.targetTick = c.targetTickAngle != nil ? 1 : 0
        f.gmt = c.gmtAngle != nil ? 1 : 0
        return f
    }
}

// MARK: - Spring Motion Engine
//
// `Canvas` cannot interpolate a plain struct, so `withAnimation` never smoothed the mascot:
// every pose change snapped. Instead each continuous channel is a damped spring that chases
// the pose of the current regime, which gives glide, squash-and-stretch overshoot and
// frame-rate independence. Discrete features (eye / mouth style) swap behind a blink or pop.

struct MascotSpring {
    var value: Double
    var velocity: Double = 0
    
    init(_ value: Double = 0) { self.value = value }
    
    mutating func snap(_ v: Double) {
        value = v
        velocity = 0
    }
    
    mutating func step(to goal: Double, k: Double, zeta: Double, dt: Double, angular: Bool = false) {
        guard dt > 0 else { return }
        let c = 2.0 * zeta * k.squareRoot()
        var left = dt
        while left > 0 {
            let h = min(left, 1.0 / 120.0)
            var err = goal - value
            if angular { err = MascotSpring.wrap(err) }
            velocity += (k * err - c * velocity) * h
            value += velocity * h
            left -= h
        }
        if angular { value = value.truncatingRemainder(dividingBy: 360.0) }
    }
    
    static func wrap(_ angle: Double) -> Double {
        var a = angle.truncatingRemainder(dividingBy: 360.0)
        if a > 180 { a -= 360 } else if a < -180 { a += 360 }
        return a
    }
}

@MainActor
final class MascotDynamics {
    /// Drag-to-look offsets written by the interactive wrapper.
    var dragX: Double = 0
    var dragY: Double = 0
    
    private var turnX = MascotSpring()
    private var turnY = MascotSpring()
    private var tilt = MascotSpring()
    private var scaleX = MascotSpring(1)
    private var scaleY = MascotSpring(1)
    private var jump = MascotSpring()
    private var bell = MascotSpring()
    private var hammer = MascotSpring()
    private var leftEar = MascotSpring()
    private var rightEar = MascotSpring()
    private var minute = MascotSpring()
    private var hour = MascotSpring()
    private var bezel = MascotSpring()
    private var targetAngle = MascotSpring()
    private var gmtAngle = MascotSpring()
    private var mouthPop = MascotSpring(1)
    private var fx = MascotFX()
    
    private var shownEyes: TempoMascotConfig.EyeStyle = .idle
    private var shownMouth: TempoMascotConfig.MouthStyle = .smile
    private var blinkStart: Double?
    private var nextBlink: Double = 0
    private var blinkRequested = false
    private var sparkUntil: Double = 0
    private var lastTime: Double?
    private var primed = false
    
    // MARK: Impulses
    
    func squish() {
        scaleX.velocity += 1.7
        scaleY.velocity -= 2.2
        jump.velocity -= 120
        blinkRequested = true
    }
    
    func pressLeftEar() {
        leftEar.value = 8
        leftEar.velocity = 0
        turnX.velocity -= 26
        tilt.velocity -= 22
        sparkUntil = Date().timeIntervalSinceReferenceDate + 0.3
    }
    
    func pressRightEar() {
        rightEar.value = 8
        rightEar.velocity = 0
        turnX.velocity += 26
        tilt.velocity += 22
    }
    
    // MARK: Frame step
    
    func pose(for goal: TempoMascotConfig, at t: Double, idle: Bool, autoSweep: Bool) -> TempoMascotConfig {
        let dt: Double = lastTime.map { min(max(t - $0, 0), 1.0 / 20.0) } ?? 0
        lastTime = t
        
        let sweeping = goal.sweepTrail && autoSweep
        let minuteGoal = sweeping ? (t * 48.0).truncatingRemainder(dividingBy: 360.0) : goal.minuteAngle
        let hammerGoal = goal.hammerDroop ? 28.0 : goal.hammerAngle
        let fxGoal = MascotFX.goal(for: goal, spark: t < sparkUntil)
        
        if !primed {
            primed = true
            turnX.snap(Double(goal.turnX))
            turnY.snap(Double(goal.turnY))
            tilt.snap(goal.tiltDegrees)
            scaleX.snap(Double(goal.scaleX))
            scaleY.snap(Double(goal.scaleY))
            jump.snap(Double(goal.jumpY))
            bell.snap(goal.bellShake)
            hammer.snap(hammerGoal)
            leftEar.snap(Double(goal.leftEarClick))
            rightEar.snap(Double(goal.rightEarClick))
            minute.snap(minuteGoal)
            hour.snap(goal.hourAngle)
            bezel.snap(goal.bezelProgress ?? 0)
            targetAngle.snap(goal.targetTickAngle ?? 0)
            gmtAngle.snap(goal.gmtAngle ?? 0)
            shownEyes = goal.eyes
            shownMouth = goal.mouth
            fx = fxGoal
            nextBlink = t + 2.5
        }
        
        // Body physics — slightly under-damped so poses settle with life.
        turnX.step(to: Double(goal.turnX), k: 120, zeta: 0.6, dt: dt)
        turnY.step(to: Double(goal.turnY), k: 120, zeta: 0.6, dt: dt)
        tilt.step(to: goal.tiltDegrees, k: 110, zeta: 0.5, dt: dt)
        scaleX.step(to: Double(goal.scaleX), k: 170, zeta: 0.5, dt: dt)
        scaleY.step(to: Double(goal.scaleY), k: 170, zeta: 0.5, dt: dt)
        jump.step(to: Double(goal.jumpY), k: 150, zeta: 0.45, dt: dt)
        bell.step(to: goal.bellShake, k: 200, zeta: 0.7, dt: dt)
        hammer.step(to: hammerGoal, k: 200, zeta: 0.6, dt: dt)
        leftEar.step(to: Double(goal.leftEarClick), k: 420, zeta: 0.5, dt: dt)
        rightEar.step(to: Double(goal.rightEarClick), k: 420, zeta: 0.5, dt: dt)
        
        // Hands — firm, nearly critically damped, shortest-path rotation.
        minute.step(to: minuteGoal, k: 240, zeta: 0.9, dt: dt, angular: true)
        hour.step(to: goal.hourAngle, k: 240, zeta: 0.9, dt: dt, angular: true)
        bezel.step(to: goal.bezelProgress ?? 0, k: 90, zeta: 1.0, dt: dt)
        mouthPop.step(to: 1, k: 300, zeta: 0.45, dt: dt)
        
        // Overlay cross-fades.
        let e = dt > 0 ? 1 - exp(-dt * 9.0) : 0
        func ease(_ a: inout Double, _ b: Double) { a += (b - a) * e }
        ease(&fx.sunRays, fxGoal.sunRays)
        ease(&fx.zzz, fxGoal.zzz)
        ease(&fx.steam, fxGoal.steam)
        ease(&fx.speedLines, fxGoal.speedLines)
        ease(&fx.sweat, fxGoal.sweat)
        ease(&fx.ringWaves, fxGoal.ringWaves)
        ease(&fx.armedDot, fxGoal.armedDot)
        ease(&fx.sweepTrail, fxGoal.sweepTrail)
        ease(&fx.leftSpark, fxGoal.leftSpark)
        ease(&fx.targetTick, fxGoal.targetTick)
        ease(&fx.gmt, fxGoal.gmt)
        
        if let a = goal.targetTickAngle {
            if fx.targetTick < 0.02 { targetAngle.snap(a) }
            else { targetAngle.step(to: a, k: 200, zeta: 0.9, dt: dt, angular: true) }
        }
        if let g = goal.gmtAngle {
            if fx.gmt < 0.02 { gmtAngle.snap(g) }
            else { gmtAngle.step(to: g, k: 200, zeta: 0.9, dt: dt, angular: true) }
        }
        
        // Eyes swap behind a blink; idle blinks keep the face alive.
        if goal.mouth != shownMouth {
            shownMouth = goal.mouth
            mouthPop.value = 0.55
            mouthPop.velocity = 0
        }
        if blinkStart == nil {
            if goal.eyes != shownEyes || blinkRequested {
                blinkStart = t
            } else if idle && t > nextBlink {
                blinkStart = t
                nextBlink = t + Double.random(in: 2.6...5.4)
            }
        }
        blinkRequested = false
        var openness = 1.0
        if let b = blinkStart {
            let p = (t - b) / 0.22
            if p >= 1 {
                blinkStart = nil
                shownEyes = goal.eyes
            } else {
                if p >= 0.5 { shownEyes = goal.eyes }
                openness = pow(abs(2 * p - 1), 1.4)
            }
        }
        
        // Compose output pose.
        var c = goal
        c.turnX = CGFloat(turnX.value)
        c.turnY = CGFloat(turnY.value)
        c.tiltDegrees = tilt.value
        c.scaleX = CGFloat(scaleX.value)
        c.scaleY = CGFloat(scaleY.value)
        c.jumpY = CGFloat(jump.value)
        c.leftEarClick = CGFloat(leftEar.value)
        c.rightEarClick = CGFloat(rightEar.value)
        c.minuteAngle = minute.value
        c.hourAngle = hour.value
        c.bezelProgress = bezel.value > 0.012 ? min(1, bezel.value) : nil
        c.targetTickAngle = targetAngle.value
        c.gmtAngle = gmtAngle.value
        c.eyes = shownEyes
        c.mouth = shownMouth
        c.eyeOpenness = CGFloat(openness)
        c.mouthScale = CGFloat(mouthPop.value)
        
        // Ringing bells vibrate in proportion to how "ringing" the pose is.
        let amp = fx.ringWaves
        c.bellShake = bell.value * (1 - amp) + sin(t * 26.0) * 8.0 * amp
        c.hammerAngle = hammer.value * (1 - amp) + sin(t * 26.0) * 22.0 * amp
        c.jumpY += CGFloat(abs(sin(t * 13.0)) * -4.0 * amp)
        
        if idle {
            let breath = sin(t * 2.2)
            c.jumpY += CGFloat(breath * 2.0)
            c.scaleY *= CGFloat(1.0 + breath * 0.012)
            c.scaleX *= CGFloat(1.0 - breath * 0.008)
            c.turnX += CGFloat(sin(t * 0.7))
            c.tiltDegrees += sin(t * 0.9 + 1.0) * 0.5
        }
        
        c.fx = fx
        return c
    }
}

/// Drives a `MascotCanvasBody` from a spring engine on a single display-linked timeline.
private struct MascotStage: View {
    let size: CGFloat
    let autoSweep: Bool
    let dynamics: MascotDynamics
    let goal: @MainActor (Date) -> TempoMascotConfig
    
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: scenePhase != .active)) { timeline in
            let pose = dynamics.pose(
                for: goal(timeline.date),
                at: timeline.date.timeIntervalSinceReferenceDate,
                idle: !reduceMotion,
                autoSweep: autoSweep
            )
            MascotCanvasBody(config: pose, size: size)
        }
    }
}

// MARK: - Core Vector Watch Mascot Renderer (Works in iOS, watchOS, Widgets & Dynamic Island)

public struct TempoWatchMascotView: View {
    public var config: TempoMascotConfig
    public var size: CGFloat
    public var animated: Bool
    private var hasLiveMinute: Bool = false
    
    @State private var dynamics = MascotDynamics()
    
    public init(
        regime: TempoMascotRegime,
        size: CGFloat = 180,
        animated: Bool = true,
        overrideMinuteAngle: Double? = nil,
        overrideHourAngle: Double? = nil,
        overrideBezelProgress: Double? = nil
    ) {
        var cfg = TempoMascotConfig.from(regime: regime)
        if let m = overrideMinuteAngle { cfg.minuteAngle = m }
        if let h = overrideHourAngle { cfg.hourAngle = h }
        if let p = overrideBezelProgress { cfg.bezelProgress = p }
        self.config = cfg
        self.size = size
        self.animated = animated
        self.hasLiveMinute = overrideMinuteAngle != nil
    }
    
    public init(config: TempoMascotConfig, size: CGFloat = 180, animated: Bool = true) {
        self.config = config
        self.size = size
        self.animated = animated
    }
    
    public var body: some View {
        if animated {
            let target = config
            MascotStage(size: size, autoSweep: !hasLiveMinute, dynamics: dynamics, goal: { _ in target })
        } else {
            MascotCanvasBody(config: config, size: size)
        }
    }
}

private struct MascotCanvasBody: View {
    let config: TempoMascotConfig
    let size: CGFloat
    
    var body: some View {
        Canvas { ctx, canvasSize in
            let scale = min(canvasSize.width / 248.0, canvasSize.height / 268.0)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: 4.0, y: 16.0)
            
            let pX = config.turnX * 1.15
            let pY = config.turnY * 1.05
            let noseX = config.turnX * 1.5
            let noseY = config.turnY * 1.25
            let rimSideX = -config.turnX * 0.85
            let rimSideY = max(2.0, 3.0 - config.turnY * 0.4)
            let bodyRx = 96.0 - abs(config.turnX) * 0.45
            let bodyRy = 96.0 - abs(config.turnY) * 0.35
            
            let isMoody = config.dialTheme != .dayAlabaster
            let faceFill: Color = {
                switch config.dialTheme {
                case .dayAlabaster: return TempoMascotPalette.alabaster
                case .moodyDuskBlue: return TempoMascotPalette.moodyDuskBlue
                case .moodyMidnightBlue: return TempoMascotPalette.moodyMidnightBlue
                }
            }()
            let innerRingColor = isMoody ? TempoMascotPalette.moodyInnerRing : TempoMascotPalette.dayInnerRing
            let primaryInk = isMoody ? TempoMascotPalette.alabaster : TempoMascotPalette.carbon
            let tickColor = isMoody ? TempoMascotPalette.moonlightTick : TempoMascotPalette.carbon
            
            let fx = config.effectiveFX
            
            // 1. Ground Shadow
            if config.showGroundShadow {
                let shadowRatio = max(0.55, 1.0 - abs(config.jumpY) * 0.02)
                let sRx = 58.0 * shadowRatio
                let shadowRect = CGRect(x: 120.0 - sRx, y: 231.0, width: sRx * 2.0, height: 14.0)
                ctx.fill(Path(ellipseIn: shadowRect), with: .color(TempoMascotPalette.groundShadow.opacity(0.65)))
            }
            
            // 2. Main Body Transform (Jump, Tilt, Scale Squash/Stretch)
            ctx.translateBy(x: 120.0, y: 128.0 + config.jumpY)
            ctx.rotate(by: .degrees(config.tiltDegrees))
            ctx.scaleBy(x: config.scaleX, y: config.scaleY)
            ctx.translateBy(x: -120.0, y: -128.0)
            
            // 3. Hardware Ears (Twin Bells vs. Chronograph Pushers)
            if config.twinBells {
                drawTwinBells(ctx: &ctx)
            } else {
                drawPusherEars(ctx: &ctx)
            }
            
            // 4. 2.5D Case Side Extrusion
            let extrudeRect = CGRect(
                x: 120.0 + rimSideX - bodyRx,
                y: 128.0 + rimSideY - bodyRy,
                width: bodyRx * 2.0,
                height: bodyRy * 2.0
            )
            ctx.fill(Path(ellipseIn: extrudeRect), with: .color(TempoMascotPalette.carbon))
            
            // 5. Watch Case Bezel & Face
            let caseRect = CGRect(x: 120.0 - bodyRx, y: 128.0 - bodyRy, width: bodyRx * 2.0, height: bodyRy * 2.0)
            let casePath = Path(ellipseIn: caseRect)
            ctx.fill(casePath, with: .color(faceFill))
            ctx.stroke(casePath, with: .color(TempoMascotPalette.carbon), lineWidth: 14.0)
            
            // 6. Inner Dial Ring
            let inRx = bodyRx - 18.0
            let inRy = bodyRy - 18.0
            let innerRect = CGRect(
                x: 120.0 + pX * 0.35 - inRx,
                y: 128.0 + pY * 0.35 - inRy,
                width: inRx * 2.0,
                height: inRy * 2.0
            )
            ctx.stroke(Path(ellipseIn: innerRect), with: .color(innerRingColor), lineWidth: 2.5)
            
            // 7. All 4 Cardinal Ticks (12, 3, 6, 9 o'clock)
            strokeLine(&ctx, from: CGPoint(x: 120 + pX * 0.4, y: 42), to: CGPoint(x: 120 + pX * 0.4, y: 54), color: tickColor, width: 6)
            strokeLine(&ctx, from: CGPoint(x: 206 + pX * 0.25, y: 128 + pY * 0.4), to: CGPoint(x: 194 + pX * 0.25, y: 128 + pY * 0.4), color: tickColor, width: 6)
            strokeLine(&ctx, from: CGPoint(x: 120 + pX * 0.4, y: 214), to: CGPoint(x: 120 + pX * 0.4, y: 202), color: tickColor, width: 6)
            strokeLine(&ctx, from: CGPoint(x: 34 + pX * 0.25, y: 128 + pY * 0.4), to: CGPoint(x: 46 + pX * 0.25, y: 128 + pY * 0.4), color: tickColor, width: 6)
            
            fade(fx.armedDot, &ctx) { ctx in
                let dotRect = CGRect(x: 120 + pX * 0.4 - 5, y: 61, width: 10, height: 10)
                ctx.fill(Path(ellipseIn: dotRect), with: .color(TempoMascotPalette.orange))
            }
            
            // Moody Blue Crescent Moon Accent
            if isMoody {
                let moonRect = CGRect(x: 154, y: 64, width: 14, height: 14)
                ctx.fill(Path(ellipseIn: moonRect), with: .color(TempoMascotPalette.orange))
                let cutRect = CGRect(x: 159, y: 61, width: 12, height: 12)
                ctx.fill(Path(ellipseIn: cutRect), with: .color(faceFill))
            }
            
            // 8. Bezel Countdown Arc & Target Tick
            if let progress = config.bezelProgress, progress > 0.012 {
                let endDeg = min(359.0, max(4.0, progress * 360.0))
                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: 120, y: 128),
                    radius: 86,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(endDeg - 90),
                    clockwise: false
                )
                let style = StrokeStyle(
                    lineWidth: 8,
                    lineCap: .round,
                    dash: config.bezelDashed ? [10, 8] : []
                )
                ctx.stroke(arc, with: .color(TempoMascotPalette.orange), style: style)
                let tip = polar(cx: 120, cy: 128, r: 86, deg: endDeg)
                ctx.fill(Path(ellipseIn: CGRect(x: tip.x - 6, y: tip.y - 6, width: 12, height: 12)), with: .color(TempoMascotPalette.orange))
            }
            
            fade(fx.targetTick, &ctx) { ctx in
                let targetDeg = config.targetTickAngle ?? 0.0
                let p1 = polar(cx: 120, cy: 128, r: 76, deg: targetDeg)
                let p2 = polar(cx: 120, cy: 128, r: 92, deg: targetDeg)
                strokeLine(&ctx, from: p1, to: p2, color: TempoMascotPalette.orange, width: 6)
            }
            
            fade(fx.sunRays, &ctx) { ctx in
                strokeLine(&ctx, from: CGPoint(x: 120, y: 12), to: CGPoint(x: 120, y: 22), color: TempoMascotPalette.orange, width: 4)
                strokeLine(&ctx, from: CGPoint(x: 92, y: 16), to: CGPoint(x: 96, y: 25), color: TempoMascotPalette.orange, width: 4)
                strokeLine(&ctx, from: CGPoint(x: 148, y: 16), to: CGPoint(x: 144, y: 25), color: TempoMascotPalette.orange, width: 4)
            }
            
            fade(fx.zzz, &ctx) { ctx in
                var z1 = Path()
                z1.move(to: CGPoint(x: 184, y: 30))
                z1.addLine(to: CGPoint(x: 198, y: 30))
                z1.addLine(to: CGPoint(x: 184, y: 44))
                z1.addLine(to: CGPoint(x: 198, y: 44))
                ctx.stroke(z1, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                
                var z2 = Path()
                z2.move(to: CGPoint(x: 204, y: 14))
                z2.addLine(to: CGPoint(x: 215, y: 14))
                z2.addLine(to: CGPoint(x: 204, y: 25))
                z2.addLine(to: CGPoint(x: 215, y: 25))
                ctx.stroke(z2, with: .color(tickColor), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
            }
            
            fade(fx.steam, &ctx) { ctx in
                for xOff in [104.0, 120.0, 136.0] {
                    var s = Path()
                    s.move(to: CGPoint(x: xOff, y: 18))
                    s.addQuadCurve(to: CGPoint(x: xOff, y: 4), control: CGPoint(x: xOff - 6, y: 11))
                    s.addQuadCurve(to: CGPoint(x: xOff, y: -10), control: CGPoint(x: xOff + 6, y: -3))
                    ctx.stroke(s, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                }
            }
            
            fade(fx.speedLines, &ctx) { ctx in
                strokeLine(&ctx, from: CGPoint(x: 4, y: 96), to: CGPoint(x: 24, y: 96), color: TempoMascotPalette.orange, width: 4)
                strokeLine(&ctx, from: CGPoint(x: 0, y: 126), to: CGPoint(x: 18, y: 126), color: TempoMascotPalette.carbon, width: 4)
                strokeLine(&ctx, from: CGPoint(x: 8, y: 156), to: CGPoint(x: 26, y: 156), color: TempoMascotPalette.orange, width: 4)
            }
            
            fade(fx.sweat, &ctx) { ctx in
                let drop = Path(ellipseIn: CGRect(x: 178, y: 86, width: 11, height: 15))
                ctx.fill(drop, with: .color(TempoMascotPalette.orange))
            }
            
            // 9. Eyes & Brows
            drawEyesAndBrows(ctx: &ctx, pX: pX, pY: pY, primaryInk: primaryInk, faceFill: faceFill)
            
            // 10. Pure Watch-Hand Nose (Black Minute Hand + Orange Hour Hand + Optional 3rd GMT Hand)
            let nCx = 120.0 + noseX
            let nCy = 128.0 + noseY
            let centerPt = CGPoint(x: nCx, y: nCy)
            
            fade(fx.sweepTrail, &ctx) { ctx in
                var trail = Path()
                trail.addArc(
                    center: centerPt,
                    radius: 36,
                    startAngle: .degrees(config.minuteAngle - 145),
                    endAngle: .degrees(config.minuteAngle - 90),
                    clockwise: false
                )
                ctx.stroke(trail, with: .color(TempoMascotPalette.orange.opacity(0.25)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            }
            
            fade(fx.gmt, &ctx) { ctx in
                let gmt = config.gmtAngle ?? 0.0
                let gPt = polar(cx: nCx, cy: nCy, r: 48, deg: gmt)
                var gPath = Path()
                gPath.move(to: centerPt)
                gPath.addLine(to: gPt)
                ctx.stroke(gPath, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 3]))
                ctx.fill(Path(ellipseIn: CGRect(x: gPt.x - 4.5, y: gPt.y - 4.5, width: 9, height: 9)), with: .color(TempoMascotPalette.orange))
            }
            
            let minPt = polar(cx: nCx, cy: nCy, r: 40, deg: config.minuteAngle)
            let hrPt = polar(cx: nCx, cy: nCy, r: 30, deg: config.hourAngle)
            strokeLine(&ctx, from: centerPt, to: minPt, color: primaryInk, width: 8.5)
            strokeLine(&ctx, from: centerPt, to: hrPt, color: TempoMascotPalette.orange, width: 8.5)
            
            ctx.fill(Path(ellipseIn: CGRect(x: nCx - 7.5, y: nCy - 7.5, width: 15, height: 15)), with: .color(TempoMascotPalette.orange))
            ctx.fill(Path(ellipseIn: CGRect(x: nCx - 3.0, y: nCy - 3.0, width: 6, height: 6)), with: .color(faceFill))
            
            // 11. Mouth
            drawMouth(ctx: &ctx, pX: pX, pY: pY, primaryInk: primaryInk)
        }
        .frame(width: size, height: size)
    }
    
    // MARK: - Sub-Drawers
    
    private func drawTwinBells(ctx: inout GraphicsContext) {
        // Feet
        strokeLine(&ctx, from: CGPoint(x: 88, y: 214), to: CGPoint(x: 74, y: 234), color: TempoMascotPalette.carbon, width: 10)
        strokeLine(&ctx, from: CGPoint(x: 152, y: 214), to: CGPoint(x: 166, y: 234), color: TempoMascotPalette.carbon, width: 10)
        
        // Left Bell (Black)
        ctx.drawLayer { lCtx in
            lCtx.translateBy(x: 58, y: 44)
            lCtx.rotate(by: .degrees(-38 + config.bellShake))
            lCtx.fill(Path(CGRect(x: -5, y: -2, width: 10, height: 20)), with: .color(TempoMascotPalette.carbon))
            var dome = Path()
            dome.addArc(center: CGPoint(x: 0, y: -2), radius: 33, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            dome.closeSubpath()
            lCtx.fill(dome, with: .color(TempoMascotPalette.carbon))
        }
        
        // Right Bell (Orange)
        ctx.drawLayer { rCtx in
            rCtx.translateBy(x: 182, y: 44)
            rCtx.rotate(by: .degrees(38 + config.bellShake))
            rCtx.fill(Path(CGRect(x: -5, y: -2, width: 10, height: 20)), with: .color(TempoMascotPalette.orange))
            var dome = Path()
            dome.addArc(center: CGPoint(x: 0, y: -2), radius: 33, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            dome.closeSubpath()
            rCtx.fill(dome, with: .color(TempoMascotPalette.orange))
        }
        
        // Center Striker Hammer
        ctx.drawLayer { hCtx in
            hCtx.translateBy(x: 120, y: 24)
            hCtx.rotate(by: .degrees(config.hammerDroop ? 28 : config.hammerAngle))
            strokeLine(&hCtx, from: .zero, to: CGPoint(x: 0, y: -16), color: TempoMascotPalette.orange, width: 6)
            let head = Path(roundedRect: CGRect(x: -11, y: -22, width: 22, height: 9), cornerRadius: 4.5)
            hCtx.fill(head, with: .color(TempoMascotPalette.carbon))
        }
        
        fade(config.effectiveFX.ringWaves, &ctx) { ctx in
            var lw = Path()
            lw.addArc(center: CGPoint(x: 44, y: 34), radius: 28, startAngle: .degrees(195), endAngle: .degrees(255), clockwise: false)
            ctx.stroke(lw, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            
            var rw = Path()
            rw.addArc(center: CGPoint(x: 196, y: 34), radius: 28, startAngle: .degrees(285), endAngle: .degrees(345), clockwise: false)
            ctx.stroke(rw, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
    
    private func drawPusherEars(ctx: inout GraphicsContext) {
        let leftDepth = max(0, -config.turnX * 0.4) - config.leftEarClick
        let rightDepth = max(0, config.turnX * 0.4) - config.rightEarClick
        
        // Left Pusher Ear (Black #1A1A1A)
        ctx.drawLayer { lCtx in
            lCtx.translateBy(x: 62 - leftDepth, y: 50)
            lCtx.rotate(by: .degrees(-38))
            lCtx.fill(Path(roundedRect: CGRect(x: -8, y: -12, width: 16, height: 26), cornerRadius: 5), with: .color(TempoMascotPalette.carbon))
            lCtx.fill(Path(roundedRect: CGRect(x: -13, y: -22, width: 26, height: 12), cornerRadius: 5), with: .color(TempoMascotPalette.carbon))
        }
        
        fade(config.effectiveFX.leftSpark, &ctx) { ctx in
            strokeLine(&ctx, from: CGPoint(x: 26, y: 26), to: CGPoint(x: 38, y: 34), color: TempoMascotPalette.orange, width: 4)
            strokeLine(&ctx, from: CGPoint(x: 36, y: 16), to: CGPoint(x: 44, y: 28), color: TempoMascotPalette.orange, width: 4)
        }
        
        // Right Pusher Ear (International Orange #FF4F00)
        ctx.drawLayer { rCtx in
            rCtx.translateBy(x: 178 + rightDepth, y: 50)
            rCtx.rotate(by: .degrees(38))
            rCtx.fill(Path(roundedRect: CGRect(x: -8, y: -12, width: 16, height: 26), cornerRadius: 5), with: .color(TempoMascotPalette.orange))
            rCtx.fill(Path(roundedRect: CGRect(x: -13, y: -22, width: 26, height: 12), cornerRadius: 5), with: .color(TempoMascotPalette.orange))
        }
    }
    
    private func drawEyesAndBrows(ctx: inout GraphicsContext, pX: CGFloat, pY: CGFloat, primaryInk: Color, faceFill: Color) {
        let lX = 86.0 + pX
        let rX = 154.0 + pY * 0.0 + pX
        let eY = 118.0 + pY
        
        ctx.drawLayer { ctx in
        ctx.translateBy(x: 0, y: eY)
        ctx.scaleBy(x: 1, y: max(0.06, Double(config.eyeOpenness)))
        ctx.translateBy(x: 0, y: -eY)
        switch config.eyes {
        case .idle:
            ctx.fill(Path(roundedRect: CGRect(x: lX - 6, y: eY - 12, width: 12, height: 22), cornerRadius: 6), with: .color(primaryInk))
            ctx.fill(Path(roundedRect: CGRect(x: rX - 6, y: eY - 12, width: 12, height: 22), cornerRadius: 6), with: .color(primaryInk))
        case .focus:
            ctx.fill(Path(roundedRect: CGRect(x: lX - 6, y: eY - 8, width: 12, height: 17), cornerRadius: 6), with: .color(primaryInk))
            ctx.fill(Path(roundedRect: CGRect(x: rX - 6, y: eY - 8, width: 12, height: 17), cornerRadius: 6), with: .color(primaryInk))
        case .lookup:
            ctx.fill(Path(roundedRect: CGRect(x: lX - 6, y: eY - 17, width: 12, height: 20), cornerRadius: 6), with: .color(primaryInk))
            ctx.fill(Path(roundedRect: CGRect(x: rX - 6, y: eY - 17, width: 12, height: 20), cornerRadius: 6), with: .color(primaryInk))
        case .wide:
            ctx.fill(Path(ellipseIn: CGRect(x: lX - 9.5, y: eY - 9.5, width: 19, height: 19)), with: .color(primaryInk))
            ctx.fill(Path(ellipseIn: CGRect(x: rX - 9.5, y: eY - 9.5, width: 19, height: 19)), with: .color(primaryInk))
            ctx.fill(Path(ellipseIn: CGRect(x: lX - 6, y: eY - 6, width: 6, height: 6)), with: .color(faceFill))
            ctx.fill(Path(ellipseIn: CGRect(x: rX - 6, y: eY - 6, width: 6, height: 6)), with: .color(faceFill))
        case .happy:
            for cx in [lX, rX] {
                var p = Path()
                p.addArc(center: CGPoint(x: cx, y: eY + 3), radius: 10, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                ctx.stroke(p, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
            }
        case .sleepy:
            for cx in [lX, rX] {
                var p = Path()
                p.addArc(center: CGPoint(x: cx, y: eY - 2), radius: 9.5, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                ctx.stroke(p, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
        case .wink:
            var p = Path()
            p.addArc(center: CGPoint(x: lX, y: eY + 2), radius: 9.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.stroke(p, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            ctx.fill(Path(roundedRect: CGRect(x: rX - 6, y: eY - 11, width: 12, height: 21), cornerRadius: 6), with: .color(primaryInk))
        case .chill:
            strokeLine(&ctx, from: CGPoint(x: lX - 10, y: eY), to: CGPoint(x: lX + 10, y: eY), color: primaryInk, width: 6)
            strokeLine(&ctx, from: CGPoint(x: rX - 10, y: eY), to: CGPoint(x: rX + 10, y: eY), color: primaryInk, width: 6)
        case .squint:
            var lp = Path()
            lp.move(to: CGPoint(x: lX - 9, y: eY - 7))
            lp.addLine(to: CGPoint(x: lX + 7, y: eY))
            lp.addLine(to: CGPoint(x: lX - 9, y: eY + 7))
            ctx.stroke(lp, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            var rp = Path()
            rp.move(to: CGPoint(x: rX + 9, y: eY - 7))
            rp.addLine(to: CGPoint(x: rX - 7, y: eY))
            rp.addLine(to: CGPoint(x: rX + 9, y: eY + 7))
            ctx.stroke(rp, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
        }
        }
        
        switch config.brows {
        case .none: break
        case .focus:
            strokeLine(&ctx, from: CGPoint(x: lX - 11, y: eY - 18), to: CGPoint(x: lX + 9, y: eY - 12), color: primaryInk, width: 5)
            strokeLine(&ctx, from: CGPoint(x: rX + 11, y: eY - 18), to: CGPoint(x: rX - 9, y: eY - 12), color: primaryInk, width: 5)
        case .curious:
            strokeLine(&ctx, from: CGPoint(x: lX - 10, y: eY - 16), to: CGPoint(x: lX + 10, y: eY - 16), color: primaryInk, width: 5)
            var rb = Path()
            rb.move(to: CGPoint(x: rX - 10, y: eY - 18))
            rb.addQuadCurve(to: CGPoint(x: rX + 10, y: eY - 18), control: CGPoint(x: rX, y: eY - 27))
            ctx.stroke(rb, with: .color(primaryInk), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        case .worried:
            strokeLine(&ctx, from: CGPoint(x: lX - 10, y: eY - 13), to: CGPoint(x: lX + 9, y: eY - 19), color: primaryInk, width: 4.5)
            strokeLine(&ctx, from: CGPoint(x: rX - 9, y: eY - 19), to: CGPoint(x: rX + 10, y: eY - 13), color: primaryInk, width: 4.5)
        }
    }
    
    private func drawMouth(ctx: inout GraphicsContext, pX: CGFloat, pY: CGFloat, primaryInk: Color) {
        let mCx = 120.0 + pX
        let mCy = 166.0 + pY
        let pop = max(0.05, Double(config.mouthScale))
        ctx.translateBy(x: mCx, y: mCy)
        ctx.scaleBy(x: pop, y: pop)
        ctx.translateBy(x: -mCx, y: -mCy)
        
        switch config.mouth {
        case .smile:
            var p = Path()
            p.move(to: CGPoint(x: mCx - 16, y: mCy - 2))
            p.addQuadCurve(to: CGPoint(x: mCx + 16, y: mCy - 2), control: CGPoint(x: mCx, y: mCy + 14))
            ctx.stroke(p, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        case .orangeSmile:
            var p = Path()
            p.move(to: CGPoint(x: mCx - 19, y: mCy - 3))
            p.addQuadCurve(to: CGPoint(x: mCx + 19, y: mCy - 3), control: CGPoint(x: mCx, y: mCy + 17))
            ctx.stroke(p, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        case .openHappy:
            var p = Path()
            p.addArc(center: CGPoint(x: mCx, y: mCy - 5), radius: 17, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            p.closeSubpath()
            ctx.fill(p, with: .color(TempoMascotPalette.orange))
        case .determined:
            strokeLine(&ctx, from: CGPoint(x: mCx - 13, y: mCy + 4), to: CGPoint(x: mCx + 13, y: mCy + 1), color: primaryInk, width: 6)
        case .oSmall:
            let r = CGRect(x: mCx - 6.5, y: mCy - 3.5, width: 13, height: 13)
            ctx.stroke(Path(ellipseIn: r), with: .color(primaryInk), lineWidth: 5.5)
        case .oBig:
            let r = CGRect(x: mCx - 10.5, y: mCy - 7.5, width: 21, height: 21)
            ctx.fill(Path(ellipseIn: r), with: .color(TempoMascotPalette.orange))
        case .smirk:
            var p = Path()
            p.move(to: CGPoint(x: mCx - 10, y: mCy + 3))
            p.addQuadCurve(to: CGPoint(x: mCx + 16, y: mCy - 4), control: CGPoint(x: mCx + 5, y: mCy + 9))
            ctx.stroke(p, with: .color(primaryInk), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        case .squish:
            var p = Path()
            p.move(to: CGPoint(x: mCx - 16, y: mCy + 4))
            p.addQuadCurve(to: CGPoint(x: mCx, y: mCy + 4), control: CGPoint(x: mCx - 8, y: mCy - 4))
            p.addQuadCurve(to: CGPoint(x: mCx + 16, y: mCy + 4), control: CGPoint(x: mCx + 8, y: mCy + 12))
            ctx.stroke(p, with: .color(TempoMascotPalette.orange), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        }
    }
    
    /// Draws `body` at `amount` opacity; skips work when effectively invisible.
    private func fade(_ amount: Double, _ ctx: inout GraphicsContext, _ body: (inout GraphicsContext) -> Void) {
        guard amount > 0.01 else { return }
        ctx.drawLayer { layer in
            layer.opacity = min(1.0, amount)
            body(&layer)
        }
    }
    
    private func polar(cx: Double, cy: Double, r: Double, deg: Double) -> CGPoint {
        let rad = (deg - 90.0) * .pi / 180.0
        return CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))
    }
    
    private func strokeLine(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color, width: CGFloat) {
        var p = Path()
        p.move(to: from)
        p.addLine(to: to)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

// MARK: - Interactive Mascot (drag to look · tap to squish · ear clicks), all spring-driven

public struct TempoMascotLive: Sendable {
    public var regime: TempoMascotRegime
    public var minuteAngle: Double?
    public var hourAngle: Double?
    public var bezelProgress: Double?
    
    public init(
        regime: TempoMascotRegime,
        minuteAngle: Double? = nil,
        hourAngle: Double? = nil,
        bezelProgress: Double? = nil
    ) {
        self.regime = regime
        self.minuteAngle = minuteAngle
        self.hourAngle = hourAngle
        self.bezelProgress = bezelProgress
    }
}

public struct TempoInteractiveMascotView: View {
    public var size: CGFloat
    public var onLeftEarTap: (() -> Void)?
    public var onRightEarTap: (() -> Void)?
    public var onBodyTap: (() -> Void)?
    
    private let live: @MainActor (Date) -> TempoMascotLive
    private let hasLiveMinute: Bool
    
    @State private var dynamics = MascotDynamics()
    
    /// Static regime with optional fixed overrides.
    public init(
        regime: TempoMascotRegime,
        size: CGFloat = 210,
        overrideMinuteAngle: Double? = nil,
        overrideHourAngle: Double? = nil,
        overrideBezelProgress: Double? = nil,
        onLeftEarTap: (() -> Void)? = nil,
        onRightEarTap: (() -> Void)? = nil,
        onBodyTap: (() -> Void)? = nil
    ) {
        let fixed = TempoMascotLive(
            regime: regime,
            minuteAngle: overrideMinuteAngle,
            hourAngle: overrideHourAngle,
            bezelProgress: overrideBezelProgress
        )
        self.live = { _ in fixed }
        self.hasLiveMinute = overrideMinuteAngle != nil
        self.size = size
        self.onLeftEarTap = onLeftEarTap
        self.onRightEarTap = onRightEarTap
        self.onBodyTap = onBodyTap
    }
    
    /// Per-frame provider: lets timers and stopwatches feed the mascot without re-rendering their page.
    public init(
        size: CGFloat = 210,
        providesMinuteAngle: Bool = false,
        onLeftEarTap: (() -> Void)? = nil,
        onRightEarTap: (() -> Void)? = nil,
        onBodyTap: (() -> Void)? = nil,
        live: @escaping @MainActor (Date) -> TempoMascotLive
    ) {
        self.live = live
        self.hasLiveMinute = providesMinuteAngle
        self.size = size
        self.onLeftEarTap = onLeftEarTap
        self.onRightEarTap = onRightEarTap
        self.onBodyTap = onBodyTap
    }
    
    public var body: some View {
        ZStack {
            MascotStage(size: size, autoSweep: !hasLiveMinute, dynamics: dynamics, goal: goal)
            
            // Invisible hit zones: left ear, right ear, dial body.
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: size * 0.42, height: size * 0.34)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dynamics.pressLeftEar()
                            onLeftEarTap?()
                        }
                    Spacer()
                    Color.clear
                        .frame(width: size * 0.42, height: size * 0.34)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            dynamics.pressRightEar()
                            onRightEarTap?()
                        }
                }
                Color.clear
                    .frame(width: size * 0.85, height: size * 0.66)
                    .contentShape(Circle())
                    .onTapGesture {
                        dynamics.squish()
                        onBodyTap?()
                    }
            }
            .frame(width: size, height: size)
        }
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    dynamics.dragX = max(-10, min(10, value.translation.width * 0.12))
                    dynamics.dragY = max(-6, min(6, value.translation.height * 0.08))
                }
                .onEnded { _ in
                    dynamics.dragX = 0
                    dynamics.dragY = 0
                }
        )
    }
    
    private var goal: @MainActor (Date) -> TempoMascotConfig {
        let provider = live
        let dyn = dynamics
        return { date in
            let state = provider(date)
            var cfg = TempoMascotConfig.from(regime: state.regime)
            if let m = state.minuteAngle { cfg.minuteAngle = m }
            if let h = state.hourAngle { cfg.hourAngle = h }
            if let p = state.bezelProgress { cfg.bezelProgress = p }
            cfg.turnX = max(-11, min(11, cfg.turnX + CGFloat(dyn.dragX)))
            cfg.turnY = max(-7, min(7, cfg.turnY + CGFloat(dyn.dragY)))
            cfg.tiltDegrees += dyn.dragX * 0.65
            return cfg
        }
    }
}
