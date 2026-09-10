import WidgetKit
import SwiftUI
import AppIntents

/// A Control Center / Lock Screen control: the same blind start the widget's own
/// "Start" button and "Hey Siri, start a session" use, `StartSessionIntent()` with no
/// category, reachable from the two customizable slots on the Lock Screen (the ones
/// that default to Flashlight and Camera) or from Control Center itself, without
/// unlocking the phone first.
///
/// This is a genuinely different mechanism from the widget above — `ControlWidget`
/// rather than `Widget` — but needs no new extension or entitlement: Controls run in
/// the same `com.apple.widgetkit-extension` this target already declares, so adding
/// one here is exactly what `ActualWidgetBundle` is for.
struct StartSessionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "StartSessionControl") {
            ControlWidgetButton(action: StartSessionIntent()) {
                Label("Start a session", systemImage: "play.fill")
            }
        }
        .displayName("Start a session")
        .description("Starts an unlabelled session in Actual — you say what it was when you stop.")
    }
}
