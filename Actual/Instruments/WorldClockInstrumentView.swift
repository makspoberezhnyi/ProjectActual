import SwiftUI
import CoreLocation

struct WorldClockInstrumentView: View {
    @Bindable private var store = TimeOSStore.shared
    @State private var showAdd = false
    @State private var isLocatingGPS = false

    init() {}

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.worldCities) { city in
                    WorldCityRow(city: city)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(Color.tempoInk.opacity(0.1))
                        .contextMenu {
                            Button("Sync 9 AM overlap timer", systemImage: "timer") {
                                store.startOverlapCountdown(for: city)
                            }
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                store.removeWorldCity(city.id)
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SharedBackground())
            .navigationTitle("World")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        addGPSCurrentCity()
                    } label: {
                        if isLocatingGPS {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "location.fill")
                        }
                    }
                    .tint(Color.tempoAccent)
                    .accessibilityLabel("Add current GPS city")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add city", systemImage: "plus") { showAdd = true }
                        .tint(Color.tempoAccent)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddWorldCitySheet(store: store)
                    .presentationDetents([.large])
            }
        }
    }

    private func addGPSCurrentCity() {
        isLocatingGPS = true
        LocationTravelManager.shared.requestAuthorization()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            let loc = LocationTravelManager.shared.effectiveLocation
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
               let first = placemarks.first {
                let city = first.locality ?? first.subAdministrativeArea ?? first.name ?? "My Location"
                let country = first.country ?? ""
                let tz = first.timeZone?.identifier ?? TimeZone.current.identifier
                if !store.worldCities.contains(where: { $0.cityName.lowercased() == city.lowercased() }) {
                    store.addWorldCity(name: city, tzIdentifier: tz, note: country)
                }
            } else {
                let tz = TimeZone.current.identifier
                let city = tz.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? "Local Time"
                if !store.worldCities.contains(where: { $0.cityName.lowercased() == city.lowercased() }) {
                    store.addWorldCity(name: city, tzIdentifier: tz, note: "Current Time Zone")
                }
            }
            isLocatingGPS = false
        }
    }
}

private struct WorldCityRow: View {
    let city: TempoWorldCity

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let comp = city.localComponents(at: now)
            let h = Double(comp.hour ?? 12)
            let m = Double(comp.minute ?? 0)
            let night = city.isMoodyNight(at: now)
            let dusk = city.isMoodyDusk(at: now)

            HStack(spacing: 14) {
                TempoWatchMascotView(
                    regime: night ? .worldRemoteNight : (dusk ? .worldDualGMT : .worldLocalDay),
                    size: 58,
                    animated: false,
                    overrideMinuteAngle: m * 6,
                    overrideHourAngle: (h.truncatingRemainder(dividingBy: 12)) * 30 + m * 0.5
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(city.cityName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.tempoInk)
                    HStack(spacing: 5) {
                        Image(systemName: night ? "moon.stars.fill" : (dusk ? "sunset.fill" : "sun.max.fill"))
                            .symbolRenderingMode(.hierarchical)
                        Text(city.hoursOffsetString(at: now))
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.tempoMuted)
                }
                Spacer(minLength: 8)
                Text(city.formattedLocalTime(at: now))
                    .font(.tempoNumerals(32))
                    .foregroundStyle(Color.tempoInk)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("World") {
    WorldClockInstrumentView()
}

#Preview("World · Dark") {
    WorldClockInstrumentView()
        .preferredColorScheme(.dark)
}
