import CoreLocation
import Combine
import Foundation

enum ScannerStatus: Equatable {
    case idle
    case awaitingPermission
    case scanning
    case ready
    case permissionDenied
    case restricted
    case failed(String)

    var isScanning: Bool {
        if case .scanning = self { return true }
        return false
    }
}

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published private(set) var status: ScannerStatus = .idle
    @Published private(set) var networks: [WiFiNetwork] = []
    @Published private(set) var currentConnection: CurrentConnection?
    @Published private(set) var supported5GHzChannels: [Int] = []
    @Published private(set) var scannedAt: Date?

    private let permission = LocationPermissionService()
    private let scanner = WiFiScanner()
    private let scanQueue = DispatchQueue(label: "com.aetherscan.scan", qos: .userInitiated)
    private var hasStarted = false

    init() {
        permission.onAuthorizationChange = { [weak self] authorization in
            self?.handleAuthorizationChange(authorization)
        }
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        refresh()
    }

    func refresh() {
        switch permission.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            performScan()
        case .notDetermined:
            status = .awaitingPermission
            permission.requestWhenInUseAuthorization()
        case .denied:
            status = .permissionDenied
        case .restricted:
            status = .restricted
        @unknown default:
            status = .permissionDenied
        }
    }

    func refreshAuthorizationStatus() {
        permission.refreshStatus()
        handleAuthorizationChange(permission.authorizationStatus)
    }

    func openSystemSettings() {
        permission.openSystemSettings()
    }

    private func handleAuthorizationChange(_ authorization: CLAuthorizationStatus) {
        switch authorization {
        case .authorizedAlways, .authorizedWhenInUse:
            if status == .awaitingPermission || status == .permissionDenied || status == .restricted {
                performScan()
            }
        case .denied:
            if status == .awaitingPermission { status = .permissionDenied }
        case .restricted:
            if status == .awaitingPermission { status = .restricted }
        case .notDetermined:
            break
        @unknown default:
            if status == .awaitingPermission { status = .permissionDenied }
        }
    }

    private func performScan() {
        guard !status.isScanning else { return }
        status = .scanning

        scanQueue.async { [weak self, scanner] in
            do {
                let snapshot = try scanner.scan()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.networks = snapshot.networks
                    self.currentConnection = snapshot.currentConnection
                    self.supported5GHzChannels = snapshot.supported5GHzChannels
                    self.scannedAt = snapshot.scannedAt
                    self.status = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    let message: String
                    if case WiFiScannerError.interfaceUnavailable = error {
                        message = L10n.text("error.interfaceUnavailable")
                    } else {
                        message = L10n.text("error.scanFailed")
                    }
                    self.status = .failed(message)
                }
            }
        }
    }
}
