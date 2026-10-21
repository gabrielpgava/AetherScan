import CoreLocation
import Combine
import Foundation
import AppKit

@MainActor
final class LocationPermissionService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager: CLLocationManager
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshStatus() {
        updateStatus(manager.authorizationStatus)
    }

    func openSystemSettings() {
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
        ].compactMap(URL.init(string:))

        for url in settingsURLs where NSWorkspace.shared.open(url) {
            return
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.updateStatus(status)
        }
    }

    private func updateStatus(_ status: CLAuthorizationStatus) {
        guard authorizationStatus != status else { return }
        authorizationStatus = status
        onAuthorizationChange?(status)
    }
}
