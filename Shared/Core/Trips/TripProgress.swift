import Foundation

/// A point on the earth, kept free of CoreLocation so the detection logic below can be
/// tested with literals.
public struct Coordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in metres.
    public func distance(to other: Coordinate) -> Double {
        let earthRadius = 6_371_000.0
        let phi1 = latitude * .pi / 180
        let phi2 = other.latitude * .pi / 180
        let deltaPhi = (other.latitude - latitude) * .pi / 180
        let deltaLambda = (other.longitude - longitude) * .pi / 180

        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2)
            + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// One reading from the device.
public struct LocationSample: Equatable, Sendable {
    public let coordinate: Coordinate
    public let timestamp: Date
    /// Metres. A reading too vague to trust is ignored rather than acted on.
    public let horizontalAccuracy: Double

    public init(coordinate: Coordinate, timestamp: Date, horizontalAccuracy: Double = 10) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }
}

/// Where a trip has got to.
public enum TripPhase: Equatable, Sendable {
    /// Started, but the person has not actually left yet.
    case awaitingDeparture
    /// Moving, and not yet at the destination.
    case enRoute
    /// Inside the destination radius, waiting to see whether this is an arrival or a
    /// red light.
    case settling(since: Date)
    /// Arrived, at this moment.
    case arrived(at: Date)
}

/// Decides when a trip actually began and ended, from location readings alone.
///
/// The dwell requirement is the whole point: a car stopped inside the destination radius
/// for ten seconds is a traffic light, not an arrival. Closing a session on the first
/// reading inside the radius would write a wrong duration and quietly corrupt the very
/// history the engine depends on.
public struct TripProgressDetector: Sendable {

    public struct Configuration: Sendable {
        /// How far from the origin counts as having left.
        public var departureRadiusMeters: Double
        /// How close to the destination counts as being there.
        public var arrivalRadiusMeters: Double
        /// How long the position must stay inside that radius before it is an arrival.
        public var dwellSeconds: TimeInterval
        /// Readings vaguer than this are ignored.
        public var accuracyCeilingMeters: Double

        public init(
            departureRadiusMeters: Double = 200,
            arrivalRadiusMeters: Double = 150,
            dwellSeconds: TimeInterval = 120,
            accuracyCeilingMeters: Double = 200
        ) {
            self.departureRadiusMeters = departureRadiusMeters
            self.arrivalRadiusMeters = arrivalRadiusMeters
            self.dwellSeconds = dwellSeconds
            self.accuracyCeilingMeters = accuracyCeilingMeters
        }

        public static let standard = Configuration()
    }

    public let configuration: Configuration

    public init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    /// Advances the phase by one reading.
    ///
    /// Pure: same inputs, same output, no clock of its own. The caller supplies the
    /// reading and its timestamp, which is what makes the whole thing testable without
    /// waiting two real minutes for a dwell.
    public func advance(
        _ phase: TripPhase,
        with sample: LocationSample,
        origin: Coordinate?,
        destination: Coordinate
    ) -> TripPhase {
        // A reading this vague could place the car anywhere; acting on it is worse than
        // waiting for a better one.
        guard sample.horizontalAccuracy <= configuration.accuracyCeilingMeters else { return phase }

        let toDestination = sample.coordinate.distance(to: destination)

        switch phase {
        case .awaitingDeparture:
            // Already at the destination when the trip started: nothing to travel.
            if toDestination <= configuration.arrivalRadiusMeters, origin == nil {
                return .settling(since: sample.timestamp)
            }
            guard let origin else { return .enRoute }
            return sample.coordinate.distance(to: origin) > configuration.departureRadiusMeters
                ? .enRoute
                : .awaitingDeparture

        case .enRoute:
            return toDestination <= configuration.arrivalRadiusMeters
                ? .settling(since: sample.timestamp)
                : .enRoute

        case .settling(let since):
            // Moved back out: that was a light, or a pass-by, not an arrival.
            guard toDestination <= configuration.arrivalRadiusMeters else { return .enRoute }

            return sample.timestamp.timeIntervalSince(since) >= configuration.dwellSeconds
                ? .arrived(at: since)
                : .settling(since: since)

        case .arrived:
            return phase
        }
    }

    /// Whether a phase transition is one the app should act on.
    public func departureTime(from previous: TripPhase, to next: TripPhase, sample: LocationSample) -> Date? {
        if case .awaitingDeparture = previous, case .enRoute = next { return sample.timestamp }
        return nil
    }

    public func arrivalTime(from previous: TripPhase, to next: TripPhase) -> Date? {
        guard case .arrived(let at) = next else { return nil }
        if case .arrived = previous { return nil }
        // The arrival happened when the car first stopped, not when the dwell elapsed.
        return at
    }
}
