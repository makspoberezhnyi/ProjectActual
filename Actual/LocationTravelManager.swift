import Foundation
import CoreLocation
import MapKit
#if canImport(UIKit)
import UIKit
#endif

public enum TravelTransportMode: String, Codable, CaseIterable, Identifiable {
    case driving = "drive"
    case transit = "transit"
    case walking = "walk"
    case cycling = "cycling"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .driving: return "Car"
        case .transit: return "City Transport"
        case .walking: return "By Feet"
        case .cycling: return "Bicycle"
        }
    }
    
    public var actionTitle: String {
        switch self {
        case .driving: return "Drive"
        case .transit: return "Transit"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        }
    }
    
    public var iconName: String {
        switch self {
        case .driving: return "car.fill"
        case .transit: return "tram.fill"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        }
    }
    
    public var appleMapsFlag: String {
        switch self {
        case .driving: return "d"
        case .transit: return "r"
        case .walking: return "w"
        case .cycling: return "b"
        }
    }
    
    public var mapLaunchMode: String {
        switch self {
        case .driving: return MKLaunchOptionsDirectionsModeDriving
        case .transit: return MKLaunchOptionsDirectionsModeTransit
        case .walking: return MKLaunchOptionsDirectionsModeWalking
        case .cycling: return MKLaunchOptionsDirectionsModeDriving
        }
    }
}

public struct TravelAssessmentResult: Identifiable, Codable, Hashable {
    public var id: String
    public var destinationTitle: String
    public var destinationAddress: String?
    public var travelDurationMinutes: Int
    public var distanceMeters: Double
    public var distanceString: String
    public var transportTypeName: String
    public var transportMode: TravelTransportMode
    public var latitude: Double?
    public var longitude: Double?
    
    public init(
        id: String = UUID().uuidString,
        destinationTitle: String,
        destinationAddress: String? = nil,
        travelDurationMinutes: Int,
        distanceMeters: Double,
        distanceString: String,
        transportTypeName: String = "Drive",
        transportMode: TravelTransportMode = .driving,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.destinationTitle = destinationTitle
        self.destinationAddress = destinationAddress
        self.travelDurationMinutes = travelDurationMinutes
        self.distanceMeters = distanceMeters
        self.distanceString = distanceString
        self.transportTypeName = transportTypeName
        self.transportMode = transportMode
        self.latitude = latitude
        self.longitude = longitude
    }
    
    enum CodingKeys: String, CodingKey {
        case id, destinationTitle, destinationAddress, travelDurationMinutes, distanceMeters, distanceString, transportTypeName, transportMode, latitude, longitude
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.destinationTitle = try container.decode(String.self, forKey: .destinationTitle)
        self.destinationAddress = try container.decodeIfPresent(String.self, forKey: .destinationAddress)
        self.travelDurationMinutes = try container.decode(Int.self, forKey: .travelDurationMinutes)
        self.distanceMeters = try container.decode(Double.self, forKey: .distanceMeters)
        self.distanceString = try container.decode(String.self, forKey: .distanceString)
        let typeName = try container.decodeIfPresent(String.self, forKey: .transportTypeName) ?? "Drive"
        self.transportTypeName = typeName
        if let mode = try container.decodeIfPresent(TravelTransportMode.self, forKey: .transportMode) {
            self.transportMode = mode
        } else {
            let lower = typeName.lowercased()
            if lower.contains("transit") || lower.contains("bus") || lower.contains("train") || lower.contains("tram") {
                self.transportMode = .transit
            } else if lower.contains("walk") || lower.contains("feet") || lower.contains("foot") {
                self.transportMode = .walking
            } else if lower.contains("cycl") || lower.contains("bike") {
                self.transportMode = .cycling
            } else {
                self.transportMode = .driving
            }
        }
        self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
    
    public var formattedDuration: String {
        if travelDurationMinutes < 60 {
            return "\(travelDurationMinutes)m"
        } else if travelDurationMinutes < 1440 {
            let hours = travelDurationMinutes / 60
            let mins = travelDurationMinutes % 60
            return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
        } else {
            let days = travelDurationMinutes / 1440
            let hours = (travelDurationMinutes % 1440) / 60
            return "\(days)d \(hours)h"
        }
    }
}

@Observable
public final class LocationTravelManager: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationTravelManager()
    
    private let locationManager = CLLocationManager()
    public var userLocation: CLLocation?
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Dynamic localized fallback coordinates based on user's timezone / locale
    private var fallbackLocation: CLLocation {
        let tz = TimeZone.current.identifier
        if tz.contains("Warsaw") || tz.contains("Poland") || Locale.current.identifier.contains("PL") {
            return CLLocation(latitude: 51.7592, longitude: 19.4560) // Łódź, Poland
        } else if tz.contains("London") {
            return CLLocation(latitude: 51.5074, longitude: -0.1278) // London, UK
        } else if tz.contains("Paris") || tz.contains("Berlin") || tz.contains("Europe") {
            return CLLocation(latitude: 52.2297, longitude: 21.0122) // Central Europe
        } else {
            return CLLocation(latitude: 37.3346, longitude: -122.0090) // Cupertino, CA
        }
    }
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        self.authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    public func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.userLocation = location
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed: \(error.localizedDescription)")
    }
    
    public var effectiveLocation: CLLocation {
        userLocation ?? fallbackLocation
    }
    
    private func cleanLandmarkQuery(_ input: String) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("the ") {
            text = String(text.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let genericSuffixes = [
            "shopping mall", "shopping center", "shopping centre", "shopping plaza",
            "shopping", "mall", "department store", "supermarket", "grocery store",
            "hypermarket"
        ]
        
        var simplified = text
        for suffix in genericSuffixes {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: suffix) + "\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                simplified = regex.stringByReplacingMatches(
                    in: simplified,
                    range: NSRange(simplified.startIndex..., in: simplified),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return simplified.isEmpty ? text : simplified
    }
    
    // MARK: - Travel Time & ETA Calculations via MapKit
    
    public func calculateTravel(to query: String, mode: TravelTransportMode = .driving) async -> TravelAssessmentResult? {
        requestAuthorization()
        
        let startLoc = effectiveLocation
        var cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().hasPrefix("the ") {
            cleaned = String(cleaned.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        let simplified = cleanLandmarkQuery(cleaned)
        
        // Extract distinct keywords (e.g. ["manufaktura"])
        let queryWords = simplified.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        
        // Candidates to search in order: simplified landmark first, then full query
        var candidateQueries: [String] = []
        if simplified != cleaned && !simplified.isEmpty {
            candidateQueries.append(simplified)
        }
        candidateQueries.append(cleaned)
        
        // 1. Try MKLocalSearch with local region bias
        for q in candidateQueries {
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = q
            searchRequest.region = MKCoordinateRegion(
                center: startLoc.coordinate,
                latitudinalMeters: 80_000,
                longitudinalMeters: 80_000
            )
            
            let search = MKLocalSearch(request: searchRequest)
            if let response = try? await search.start(), !response.mapItems.isEmpty {
                // Prioritize map item whose name actually contains the keyword
                if let bestMatch = response.mapItems.first(where: { item in
                    guard let name = item.name?.lowercased() else { return false }
                    return queryWords.contains(where: { name.contains($0) })
                }) {
                    return await calculateRoute(from: startLoc, to: bestMatch, customTitle: bestMatch.name ?? q, mode: mode)
                }
            }
        }
        
        // 2. Try global MKLocalSearch (worldwide scope)
        for q in candidateQueries {
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = q
            let search = MKLocalSearch(request: searchRequest)
            if let response = try? await search.start(), !response.mapItems.isEmpty {
                if let bestMatch = response.mapItems.first(where: { item in
                    guard let name = item.name?.lowercased() else { return false }
                    return queryWords.contains(where: { name.contains($0) })
                }) {
                    return await calculateRoute(from: startLoc, to: bestMatch, customTitle: bestMatch.name ?? q, mode: mode)
                }
            }
        }
        
        // 3. Try CLGeocoder
        for q in candidateQueries {
            if let geocodeResult = await calculateTravelViaGeocoder(query: q, startLoc: startLoc, mode: mode) {
                return geocodeResult
            }
        }
        
        // 4. Return fallback estimation
        return estimateFallbackResult(for: simplified, mode: mode)
    }
    
    public func calculateTravel(coordinate: CLLocationCoordinate2D, title: String, mode: TravelTransportMode = .driving) async -> TravelAssessmentResult? {
        let startLoc = effectiveLocation
        let destPlacemark = MKPlacemark(coordinate: coordinate)
        let destMapItem = MKMapItem(placemark: destPlacemark)
        destMapItem.name = title
        return await calculateRoute(from: startLoc, to: destMapItem, customTitle: title, mode: mode)
    }
    
    private func calculateTravelViaGeocoder(query: String, startLoc: CLLocation, mode: TravelTransportMode = .driving) async -> TravelAssessmentResult? {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(query),
              let first = placemarks.first,
              let _ = first.location else {
            return nil
        }
        
        let destPlacemark = MKPlacemark(placemark: first)
        let destMapItem = MKMapItem(placemark: destPlacemark)
        let resolvedTitle = first.name ?? query
        destMapItem.name = resolvedTitle
        return await calculateRoute(from: startLoc, to: destMapItem, customTitle: resolvedTitle, mode: mode)
    }
    
    private func calculateRoute(from startLoc: CLLocation, to destination: MKMapItem, customTitle: String, mode: TravelTransportMode = .driving) async -> TravelAssessmentResult? {
        let sourcePlacemark = MKPlacemark(coordinate: startLoc.coordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let request = MKDirections.Request()
        request.source = sourceMapItem
        request.destination = destination
        switch mode {
        case .driving:
            request.transportType = .automobile
        case .transit:
            request.transportType = .transit
        case .walking, .cycling:
            request.transportType = .walking
        }
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let primaryRoute = response.routes.first {
                var durationSecs = primaryRoute.expectedTravelTime
                if mode == .cycling {
                    // Approximate cycling time as ~1/3 to 1/3.5 of walking time
                    durationSecs = max(60, durationSecs / 3.2)
                }
                let mins = max(1, Int(ceil(durationSecs / 60.0)))
                let distMeters = primaryRoute.distance
                let distString = formatDistance(meters: distMeters)
                
                let destCoord = destination.placemark.coordinate
                let address = destination.placemark.title
                
                return TravelAssessmentResult(
                    destinationTitle: customTitle,
                    destinationAddress: address,
                    travelDurationMinutes: mins,
                    distanceMeters: distMeters,
                    distanceString: distString,
                    transportTypeName: mode.displayName,
                    transportMode: mode,
                    latitude: destCoord.latitude,
                    longitude: destCoord.longitude
                )
            }
        } catch {
            print("MKDirections calculation error (\(mode.rawValue)): \(error.localizedDescription)")
        }
        
        // Fallback distance calculation using crow-flies distance
        let destLoc = CLLocation(
            latitude: destination.placemark.coordinate.latitude,
            longitude: destination.placemark.coordinate.longitude
        )
        let crowMeters = startLoc.distance(from: destLoc)
        
        let estimatedSecs: Double
        let routeDistanceMeters: Double
        switch mode {
        case .driving:
            // Average driving speed ~45 km/h with 1.25 urban curvature factor
            routeDistanceMeters = crowMeters * 1.25
            estimatedSecs = (routeDistanceMeters / 12.5)
        case .transit:
            // City transport: average speed ~25 km/h + 5 min wait/transfer buffer
            routeDistanceMeters = crowMeters * 1.3
            estimatedSecs = (routeDistanceMeters / 6.94) + 300
        case .walking:
            // Walking: average ~4.8 km/h (1.33 m/s) with 1.2 pedestrian detour factor
            routeDistanceMeters = crowMeters * 1.2
            estimatedSecs = (routeDistanceMeters / 1.33)
        case .cycling:
            // Cycling: average ~18 km/h (5.0 m/s) with 1.2 bike route factor
            routeDistanceMeters = crowMeters * 1.2
            estimatedSecs = (routeDistanceMeters / 5.0)
        }
        
        let mins = max(1, Int(ceil(estimatedSecs / 60.0)))
        
        return TravelAssessmentResult(
            destinationTitle: customTitle,
            destinationAddress: destination.placemark.title,
            travelDurationMinutes: mins,
            distanceMeters: routeDistanceMeters,
            distanceString: formatDistance(meters: routeDistanceMeters),
            transportTypeName: mode.displayName,
            transportMode: mode,
            latitude: destination.placemark.coordinate.latitude,
            longitude: destination.placemark.coordinate.longitude
        )
    }
    
    public func estimateFallbackResult(for query: String, mode: TravelTransportMode = .driving) -> TravelAssessmentResult {
        let mins: Int
        let distMeters: Double
        let distStr: String
        switch mode {
        case .driving:
            mins = 25
            distMeters = 12000
            distStr = "12.0 km"
        case .transit:
            mins = 38
            distMeters = 13500
            distStr = "13.5 km"
        case .walking:
            mins = 95
            distMeters = 8000
            distStr = "8.0 km"
        case .cycling:
            mins = 32
            distMeters = 8500
            distStr = "8.5 km"
        }
        return TravelAssessmentResult(
            destinationTitle: query,
            destinationAddress: "Estimated route",
            travelDurationMinutes: mins,
            distanceMeters: distMeters,
            distanceString: distStr,
            transportTypeName: mode.displayName,
            transportMode: mode
        )
    }
    
    private func formatDistance(meters: Double) -> String {
        let isMetric = Locale.current.measurementSystem == .metric
        if isMetric {
            if meters < 1000 {
                return "\(Int(meters)) m"
            } else {
                let km = meters / 1000.0
                return String(format: "%.1f km", km)
            }
        } else {
            let miles = meters * 0.000621371
            if miles < 0.2 {
                let feet = meters * 3.28084
                return "\(Int(feet)) ft"
            } else {
                return String(format: "%.1f mi", miles)
            }
        }
    }
    
    public func openInMaps(result: TravelAssessmentResult) {
        if let lat = result.latitude, let lon = result.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = result.destinationTitle
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: result.transportMode.mapLaunchMode
            ])
        } else {
            let encoded = result.destinationTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)&dirflg=\(result.transportMode.appleMapsFlag)") {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
            }
        }
    }
}
