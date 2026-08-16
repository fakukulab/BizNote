import MapKit

@MainActor
final class LocationSearchCompleter: NSObject, ObservableObject {
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private lazy var delegate = Delegate(owner: self)

    override init() {
        super.init()
        completer.delegate = delegate
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func resolve(_ completion: MKLocalSearchCompletion) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.first
    }

    fileprivate func handleUpdate(_ results: [MKLocalSearchCompletion]) {
        self.results = results
    }

    private final class Delegate: NSObject, MKLocalSearchCompleterDelegate {
        weak var owner: LocationSearchCompleter?
        init(owner: LocationSearchCompleter) { self.owner = owner }

        func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
            let results = completer.results
            Task { @MainActor [owner] in
                owner?.handleUpdate(results)
            }
        }

        func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
            Task { @MainActor [owner] in
                owner?.handleUpdate([])
            }
        }
    }
}
