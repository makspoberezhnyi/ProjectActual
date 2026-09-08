import Foundation

/// Duration rendering, kept in Core so the phone, watch and Mac all read a number
/// the same way rather than each inventing its own formatting.
public enum DurationFormatting {

    /// "4.2 km" / "850 m" — the same plain-fact tone as everything else. No pace, no
    /// judgment on the number, just the distance covered.
    public static func distance(meters: Double) -> String {
        guard meters >= 950 else { return "\(Int(meters.rounded() / 10) * 10)m" }
        return String(format: "%.1f km", meters / 1000)
    }


    /// "2h 40m", "38m", "1h". Used wherever an estimate or a logged actual is shown.
    public static func compact(minutes: Int) -> String {
        let safe = max(0, minutes)
        let hours = safe / 60
        let mins = safe % 60

        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }

    /// "2h 00m" — the padded form used where a guess sits as the headline number and
    /// a bare "2h" would read as less deliberate than it is.
    public static func padded(minutes: Int) -> String {
        let safe = max(0, minutes)
        let hours = safe / 60
        let mins = safe % 60

        if hours == 0 { return "\(mins)m" }
        return String(format: "%dh %02dm", hours, mins)
    }

    /// "38m", "2h 40m", "172h". Past a certain size the minutes stop carrying meaning
    /// and only cost the layout a line break, so a running total drops them.
    public static func coarse(minutes: Int) -> String {
        let safe = max(0, minutes)
        guard safe >= 600 else { return compact(minutes: safe) }
        return "\((safe + 30) / 60)h"
    }

    /// "42:18" while running, rolling over to "1:02:47" past the hour.
    public static func clock(seconds: Int) -> String {
        let safe = max(0, seconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let secs = safe % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// "+78%" / "-12%" / "+0%". The sign carries the direction, so the surrounding
    /// copy can stay neutral about whether that is good or bad.
    public static func signedPercent(_ proportion: Double) -> String {
        let percent = Int((proportion * 100).rounded())
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }

    /// "19%" — magnitude only, for the aggregate headline.
    public static func percent(_ proportion: Double) -> String {
        "\(Int((abs(proportion) * 100).rounded()))%"
    }
}
