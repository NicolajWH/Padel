import Foundation
import CoreLocation

/// One-shot async wrapper around CLLocationManager, used to tag shared
/// matches with the court's position and to find matches nearby.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var isAuthorizationDenied = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Like `currentLocation()`, but never prompts for permission — returns
    /// nil unless access was already granted. Used for passive discovery on
    /// the home screen, where a surprise permission dialog would be rude.
    func currentLocationIfAuthorized() async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }
        return await currentLocation()
    }

    /// Returns the current location, asking for permission if needed.
    /// Resolves to nil if permission is denied or the fix fails.
    func currentLocation() async -> CLLocation? {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            isAuthorizationDenied = true
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // The delegate callback re-triggers the request once authorized.
        default:
            break
        }

        guard continuation == nil else {
            // A request is already in flight; don't stack another.
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if self.manager.authorizationStatus == .authorizedWhenInUse
                || self.manager.authorizationStatus == .authorizedAlways {
                self.manager.requestLocation()
            }
            // If still .notDetermined we wait for locationManagerDidChangeAuthorization.
        }
    }

    private func finish(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isAuthorizationDenied = false
                if self.continuation != nil {
                    self.manager.requestLocation()
                }
            case .denied, .restricted:
                self.isAuthorizationDenied = true
                self.finish(with: nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.finish(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.finish(with: nil)
        }
    }
}
