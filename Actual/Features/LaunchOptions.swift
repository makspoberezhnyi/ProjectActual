import Foundation

#if DEBUG
/// Opens the app straight onto a given screen from a launch argument, so screens can
/// be captured and compared against the design reference without driving the UI by
/// hand. Debug builds only, and it reads nothing unless the argument is passed.
///
///     xcrun simctl launch booted app.actual.Actual -startOn insights
enum LaunchOptions {
    private static var requested: String? {
        UserDefaults.standard.string(forKey: "startOn")
    }

    static var destination: Destination {
        requested == "insights" ? .insights : .home
    }

    static var opensCapture: Bool { requested == "capture" }
    static var opensActiveSession: Bool { requested == "active" }
    /// Ends whatever is running on launch, through the same path the End button uses,
    /// so the outcome screen can be captured without driving the UI by hand.
    static var endsRunningSession: Bool { requested == "end" }

    /// Pre-fills the capture screen's title, so the state where history is already
    /// matched can be captured without typing into the simulator.
    /// A synthetic free window, so the gap filler can be exercised without writing
    /// events into the simulator's calendar.
    static var fakeGapMinutes: Int? {
        let value = UserDefaults.standard.integer(forKey: "fakeGap")
        return value > 0 ? value : nil
    }

    /// Shortens the arrival dwell, so an auto-closing trip can be verified without
    /// sitting through two real minutes of parked car.
    static var dwellSeconds: TimeInterval? {
        let value = UserDefaults.standard.double(forKey: "dwellSeconds")
        return value > 0 ? value : nil
    }

    static var captureTitle: String {
        UserDefaults.standard.string(forKey: "captureTitle") ?? ""
    }
}
#endif
