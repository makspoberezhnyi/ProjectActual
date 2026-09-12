import SwiftUI
import MapKit

/// The trip drawn as it happens: the route covered so far, styled the way a Strava
/// activity map reads, with the same time and distance the rest of the app already
/// shows for anything else — no pace, no split times, nothing this product doesn't
/// actually measure.
struct TripMapView: View {
    let session: Session
    let onDismiss: () -> Void

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasFramedRoute = false

    private var route: [RoutePoint] { session.route }

    var body: some View {
        ZStack(alignment: .top) {
            map
                .ignoresSafeArea()

            header

            VStack {
                Spacer()
                statCard
                    .padding(.horizontal, Theme.Padding.screen)
                    .padding(.bottom, 40)
            }
        }
        .onChange(of: route.count) { _, _ in frameRoute() }
        .task { frameRoute() }
    }

    private var map: some View {
        Map(position: $cameraPosition) {
            if let start = route.first {
                Annotation("Start", coordinate: start.coordinate.clLocation) {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 12, height: 12)
                        .overlay { Circle().strokeBorder(Theme.ink, lineWidth: 2) }
                }
            }

            if route.count >= 2 {
                MapPolyline(coordinates: route.map(\.coordinate.clLocation))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }

            if let current = route.last {
                Annotation("Now", coordinate: current.coordinate.clLocation) {
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.25)).frame(width: 26, height: 26)
                        Circle().fill(Theme.accent).frame(width: 12, height: 12)
                            .overlay { Circle().strokeBorder(Theme.bg, lineWidth: 2) }
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
        .colorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.bg.opacity(0.85), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close map")
            Spacer()
        }
        .padding(.horizontal, Theme.Padding.screen)
        .padding(.top, 8)
    }

    private var statCard: some View {
        HStack(spacing: 0) {
            stat(
                label: "time",
                value: DurationFormatting.clock(seconds: session.elapsedSeconds())
            )
            Divider().overlay(Theme.line).frame(height: 32)
            stat(
                label: "distance",
                value: DurationFormatting.distance(meters: session.routeDistanceMeters)
            )
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.panel))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.panel)
                .strokeBorder(Theme.line, lineWidth: 1)
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typeface.timer(22))
                .foregroundStyle(Theme.ink)
            Caption(label, size: 11.5)
        }
        .frame(maxWidth: .infinity)
    }

    /// Frames the camera around the route so far. Runs once the route has enough points
    /// to define a real region, and again as it grows, rather than fighting the person
    /// for control of the map on every single fix.
    private func frameRoute() {
        guard route.count >= 2 else { return }

        let coordinates = route.map(\.coordinate.clLocation)
        let rect = MKMapRect(coordinates: coordinates)
        cameraPosition = .rect(rect)
    }
}

extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension MKMapRect {
    /// The smallest rect containing every coordinate, padded so the route doesn't run
    /// edge to edge.
    init(coordinates: [CLLocationCoordinate2D]) {
        let points = coordinates.map(MKMapPoint.init)
        let xs = points.map(\.x)
        let ys = points.map(\.y)

        let rect = MKMapRect(
            x: xs.min() ?? 0, y: ys.min() ?? 0,
            width: (xs.max() ?? 0) - (xs.min() ?? 0),
            height: (ys.max() ?? 0) - (ys.min() ?? 0)
        )
        self = rect.insetBy(dx: -rect.width * 0.25 - 200, dy: -rect.height * 0.25 - 200)
    }
}

/// The finished route as a small, non-interactive map: the same line style as the live
/// map, sized to sit inline on the session end screen the way an activity summary does.
struct RouteSummaryView: View {
    let route: [RoutePoint]

    private var region: MKCoordinateRegion {
        let coordinates = route.map(\.coordinate.clLocation)
        let rect = MKMapRect(coordinates: coordinates)
        return MKCoordinateRegion(rect)
    }

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            MapPolyline(coordinates: route.map(\.coordinate.clLocation))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
        .colorScheme(.dark)
        .allowsHitTesting(false)
    }
}
