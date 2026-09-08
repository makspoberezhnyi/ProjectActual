import Foundation
import CoreLocation
import os

/// Trip watching happens in the background, where nothing is visible on screen. When it
/// silently fails to start there is otherwise nothing to look at, so the decisions it
/// makes are logged.
let tripLog = Logger(subsystem: "app.actual.Actual", category: "trips")

/// Watches a trip while it happens, so it ends itself.
///
/// This is the most differentiated part of the product: for a trip, nobody should have
/// to remember to tap stop. The app can see the car leave and see it park, so it times
/// the real thing and writes the duration without asking.
///
/// Runs in the background. Two mechanisms, because one alone is not enough:
/// continuous updates while the app is backgrounded give the resolution needed to judge
/// a dwell, and a monitored region around the destination wakes the app even if iOS has
/// terminated it in the meantime.
@MainActor
@Observable
final class TripMonitor: NSObject {
    private let manager = CLLocationManager()
    private let detector: TripProgressDetector

    private(set) var phase: TripPhase = .awaitingDeparture
    private(set) var isMonitoring = false

    private var origin: Coordinate?
    private var destination: Coordinate?
    private var regionIdentifier: String?
    /// Confirms an arrival on the clock rather than on further readings.
    ///
    /// A parked car stops generating location updates — that is the point of the
    /// hardware being efficient — so waiting for another sample to prove the dwell
    /// elapsed would mean waiting forever. The samples decide whether we are settling;
    /// this decides when settling has lasted long enough.
    private var dwellTask: Task<Void, Never>?
    private var lastCoordinate: Coordinate?

    /// The path recorded so far, oldest first. What a live map draws as it grows.
    private(set) var route: [RoutePoint] = []
    /// Called whenever a new point is accepted, throttled so it is cheap to persist on
    /// every call rather than needing its own batching logic downstream.
    var onRouteUpdate: (([RoutePoint]) -> Void)?
    private var lastPersistedCount = 0

    /// Called when the person is judged to have actually left.
    var onDeparture: ((Date) -> Void)?
    /// Called once, when the car has been parked at the destination long enough to
    /// count as arrived.
    var onArrival: ((Date) -> Void)?

    init(detector: TripProgressDetector = TripProgressDetector()) {
        self.detector = detector
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // A trip that pauses itself stops noticing the arrival.
        manager.pausesLocationUpdatesAutomatically = false
        // Never silent: while this is running, the person can see it is running.
        manager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Lifecycle

    func begin(destination: Coordinate, origin: Coordinate?, sessionID: UUID) {
        stop()
        route = []
        lastPersistedCount = 0
        tripLog.notice("begin: destination \(destination.latitude), \(destination.longitude), origin \(origin == nil ? "unknown" : "known"), auth \(self.manager.authorizationStatus.rawValue)")

        self.destination = destination
        self.origin = origin
        phase = .awaitingDeparture
        isMonitoring = true

        // Background updates need Always; without it the trip still ends itself while
        // the app is open, which is a lesser version rather than a broken one.
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        } else if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        enableBackgroundUpdatesIfPermitted()
        manager.startUpdatingLocation()
        tripLog.notice("begin: started updating location")

        // A region around the destination wakes the app even if it has been terminated,
        // which continuous updates alone cannot promise.
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            let identifier = "trip-\(sessionID.uuidString)"
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: destination.latitude, longitude: destination.longitude
                ),
                radius: max(detector.configuration.arrivalRadiusMeters, 100),
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
            regionIdentifier = identifier
        }
    }

    func stop() {
        guard isMonitoring else { return }
        dwellTask?.cancel()
        dwellTask = nil
        manager.stopUpdatingLocation()
        if let regionIdentifier {
            manager.monitoredRegions
                .filter { $0.identifier == regionIdentifier }
                .forEach(manager.stopMonitoring(for:))
        }
        regionIdentifier = nil
        destination = nil
        origin = nil
        isMonitoring = false
        phase = .awaitingDeparture
        route = []
        lastPersistedCount = 0
    }

    private func enableBackgroundUpdatesIfPermitted() {
        // Setting this without the background mode declared throws, so it is guarded on
        // the authorisation that makes it legal.
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = true
    }

    // MARK: - Readings

    fileprivate func consume(_ locations: [CLLocation]) {
        guard isMonitoring, let destination else {
            tripLog.debug("consume: ignored, monitoring \(self.isMonitoring)")
            return
        }

        for location in locations {
            let coordinate = Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )

            // Without somewhere to have left from, departure can never be detected. The
            // first trustworthy fix after starting is that place — unless it is already
            // the destination, in which case there is no journey to watch.
            if origin == nil,
               case .awaitingDeparture = phase,
               location.horizontalAccuracy <= detector.configuration.accuracyCeilingMeters,
               coordinate.distance(to: destination) > detector.configuration.arrivalRadiusMeters {
                origin = coordinate
            }

            let sample = LocationSample(
                coordinate: coordinate,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy
            )

            let next = detector.advance(phase, with: sample, origin: origin, destination: destination)
            lastCoordinate = coordinate
            route.append(RoutePoint(coordinate: coordinate, timestamp: sample.timestamp))

            // Persisting on every single fix would be a write per second while driving.
            // Every fifth point is frequent enough for a live map to look continuous
            // without turning the drive into a write storm.
            if route.count - lastPersistedCount >= 5 {
                lastPersistedCount = route.count
                onRouteUpdate?(route)
            }

            if let departed = detector.departureTime(from: phase, to: next, sample: sample) {
                onDeparture?(departed)
            }
            if let arrived = detector.arrivalTime(from: phase, to: next) {
                phase = next
                finishArrival(at: arrived)
                return
            }

            // Entering or leaving the destination radius starts or cancels the countdown.
            switch (phase, next) {
            case (.settling, .settling):
                break
            case (_, .settling(let since)):
                scheduleDwellConfirmation(since: since)
            case (.settling, _):
                dwellTask?.cancel()
                dwellTask = nil
            default:
                break
            }

            if phase != next {
                tripLog.notice("phase: \(String(describing: self.phase)) -> \(String(describing: next)), \(Int(coordinate.distance(to: destination)))m from destination")
            }
            phase = next
        }
    }

    /// Waits out the dwell and confirms, unless the car moved off in the meantime.
    private func scheduleDwellConfirmation(since: Date) {
        dwellTask?.cancel()
        let remaining = detector.configuration.dwellSeconds - Date.now.timeIntervalSince(since)

        dwellTask = Task { [weak self] in
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled, let self else { return }
            await MainActor.run {
                // Still inside the radius after the wait: that was parking, not a light.
                guard case .settling(let start) = self.phase, self.isMonitoring else { return }
                guard let destination = self.destination, let last = self.lastCoordinate,
                      last.distance(to: destination) <= self.detector.configuration.arrivalRadiusMeters
                else { return }

                self.phase = .arrived(at: start)
                self.finishArrival(at: start)
            }
        }
    }

    private func finishArrival(at moment: Date) {
        tripLog.notice("arrived at \(moment)")
        onRouteUpdate?(route)
        let callback = onArrival
        stop()
        callback?(moment)
    }
}

extension TripMonitor: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.consume(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A dropped fix is normal in a tunnel. Keep listening rather than ending a trip
        // on the strength of a failure.
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.isMonitoring else { return }
            self.enableBackgroundUpdatesIfPermitted()
        }
    }

    /// The app can be woken here from terminated, which is the point of the region.
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard self.isMonitoring else { return }
            // Entering only opens the dwell; the arrival still has to be earned by
            // staying put, so ask for precise updates rather than closing here.
            manager.startUpdatingLocation()
        }
    }
}
