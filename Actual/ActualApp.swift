import SwiftUI
import SwiftData

@main
struct ActualApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Session.self)
    }
}
