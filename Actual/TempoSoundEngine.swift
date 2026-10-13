import Foundation
import AVFoundation
import AudioToolbox
import UIKit

/// Plays the twin-bell chime while an alarm or a finished timer is ringing in the app.
/// Uses the `.playback` audio session so it still rings with the silent switch on.
@MainActor
final class TempoSoundEngine {
    static let shared = TempoSoundEngine()

    /// File name shared with notification sounds so the lock screen and the app ring the same bells.
    nonisolated static let chimeFileName = "tempo_chime.wav"

    private var player: AVAudioPlayer?
    private var hapticTask: Task<Void, Never>?
    private var autoStopTask: Task<Void, Never>?

    private(set) var isRinging = false

    private init() {}

    /// Starts looping the chime with a heartbeat of haptics. Stops by itself after `maxDuration`.
    func startRinging(maxDuration: TimeInterval = 120) {
        stopRinging()
        isRinging = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)

        if let url = Bundle.main.url(forResource: "tempo_chime", withExtension: "wav"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.numberOfLoops = -1
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            self.player = player
        }

        hapticTask = Task { @MainActor [weak self] in
            while !Task.isCancelled, self?.isRinging == true {
                // Falls back to a system alarm tone when the bundled chime is missing.
                if self?.player == nil {
                    AudioServicesPlaySystemSound(1005)
                }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                try? await Task.sleep(for: .seconds(1.25))
            }
        }

        autoStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(maxDuration))
            guard !Task.isCancelled else { return }
            self?.stopRinging()
        }
    }

    func stopRinging() {
        isRinging = false
        hapticTask?.cancel()
        hapticTask = nil
        autoStopTask?.cancel()
        autoStopTask = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
