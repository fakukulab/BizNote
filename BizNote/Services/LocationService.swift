import CoreLocation

@MainActor
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authContinuation: CheckedContinuation<Void, Error>?
    private lazy var delegate = Delegate(owner: self)

    enum LocationError: LocalizedError {
        case permissionDenied
        case notFound

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return String(localized: "location.error.permissionDenied")
            case .notFound:
                return String(localized: "location.error.notFound")
            }
        }
    }

    override init() {
        super.init()
        manager.delegate = delegate
    }

    func currentAddress() async throws -> String {
        let location = try await requestCurrentLocation()
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw LocationError.notFound
        }
        let parts = [
            placemark.administrativeArea,
            placemark.locality,
            placemark.thoroughfare,
            placemark.subThoroughfare
        ].compactMap { $0 }
        guard !parts.isEmpty else { throw LocationError.notFound }
        return parts.joined(separator: " ")
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        try await ensureAuthorized()
        return try await withCheckedThrowingContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func ensureAuthorized() async throws {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied, .restricted:
            throw LocationError.permissionDenied
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                self.authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            return
        }
    }

    fileprivate func handleAuthChange(_ status: CLAuthorizationStatus) {
        guard let continuation = authContinuation else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            authContinuation = nil
            continuation.resume()
        case .denied, .restricted:
            authContinuation = nil
            continuation.resume(throwing: LocationError.permissionDenied)
        default:
            break
        }
    }

    fileprivate func handleLocationUpdate(_ locations: [CLLocation]) {
        guard let location = locations.last, let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: location)
    }

    fileprivate func handleLocationError(_ error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(throwing: error)
    }

    private final class Delegate: NSObject, CLLocationManagerDelegate {
        weak var owner: LocationService?
        init(owner: LocationService) { self.owner = owner }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            let status = manager.authorizationStatus
            Task { @MainActor [owner] in
                owner?.handleAuthChange(status)
            }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            Task { @MainActor [owner] in
                owner?.handleLocationUpdate(locations)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            Task { @MainActor [owner] in
                owner?.handleLocationError(error)
            }
        }
    }
}
