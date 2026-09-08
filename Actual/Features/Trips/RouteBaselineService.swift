import Foundation
import MapKit
import CoreLocation

/// Fetches an objective travel time for a trip, so the person's own guess has something
/// besides their own history to be compared against.
///
/// This is infrastructure, not a feature the app is trying to own. Traffic and routing
/// are solved problems; what Actual adds is noticing that this particular person tends
/// to arrive eight minutes after the route says, which the routing service has no reason
/// to model.
@MainActor
@Observable
final class RouteBaselineService: NSObject {
    private let manager = CLLocationManager()
    private var pendingLocation: CheckedContinuation<CLLocation?, Never>?
    /// Where the person was when the trip started, which is what departure is judged
    /// against.
    private(set) var lastKnownCoordinate: Coordinate?
    private var pendingAuthorization: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// The route's own prediction in whole minutes, or nil.
    ///
    /// Nil is a supported answer everywhere downstream: offline, a refused location
    /// permission, a timeout, or no route at all all end here, and none of them may
    /// block a trip from starting or closing.
    func baselineMinutes(
        toLatitude latitude: Double,
        longitude: Double
    ) async -> Int? {
        guard let origin = await currentLocation() else { return nil }

        let request = MKDirections.Request()
        request.source = MKMapItem(
            placemark: MKPlacemark(coordinate: origin.coordinate)
        )
        request.destination = MKMapItem(
            placemark: MKPlacemark(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        )
        request.transportType = .automobile
        // Traffic conditions matter, so ask for the time as of departing now.
        request.departureDate = .now

        lastKnownCoordinate = Coordinate(
            latitude: origin.coordinate.latitude, longitude: origin.coordinate.longitude
        )

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
                return nil
            }
            return max(1, Int((route.expectedTravelTime / 60).rounded()))
        } catch {
            return nil
        }
    }

    // MARK: - Location

    private func currentLocation() async -> CLLocation? {
        // Asking for a fix before the person has answered the permission prompt simply
        // fails, so wait for the decision rather than racing it.
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                pendingAuthorization = continuation
                manager.requestWhenInUseAuthorization()
            }
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            break
        default:
            // Refused, restricted, or still undecided: no baseline, and nothing blocks.
            return nil
        }

        if let existing = manager.location { return existing }

        return await withCheckedContinuation { continuation in
            pendingLocation = continuation
            manager.requestLocation()

            // A fix that never arrives must not leave a trip hanging.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(8))
                guard let self, let pending = self.pendingLocation else { return }
                self.pendingLocation = nil
                pending.resume(returning: nil)
            }
        }
    }
}

extension RouteBaselineService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined else { return }
            self.pendingAuthorization?.resume()
            self.pendingAuthorization = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.pendingLocation?.resume(returning: location)
            self.pendingLocation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.pendingLocation?.resume(returning: nil)
            self.pendingLocation = nil
        }
    }
}
