import Testing
import Foundation
@testable import Actual

struct RoutePointTests {

    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func point(_ lat: Double, _ lon: Double, after seconds: TimeInterval = 0) -> RoutePoint {
        RoutePoint(latitude: lat, longitude: lon, timestamp: start.addingTimeInterval(seconds))
    }

    @Test("A route round-trips through encoding without losing a point")
    func roundTrips() throws {
        let points = [point(52.23, 21.01), point(52.20, 20.99, after: 60), point(52.17, 20.97, after: 120)]
        let data = try #require(RouteCodec.encode(points))
        #expect(RouteCodec.decode(data) == points)
    }

    @Test("Decoding nil or garbage data yields an empty route rather than crashing")
    func decodesGracefully() {
        #expect(RouteCodec.decode(nil).isEmpty)
        #expect(RouteCodec.decode(Data("not json".utf8)).isEmpty)
    }

    @Test("Distance walks the recorded path, not a straight line between the ends")
    func distanceFollowsThePath() {
        // A right-angle dogleg: the walked distance must exceed the straight-line hop
        // between the first and last point.
        let points = [point(52.20, 21.00), point(52.20, 21.05), point(52.25, 21.05)]
        let walked = RouteCodec.distanceMeters(points)
        let straightLine = points.first!.coordinate.distance(to: points.last!.coordinate)
        #expect(walked > straightLine)
    }

    @Test("A single point or an empty route covers no distance")
    func noDistanceWithoutTwoPoints() {
        #expect(RouteCodec.distanceMeters([]) == 0)
        #expect(RouteCodec.distanceMeters([point(52.2, 21.0)]) == 0)
    }
}

struct DistanceFormattingTests {

    @Test(
        "Short distances read in metres, longer ones in kilometres",
        arguments: [(120.0, "120m"), (947.0, "940m"), (1000.0, "1.0 km"), (6_420.0, "6.4 km")]
    )
    func formatting(meters: Double, expected: String) {
        #expect(DurationFormatting.distance(meters: meters) == expected)
    }
}
