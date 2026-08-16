import SwiftUI
import MapKit

struct LocationSearchSheet: View {
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = LocationSearchCompleter()
    @State private var query: String = ""
    @State private var isResolving: Bool = false
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
        List(completer.results, id: \.title) { result in
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
        .searchable(text: $query, prompt: Text(String(localized: "template.meeting.searchLocationPlaceholder")))
        .onChange(of: query) { _, newValue in
            completer.update(query: newValue)
        }
        .overlay {
            if isResolving {
                ProgressView()
            }
        }
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
                onSelect(item.name ?? item.placemark.title ?? "")
                dismiss()
            } label: {
                Text(String(localized: "template.meeting.useThisLocation"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])
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
