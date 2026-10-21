import CoreWLAN
import Foundation

enum WiFiScannerError: Error {
    case interfaceUnavailable
}

struct WiFiScanner {
    func scan() throws -> ScanSnapshot {
        guard let interface = CWWiFiClient.shared().interface() else {
            throw WiFiScannerError.interfaceUnavailable
        }

        let scanResults = try interface.scanForNetworks(withSSID: nil)
        let currentSSID = interface.ssid()
        let currentBSSID = interface.bssid()
        let currentChannel = interface.wlanChannel()

        let currentConnection: CurrentConnection? = {
            guard currentSSID != nil || currentBSSID != nil || currentChannel != nil else { return nil }
            return CurrentConnection(
                ssid: currentSSID,
                bssid: currentBSSID,
                channel: currentChannel.map { Int($0.channelNumber) },
                band: currentChannel.flatMap { WiFiBand(coreWLANBand: $0.channelBand) },
                channelWidthMHz: currentChannel.flatMap(Self.widthInMHz),
                rssi: interface.rssiValue()
            )
        }()

        var byIdentifier: [String: WiFiNetwork] = [:]
        for result in scanResults {
            let network = Self.makeNetwork(
                from: result,
                currentSSID: currentSSID,
                currentBSSID: currentBSSID
            )
            if let existing = byIdentifier[network.id], existing.rssi >= network.rssi {
                continue
            }
            byIdentifier[network.id] = network
        }

        if let currentConnection,
           currentConnection.ssid != nil || currentConnection.bssid != nil,
           !byIdentifier.values.contains(where: { Self.matches($0, ssid: currentSSID, bssid: currentBSSID) }),
           let channel = currentChannel {
            let band = WiFiBand(coreWLANBand: channel.channelBand)
            let channelNumber = Int(channel.channelNumber)
            let network = WiFiNetwork(
                id: currentBSSID ?? "\(currentSSID ?? "current-network")-\(channelNumber)",
                ssid: currentSSID,
                bssid: currentBSSID,
                channel: channelNumber,
                band: band,
                channelWidthMHz: Self.widthInMHz(channel),
                rssi: interface.rssiValue(),
                frequencyMHz: band.map { Self.frequencyMHz(channel: channelNumber, band: $0) },
                isCurrent: true
            )
            byIdentifier[network.id] = network
        }

        let supported5GHzChannels = (interface.supportedWLANChannels() ?? [])
            .filter { $0.channelBand == .band5GHz }
            .map { Int($0.channelNumber) }
            .filter { $0 > 0 }

        return ScanSnapshot(
            networks: byIdentifier.values.sorted {
                if $0.isCurrent != $1.isCurrent { return $0.isCurrent }
                if $0.rssi != $1.rssi { return $0.rssi > $1.rssi }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            },
            currentConnection: currentConnection,
            supported5GHzChannels: supported5GHzChannels,
            scannedAt: Date()
        )
    }

    private static func makeNetwork(
        from result: CWNetwork,
        currentSSID: String?,
        currentBSSID: String?
    ) -> WiFiNetwork {
        let channel = result.wlanChannel
        let band = channel.flatMap { WiFiBand(coreWLANBand: $0.channelBand) }
        let channelNumber = channel.map { Int($0.channelNumber) }
        let ssid = result.ssid
        let bssid = result.bssid
        let isCurrent = matches(ssid: ssid, bssid: bssid, currentSSID: currentSSID, currentBSSID: currentBSSID)
        let fallbackID = "\(ssid ?? "hidden")|\(band?.rawValue ?? "unknown")|\(channelNumber ?? -1)"

        return WiFiNetwork(
            id: bssid ?? fallbackID,
            ssid: ssid,
            bssid: bssid,
            channel: channelNumber,
            band: band,
            channelWidthMHz: channel.flatMap(widthInMHz),
            rssi: Int(result.rssiValue),
            frequencyMHz: channelNumber.flatMap { number in
                band.map { frequencyMHz(channel: number, band: $0) }
            },
            isCurrent: isCurrent
        )
    }

    private static func matches(_ network: WiFiNetwork, ssid: String?, bssid: String?) -> Bool {
        matches(ssid: network.ssid, bssid: network.bssid, currentSSID: ssid, currentBSSID: bssid)
    }

    private static func matches(
        ssid: String?,
        bssid: String?,
        currentSSID: String?,
        currentBSSID: String?
    ) -> Bool {
        if let currentBSSID, let bssid {
            return currentBSSID.caseInsensitiveCompare(bssid) == .orderedSame
        }
        guard let currentSSID, let ssid else { return false }
        return currentSSID == ssid
    }

    private static func widthInMHz(_ channel: CWChannel) -> Int? {
        switch channel.channelWidth {
        case .width20MHz: 20
        case .width40MHz: 40
        case .width80MHz: 80
        case .width160MHz: 160
        default: nil
        }
    }

    private static func frequencyMHz(channel: Int, band: WiFiBand) -> Int {
        switch band {
        case .twoFour: channel == 14 ? 2_484 : 2_407 + channel * 5
        case .five: 5_000 + channel * 5
        case .six: 5_950 + channel * 5
        }
    }
}
