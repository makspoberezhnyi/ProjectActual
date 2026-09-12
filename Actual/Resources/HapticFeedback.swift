import UIKit

/// A centralized haptics utility to avoid scattering `UIImpactFeedbackGenerator` calls
/// throughout the codebase. This makes it easy to add or adjust haptic feedback patterns
/// without hunting through every view file.
///
/// Usage: `HapticFeedback.lightImpact()` for button taps, `HapticFeedback.heavyImpact()`
/// for destructive actions, etc.
struct HapticFeedback {
    /// Light impact for subtle interactions like button taps or small gestures
    static func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact for significant interactions like toggles or card selections
    static func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact for destructive actions like delete or clear
    static func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Selection haptic for scrubbing through discrete values (e.g., chips, tags)
    static func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Completion haptic for when an action finishes successfully
    static func completion() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.5)
    }

    /// Notification haptic for alerts or important events
    static func notification() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
