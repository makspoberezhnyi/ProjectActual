import SwiftUI
import SwiftData

@main
struct ActualApp: App {
    /// The store lives in a shared app group so the widget and its intents read exactly
    /// what the app writes, rather than a copy pushed across by hand.
    private let container = SharedStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.ink)
        }
        .modelContainer(container)
    }
}
