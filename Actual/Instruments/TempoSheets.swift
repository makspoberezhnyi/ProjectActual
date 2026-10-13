import SwiftUI
import CoreLocation
import MapKit

struct AddTempoAlarmSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: TimeOSStore
    /// When set, the sheet edits this alarm instead of creating a new one.
    var editing: TempoAlarm? = nil

    @State private var wakeDate: Date
    @State private var label: String
    @State private var weekdays: Set<Int>
    @State private var isBedtime: Bool
    @State private var chainRoutine: Bool
    @State private var chainedTitle: String
    @State private var chainedMinutes: Int

    init(store: TimeOSStore, editing: TempoAlarm? = nil) {
        _store = Bindable(wrappedValue: store)
        self.editing = editing
        let hour = editing?.hour ?? 7
        let minute = editing?.minute ?? 30
        _wakeDate = State(initialValue: Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date())
        _label = State(initialValue: editing?.label ?? "Wake up")
        _weekdays = State(initialValue: Set(editing?.activeWeekdays ?? Array(1...7)))
        _isBedtime = State(initialValue: editing?.isBedtimeWindDown ?? false)
        _chainRoutine = State(initialValue: editing.map { $0.chainedTaskTitle != nil } ?? true)
        _chainedTitle = State(initialValue: editing?.chainedTaskTitle ?? "Morning routine")
        _chainedMinutes = State(initialValue: editing?.chainedTaskMinutes ?? 20)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $wakeDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section("Repeat") {
                    weekdayPicker
                        .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                }

                Section {
                    TextField("Label", text: $label)
                    Toggle("Bedtime mode", isOn: $isBedtime)
                        .tint(Color.tempoAccent)
                }

                Section {
                    Toggle("Start a timer when I wake up", isOn: $chainRoutine)
                        .tint(Color.tempoAccent)
                    if chainRoutine {
                        TextField("Routine", text: $chainedTitle)
                        Stepper("\(chainedMinutes) min", value: $chainedMinutes, in: 5...90, step: 5)
                    }
                } footer: {
                    Text("Tap Start on the ringing screen and Tempo times your routine for you.")
                }

                if let editing {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            store.deleteAlarm(editing.id)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                    }
                    .tint(Color.tempoAccent)
                    .disabled(weekdays.isEmpty)
                    .accessibilityLabel("Save")
                }
            }
        }
    }

    /// Seven round day toggles, ordered by the user's first weekday.
    private var weekdayPicker: some View {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let order = (0..<7).map { (cal.firstWeekday - 1 + $0) % 7 + 1 }
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = weekdays.contains(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                    TactileFeedback.selection()
                } label: {
                    Text(symbols[day - 1])
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? Color.white : Color.tempoInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Circle().fill(on ? Color.tempoAccent : Color.tempoInk.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cal.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func save() {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: wakeDate)
        let days = weekdays.count == 7 ? nil : weekdays.sorted()
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if var alarm = editing {
            alarm.hour = comp.hour ?? alarm.hour
            alarm.minute = comp.minute ?? alarm.minute
            alarm.label = cleanLabel.isEmpty ? "Alarm" : cleanLabel
            alarm.repeatWeekdays = days
            alarm.isBedtimeWindDown = isBedtime
            alarm.chainedTaskTitle = chainRoutine && !chainedTitle.isEmpty ? chainedTitle : nil
            alarm.chainedTaskMinutes = chainRoutine ? chainedMinutes : nil
            store.updateAlarm(alarm)
        } else {
            store.addAlarm(
                hour: comp.hour ?? 7,
                minute: comp.minute ?? 30,
                label: cleanLabel,
                isBedtime: isBedtime,
                chainedTitle: chainRoutine ? chainedTitle : nil,
                chainedMinutes: chainRoutine ? chainedMinutes : nil,
                repeatWeekdays: days
            )
        }
        // First alarm is the natural moment to ask for alarm permission.
        Task {
            await TempoAlarmScheduler.shared.requestPermissions()
            TempoAlarmScheduler.shared.sync(store.alarms)
        }
    }
}

struct AddWorldCitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: TimeOSStore
    @Bindable private var locationManager = LocationTravelManager.shared

    @State private var searchText: String = ""
    @State private var geocodedResults: [(cityName: String, subtitle: String, tzIdentifier: String)] = []
    @State private var isSearchingMapKit: Bool = false
    @State private var isLocatingGPS: Bool = false
    @State private var gpsStatusMessage: String? = nil

    private struct CityEntry: Identifiable {
        var id: String { "\(name)-\(tz)" }
        let name: String
        let region: String
        let tz: String
    }

    private static let allKnownCities: [CityEntry] = {
        var list: [CityEntry] = [
            CityEntry(name: "Warsaw", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Łódź", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Kraków", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Wrocław", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Gdańsk", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Poznań", region: "Poland", tz: "Europe/Warsaw"),
            CityEntry(name: "Kyiv", region: "Ukraine", tz: "Europe/Kyiv"),
            CityEntry(name: "Lviv", region: "Ukraine", tz: "Europe/Kyiv"),
            CityEntry(name: "Berlin", region: "Germany", tz: "Europe/Berlin"),
            CityEntry(name: "Munich", region: "Germany", tz: "Europe/Berlin"),
            CityEntry(name: "Frankfurt", region: "Germany", tz: "Europe/Berlin"),
            CityEntry(name: "London", region: "United Kingdom", tz: "Europe/London"),
            CityEntry(name: "Paris", region: "France", tz: "Europe/Paris"),
            CityEntry(name: "Amsterdam", region: "Netherlands", tz: "Europe/Amsterdam"),
            CityEntry(name: "Zurich", region: "Switzerland", tz: "Europe/Zurich"),
            CityEntry(name: "Madrid", region: "Spain", tz: "Europe/Madrid"),
            CityEntry(name: "Barcelona", region: "Spain", tz: "Europe/Madrid"),
            CityEntry(name: "Rome", region: "Italy", tz: "Europe/Rome"),
            CityEntry(name: "Milan", region: "Italy", tz: "Europe/Rome"),
            CityEntry(name: "Vienna", region: "Austria", tz: "Europe/Vienna"),
            CityEntry(name: "Prague", region: "Czechia", tz: "Europe/Prague"),
            CityEntry(name: "Stockholm", region: "Sweden", tz: "Europe/Stockholm"),
            CityEntry(name: "Oslo", region: "Norway", tz: "Europe/Oslo"),
            CityEntry(name: "Copenhagen", region: "Denmark", tz: "Europe/Copenhagen"),
            CityEntry(name: "Helsinki", region: "Finland", tz: "Europe/Helsinki"),
            CityEntry(name: "Lisbon", region: "Portugal", tz: "Europe/Lisbon"),
            CityEntry(name: "Dublin", region: "Ireland", tz: "Europe/Dublin"),
            CityEntry(name: "Athens", region: "Greece", tz: "Europe/Athens"),
            CityEntry(name: "Istanbul", region: "Türkiye", tz: "Europe/Istanbul"),
            CityEntry(name: "New York", region: "United States", tz: "America/New_York"),
            CityEntry(name: "San Francisco", region: "United States", tz: "America/Los_Angeles"),
            CityEntry(name: "Los Angeles", region: "United States", tz: "America/Los_Angeles"),
            CityEntry(name: "Seattle", region: "United States", tz: "America/Los_Angeles"),
            CityEntry(name: "Chicago", region: "United States", tz: "America/Chicago"),
            CityEntry(name: "Austin", region: "United States", tz: "America/Chicago"),
            CityEntry(name: "Miami", region: "United States", tz: "America/New_York"),
            CityEntry(name: "Boston", region: "United States", tz: "America/New_York"),
            CityEntry(name: "Toronto", region: "Canada", tz: "America/Toronto"),
            CityEntry(name: "Vancouver", region: "Canada", tz: "America/Vancouver"),
            CityEntry(name: "Mexico City", region: "Mexico", tz: "America/Mexico_City"),
            CityEntry(name: "São Paulo", region: "Brazil", tz: "America/Sao_Paulo"),
            CityEntry(name: "Buenos Aires", region: "Argentina", tz: "America/Argentina/Buenos_Aires"),
            CityEntry(name: "Tokyo", region: "Japan", tz: "Asia/Tokyo"),
            CityEntry(name: "Seoul", region: "South Korea", tz: "Asia/Seoul"),
            CityEntry(name: "Singapore", region: "Singapore", tz: "Asia/Singapore"),
            CityEntry(name: "Hong Kong", region: "China", tz: "Asia/Hong_Kong"),
            CityEntry(name: "Shanghai", region: "China", tz: "Asia/Shanghai"),
            CityEntry(name: "Taipei", region: "Taiwan", tz: "Asia/Taipei"),
            CityEntry(name: "Bangkok", region: "Thailand", tz: "Asia/Bangkok"),
            CityEntry(name: "Dubai", region: "UAE", tz: "Asia/Dubai"),
            CityEntry(name: "Tel Aviv", region: "Israel", tz: "Asia/Jerusalem"),
            CityEntry(name: "Bengaluru", region: "India", tz: "Asia/Kolkata"),
            CityEntry(name: "Mumbai", region: "India", tz: "Asia/Kolkata"),
            CityEntry(name: "Sydney", region: "Australia", tz: "Australia/Sydney"),
            CityEntry(name: "Melbourne", region: "Australia", tz: "Australia/Melbourne"),
            CityEntry(name: "Auckland", region: "New Zealand", tz: "Pacific/Auckland")
        ]

        // Also include all system IANA timezone cities not already listed
        var seen = Set(list.map { $0.name.lowercased() })
        for id in TimeZone.knownTimeZoneIdentifiers {
            let parts = id.split(separator: "/")
            guard parts.count >= 2 else { continue }
            let rawCity = String(parts.last!).replacingOccurrences(of: "_", with: " ")
            let region = String(parts.first!).replacingOccurrences(of: "_", with: " ")
            guard !seen.contains(rawCity.lowercased()) else { continue }
            seen.insert(rawCity.lowercased())
            list.append(CityEntry(name: rawCity, region: region, tz: id))
        }
        return list
    }()

    private var filteredCatalog: [CityEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return Array(Self.allKnownCities.prefix(35))
        }
        return Self.allKnownCities.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.region.localizedCaseInsensitiveContains(q) ||
            $0.tz.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // 1. Live GPS Current Location Section
                Section {
                    Button {
                        addCurrentGPSLocation()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isLocatingGPS ? "location.fill.viewfinder" : "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.tempoAccent)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.tempoAccent.opacity(0.14)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Use Current GPS Location")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(Color.tempoInk)
                                Text(gpsStatusMessage ?? "Detect your city & local time zone automatically")
                                    .font(.caption)
                                    .foregroundStyle(Color.tempoMuted)
                            }

                            Spacer()

                            if isLocatingGPS {
                                ProgressView()
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.tempoAccent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 2. Live MapKit / Geocoder Search Results (any city on Earth)
                if !geocodedResults.isEmpty {
                    Section("Worldwide Search") {
                        ForEach(geocodedResults, id: \.cityName) { item in
                            Button {
                                store.addWorldCity(name: item.cityName, tzIdentifier: item.tzIdentifier, note: item.subtitle)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.cityName)
                                            .font(.system(.body, design: .rounded, weight: .semibold))
                                            .foregroundStyle(Color.tempoInk)
                                        Text("\(item.subtitle) · \(offsetPreview(for: item.tzIdentifier))")
                                            .font(.caption)
                                            .foregroundStyle(Color.tempoMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.tempoAccent)
                                }
                            }
                        }
                    }
                }

                // 3. Curated + IANA TimeZone Catalog
                Section(searchText.isEmpty ? "Popular & World Cities" : "Matching Cities") {
                    ForEach(filteredCatalog.prefix(60)) { item in
                        Button {
                            store.addWorldCity(name: item.name, tzIdentifier: item.tz, note: item.region)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .foregroundStyle(Color.tempoInk)
                                    Text("\(item.region) · \(offsetPreview(for: item.tz))")
                                        .font(.caption)
                                        .foregroundStyle(Color.tempoMuted)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.tempoAccent)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search any city or country…")
            .onChange(of: searchText) { _, newValue in
                performLiveGeocoderSearch(query: newValue)
            }
            .onAppear {
                locationManager.requestAuthorization()
            }
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private func offsetPreview(for tzID: String) -> String {
        guard let tz = TimeZone(identifier: tzID) else { return tzID }
        let now = Date()
        let diff = (tz.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)) / 3600
        let diffStr = diff == 0 ? "Same time" : (diff > 0 ? "+\(diff)h" : "\(diff)h")
        var cal = Calendar.current
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: now)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        let h12 = h % 12 == 0 ? 12 : h % 12
        let ampm = h < 12 ? "AM" : "PM"
        return String(format: "%@ · %02d:%02d %@", diffStr, h12, m, ampm)
    }

    private func addCurrentGPSLocation() {
        isLocatingGPS = true
        gpsStatusMessage = "Locating via GPS…"
        locationManager.requestAuthorization()

        Task { @MainActor in
            // Give CoreLocation a brief moment if it just started updating
            try? await Task.sleep(for: .milliseconds(350))
            let loc = locationManager.effectiveLocation
            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
               let first = placemarks.first {
                let city = first.locality ?? first.subAdministrativeArea ?? first.name ?? "My Location"
                let country = first.country ?? ""
                let tz = first.timeZone?.identifier ?? TimeZone.current.identifier
                isLocatingGPS = false
                store.addWorldCity(name: city, tzIdentifier: tz, note: country)
                dismiss()
            } else {
                // Fallback to current system timezone city name
                let tz = TimeZone.current.identifier
                let city = tz.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? "Local Time"
                isLocatingGPS = false
                store.addWorldCity(name: city, tzIdentifier: tz, note: "Current Time Zone")
                dismiss()
            }
        }
    }

    private func performLiveGeocoderSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            geocodedResults = []
            return
        }

        isSearchingMapKit = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }

            let geocoder = CLGeocoder()
            if let placemarks = try? await geocoder.geocodeAddressString(trimmed) {
                var results: [(String, String, String)] = []
                for p in placemarks {
                    let name = p.locality ?? p.name ?? trimmed
                    let country = p.country ?? p.administrativeArea ?? ""
                    let tz = p.timeZone?.identifier ?? TimeZone.current.identifier
                    if !results.contains(where: { $0.0.lowercased() == name.lowercased() }) {
                        results.append((name, country, tz))
                    }
                }
                self.geocodedResults = results
            }
            self.isSearchingMapKit = false
        }
    }
}
