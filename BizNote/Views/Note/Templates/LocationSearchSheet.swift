import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = LocationSearchCompleter()
    @AppStorage("locationSearch.recent") private var recentLocationsData: String = "[]"
    @State private var query: String = ""
    @State private var isResolving: Bool = false
    @State private var isLocating: Bool = false
    @State private var locationError: String?
    @State private var onlineMeetingLink: String = ""
    @State private var locationService = LocationService()
    @State private var selectedItem: MKMapItem?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
            span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
        )
    )

    var body: some View {
        Group {
            if let selectedItem {
                confirmationView(for: selectedItem)
            } else {
                searchListView
            }
        }
        .navigationTitle(String(localized: "template.meeting.searchLocation"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "action.cancel")) {
                    if selectedItem != nil {
                        selectedItem = nil
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchListView: some View {
        List {
            Section {
                TextField(String(localized: "template.meeting.searchLocationPlaceholder"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                Button {
                    useCurrentLocation()
                } label: {
                    Label(String(localized: "template.meeting.useCurrentLocation"), systemImage: "location.fill")
                }
                .disabled(isLocating)

                HStack {
                    TextField(
                        String(localized: "template.meeting.onlineMeetingLink", defaultValue: "Online Meeting Link"),
                        text: $onlineMeetingLink
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Button {
                        select(onlineMeetingLink)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(onlineMeetingLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let locationError {
                    Text(locationError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !recentLocations.isEmpty {
                Section(String(localized: "location.recent", defaultValue: "Recent")) {
                    ForEach(recentLocations, id: \.self) { location in
                        Button {
                            select(location)
                        } label: {
                            Text(location)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }

            Section {
                ForEach(completer.results, id: \.title) { result in
                    Button {
                        resolve(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .foregroundStyle(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isResolving)
                }
            }
        }
        .onChange(of: query) { _, newValue in
            completer.update(query: newValue)
        }
        .overlay {
            if isResolving {
                ProgressView()
            }
        }
    }

    private var recentLocations: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentLocationsData.utf8))) ?? []
    }

    @ViewBuilder
    private func confirmationView(for item: MKMapItem) -> some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition) {
                Marker(item.name ?? "", coordinate: item.placemark.coordinate)
                    .tint(.red)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name ?? item.placemark.title ?? "-")
                    .font(.headline)
                if let address = item.placemark.title, address != item.name {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Button {
                select(item.name ?? item.placemark.title ?? "")
            } label: {
                Text(String(localized: "template.meeting.useThisLocation"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])
        }
    }

    private func select(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        saveRecent(trimmed)
        onSelect(trimmed)
        dismiss()
    }

    private func saveRecent(_ value: String) {
        var locations = recentLocations.filter { $0 != value }
        locations.insert(value, at: 0)
        locations = Array(locations.prefix(8))
        guard let data = try? JSONEncoder().encode(locations),
              let encoded = String(data: data, encoding: .utf8) else { return }
        recentLocationsData = encoded
    }

    private func useCurrentLocation() {
        isLocating = true
        locationError = nil
        Task {
            do {
                select(try await locationService.currentAddress())
            } catch {
                locationError = error.localizedDescription
            }
            isLocating = false
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        isResolving = true
        Task {
            let item = try? await completer.resolve(completion)
            isResolving = false
            guard let item else { return }
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: item.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
            selectedItem = item
        }
    }
}
