import SwiftUI
import UIKit
import UserNotifications

/// Pictures of the mascot for the right side of notifications: ringing for alarms,
/// sleepy for bedtime, celebrating when a timer ends. Rendered from the real mascot, then cached.
@MainActor
enum TempoNotificationArt {
    private static var cache: [TempoMascotRegime: URL] = [:]

    static func attachment(_ regime: TempoMascotRegime) -> UNNotificationAttachment? {
        guard let source = renderedPNG(regime) else { return nil }
        // The system moves attachment files into its own store, so it gets a fresh copy each time.
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("tempo-\(UUID().uuidString).png")
        guard (try? FileManager.default.copyItem(at: source, to: copy)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: regime.rawValue, url: copy, options: nil)
    }

    private static func renderedPNG(_ regime: TempoMascotRegime) -> URL? {
        if let url = cache[regime], FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let art = ZStack {
            DeskBackdrop(horizon: 0.64)
            MascotStanding(regime: regime, size: 150, x: 90, feetY: 160)
        }
        .frame(width: 180, height: 180)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: art)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let name = "tempo-art-" + regime.rawValue.replacingOccurrences(of: " ", with: "-") + ".png"
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        guard (try? data.write(to: url)) != nil else { return nil }
        cache[regime] = url
        return url
    }
}
