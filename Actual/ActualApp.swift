import SwiftUI
import SwiftData

@main
struct ActualApp: App {
    init() {
        _ = NotificationManager.shared
        WatchConnectivityManager.shared.activate()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
    }
}
