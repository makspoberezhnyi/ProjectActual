import Testing
@testable import Actual

struct DurationFormattingTests {

    @Test(
        "Compact durations read the way the design writes them",
        arguments: [(0, "0m"), (38, "38m"), (60, "1h"), (90, "1h 30m"), (160, "2h 40m")]
    )
    func compact(minutes: Int, expected: String) {
        #expect(DurationFormatting.compact(minutes: minutes) == expected)
    }

    @Test(
        "Padded durations keep two digits on the minutes",
        arguments: [(120, "2h 00m"), (167, "2h 47m"), (45, "45m")]
    )
    func padded(minutes: Int, expected: String) {
        #expect(DurationFormatting.padded(minutes: minutes) == expected)
    }

    @Test(
        "The running clock rolls over to hours past sixty minutes",
        arguments: [(2538, "42:18"), (59, "0:59"), (3767, "1:02:47")]
    )
    func clock(seconds: Int, expected: String) {
        #expect(DurationFormatting.clock(seconds: seconds) == expected)
    }

    @Test(
        "Long running totals drop minutes rather than wrapping a layout",
        arguments: [(38, "38m"), (160, "2h 40m"), (599, "9h 59m"), (600, "10h"), (10318, "172h")]
    )
    func coarse(minutes: Int, expected: String) {
        #expect(DurationFormatting.coarse(minutes: minutes) == expected)
    }

    @Test("Percentages carry their sign so the copy around them can stay neutral")
    func signedPercent() {
        #expect(DurationFormatting.signedPercent(0.78) == "+78%")
        #expect(DurationFormatting.signedPercent(-0.12) == "-12%")
        #expect(DurationFormatting.signedPercent(0) == "+0%")
    }

    @Test("Negative durations clamp rather than rendering nonsense")
    func negativeClamps() {
        #expect(DurationFormatting.compact(minutes: -10) == "0m")
        #expect(DurationFormatting.clock(seconds: -5) == "0:00")
    }
}

struct ContextTagTests {

    @Test("Tags normalise so the same situation is one key, not several")
    func normalisation() {
        #expect(ContextTag("  High Pressure ") == ContextTag.highPressure)
        #expect(ContextTag("NORMAL") == ContextTag.normal)
    }

    @Test("Custom tags are stored exactly like defaults, just not in the default set")
    func customTags() {
        let custom = ContextTag("kids are home")
        #expect(custom.isDefault == false)
        #expect(ContextTag.normal.isDefault == true)
        #expect(custom.displayName == "Kids are home")
    }
}
