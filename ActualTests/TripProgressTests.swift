import Testing
import Foundation
@testable import Actual

struct TripProgressTests {

    private let detector = TripProgressDetector()
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    // Warsaw centre to Chopin Airport, roughly.
    private let home = Coordinate(latitude: 52.2297, longitude: 21.0122)
    private let airport = Coordinate(latitude: 52.1657, longitude: 20.9671)

    private func sample(
        _ coordinate: Coordinate,
        after seconds: TimeInterval,
        accuracy: Double = 10
    ) -> LocationSample {
        LocationSample(
            coordinate: coordinate,
            timestamp: start.addingTimeInterval(seconds),
            horizontalAccuracy: accuracy
        )
    }

    /// A point a given number of metres north of another.
    private func north(of coordinate: Coordinate, metres: Double) -> Coordinate {
        Coordinate(
            latitude: coordinate.latitude + metres / 111_320,
            longitude: coordinate.longitude
        )
    }

    // MARK: - Distance

    @Test("Distance between two points is measured in metres")
    func distance() {
        let metres = home.distance(to: airport)
        // Roughly seven and a half kilometres as the crow flies.
        #expect(metres > 7_000 && metres < 8_500)
    }

    @Test("A point a known distance away measures as that distance")
    func knownDistance() {
        #expect(abs(home.distance(to: north(of: home, metres: 500)) - 500) < 5)
    }

    // MARK: - Departure

    @Test("Sitting at the origin is not a departure")
    func staysUntilItMoves() {
        let phase = detector.advance(
            .awaitingDeparture,
            with: sample(north(of: home, metres: 50), after: 60),
            origin: home,
            destination: airport
        )
        #expect(phase == .awaitingDeparture)
    }

    @Test("Moving past the threshold counts as leaving")
    func departs() {
        let phase = detector.advance(
            .awaitingDeparture,
            with: sample(north(of: home, metres: 400), after: 120),
            origin: home,
            destination: airport
        )
        #expect(phase == .enRoute)
    }

    // MARK: - Arrival

    @Test("Reaching the destination starts a dwell, it is not yet an arrival")
    func reachingStartsDwell() {
        let phase = detector.advance(
            .enRoute,
            with: sample(airport, after: 1_500),
            origin: home,
            destination: airport
        )
        #expect(phase == .settling(since: start.addingTimeInterval(1_500)))
    }

    @Test("Stopping briefly inside the radius is a red light, not an arrival")
    func briefStopIsNotArrival() {
        // Twenty seconds is a traffic light. Closing the session here would write a
        // duration that never happened.
        var phase = detector.advance(.enRoute, with: sample(airport, after: 1_500), origin: home, destination: airport)
        phase = detector.advance(phase, with: sample(airport, after: 1_520), origin: home, destination: airport)
        #expect(phase == .settling(since: start.addingTimeInterval(1_500)))
    }

    @Test("Moving off again cancels the dwell")
    func movingOffCancelsDwell() {
        var phase = detector.advance(.enRoute, with: sample(airport, after: 1_500), origin: home, destination: airport)
        phase = detector.advance(
            phase,
            with: sample(north(of: airport, metres: 900), after: 1_560),
            origin: home, destination: airport
        )
        #expect(phase == .enRoute)
    }

    @Test("Staying put past the dwell is an arrival, timed from when it stopped")
    func arrives() {
        var phase = detector.advance(.enRoute, with: sample(airport, after: 1_500), origin: home, destination: airport)
        phase = detector.advance(phase, with: sample(airport, after: 1_560), origin: home, destination: airport)
        phase = detector.advance(phase, with: sample(airport, after: 1_625), origin: home, destination: airport)

        // The trip ended when the car stopped, not two minutes later when we became sure.
        #expect(phase == .arrived(at: start.addingTimeInterval(1_500)))
    }

    @Test("Arrival is reported once, not on every reading after it")
    func arrivalReportedOnce() {
        let settling = TripPhase.settling(since: start)
        let arrived = detector.advance(
            settling,
            with: sample(airport, after: 200),
            origin: home, destination: airport
        )
        #expect(detector.arrivalTime(from: settling, to: arrived) == start)
        #expect(detector.arrivalTime(from: arrived, to: arrived) == nil)
    }

    // MARK: - Bad readings

    @Test("A reading too vague to trust is ignored rather than acted on")
    func ignoresVagueReadings() {
        // Accuracy of half a kilometre could place the car anywhere; treating it as an
        // arrival would end the trip in the wrong place at the wrong time.
        let phase = detector.advance(
            .enRoute,
            with: sample(airport, after: 1_500, accuracy: 500),
            origin: home,
            destination: airport
        )
        #expect(phase == .enRoute)
    }

    // MARK: - A whole trip

    @Test("A full drive runs from waiting, through moving, to arrived")
    func wholeTrip() {
        var phase = TripPhase.awaitingDeparture
        var departure: Date?
        var arrival: Date?

        // Sitting at home, then driving out, then most of the way, then parked.
        let route: [(Coordinate, TimeInterval)] = [
            (home, 0),
            (north(of: home, metres: 60), 30),
            (north(of: home, metres: 500), 90),
            (Coordinate(latitude: 52.20, longitude: 20.99), 600),
            (airport, 1_500),
            (airport, 1_560),
            (airport, 1_640)
        ]

        for (coordinate, seconds) in route {
            let reading = sample(coordinate, after: seconds)
            let next = detector.advance(phase, with: reading, origin: home, destination: airport)
            departure = departure ?? detector.departureTime(from: phase, to: next, sample: reading)
            arrival = arrival ?? detector.arrivalTime(from: phase, to: next)
            phase = next
        }

        #expect(departure == start.addingTimeInterval(90))
        #expect(arrival == start.addingTimeInterval(1_500))
        // Twenty-three and a half minutes of actual driving, measured without a tap.
        let minutes = Int(arrival!.timeIntervalSince(departure!) / 60)
        #expect(minutes == 23)
    }
}
