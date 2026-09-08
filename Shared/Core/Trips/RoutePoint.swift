import Foundation

/// One recorded position along a trip.
///
/// Kept separate from `LocationSample` even though the shape overlaps: this is what
/// gets persisted and drawn, so it is deliberately a plain `Codable` value with no
/// dependency on CoreLocation, the same reasoning that keeps the bias engine free of
/// SwiftUI imports.
public struct RoutePoint: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date

    public init(latitude: Double, longitude: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }

    public init(coordinate: Coordinate, timestamp: Date) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
    }

    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }
}

/// Encodes and decodes a route for storage on a session, and does the plain arithmetic
/// a route implies: how far it covers, once travelled.
public enum RouteCodec {
    public static func encode(_ points: [RoutePoint]) -> Data? {
        try? JSONEncoder().encode(points)
    }

    public static func decode(_ data: Data?) -> [RoutePoint] {
        guard let data, let points = try? JSONDecoder().decode([RoutePoint].self, from: data) else {
            return []
        }
        return points
    }

    /// Total distance in metres, summing consecutive point-to-point legs.
    ///
    /// A straight line between the first and last point would understate any trip that
    /// isn't literally a straight road, so this walks the actual recorded path instead.
    public static func distanceMeters(_ points: [RoutePoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0.0) { total, pair in
            total + pair.0.coordinate.distance(to: pair.1.coordinate)
        }
    }
}
