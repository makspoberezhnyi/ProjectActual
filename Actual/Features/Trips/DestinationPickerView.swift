import SwiftUI
import MapKit

/// Searching for where a trip goes.
///
/// Setting a destination is what turns a category into a trip, which is the only thing
/// that makes an objective baseline possible.
struct DestinationPickerView: View {
    let onPick: (_ name: String, _ latitude: Double, _ longitude: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.primaryText)
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    Spacer()
                    Caption("Where to")
                    Spacer()
                    Color.clear.frame(width: 22, height: 22)
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 22)

                VStack(spacing: 16) {
                    TextField(
                        "",
                        text: $query,
                        prompt: Text("Search for a place").foregroundStyle(Theme.tertiaryText)
                    )
                    .font(Typeface.title(20))
                    .foregroundStyle(Theme.primaryText)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, newValue in scheduleSearch(newValue) }

                    Hairline()
                }
                .padding(.horizontal, Theme.Spacing.screen)
                .padding(.top, 22)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(results, id: \.self) { item in
                            Button {
                                pick(item)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "mappin.circle")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Theme.secondaryText)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unnamed place")
                                            .font(Typeface.medium(14))
                                            .foregroundStyle(Theme.primaryText)
                                        if let subtitle = address(for: item) {
                                            Caption(subtitle, size: 12)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, Theme.Spacing.row)
                                .padding(.vertical, 14)
                                .background(Theme.card, in: .rect(cornerRadius: Theme.Radius.row))
                                .overlay {
                                    RoundedRectangle(cornerRadius: Theme.Radius.row)
                                        .strokeBorder(Theme.border, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if results.isEmpty, !query.isEmpty, !isSearching {
                            Caption("Nothing found for that.")
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screen)
                    .padding(.top, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func address(for item: MKMapItem) -> String? {
        let placemark = item.placemark
        return [placemark.thoroughfare, placemark.locality]
            .compactMap { $0 }
            .joined(separator: ", ")
            .nilIfEmpty
    }

    /// Debounced, so typing does not fire a search per keystroke.
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        guard text.count >= 3 else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search(text)
        }
    }

    private func search(_ text: String) async {
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text

        guard let response = try? await MKLocalSearch(request: request).start() else {
            results = []
            return
        }
        results = Array(response.mapItems.prefix(8))
    }

    private func pick(_ item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        onPick(item.name ?? "Destination", coordinate.latitude, coordinate.longitude)
        dismiss()
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
