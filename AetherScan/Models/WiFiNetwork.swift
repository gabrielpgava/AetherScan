import CoreWLAN
import Foundation

enum WiFiBand: String, CaseIterable, Identifiable {
    case twoFour = "2.4"
    case five = "5"
    case six = "6"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoFour: L10n.text("band.2_4")
        case .five: L10n.text("band.5")
        case .six: L10n.text("band.6")
        }
    }

    init?(coreWLANBand: CWChannelBand) {
        switch coreWLANBand {
        case .band2GHz: self = .twoFour
        case .band5GHz: self = .five
        case .band6GHz: self = .six
        default: return nil
        }
    }
}

struct WiFiNetwork: Identifiable, Hashable {
    let id: String
    let ssid: String?
    let bssid: String?
    let channel: Int?
    let band: WiFiBand?
    let channelWidthMHz: Int?
    let rssi: Int
    let frequencyMHz: Int?
    let isCurrent: Bool

    var displayName: String {
        guard let ssid, !ssid.isEmpty else { return L10n.text("network.hidden") }
        return ssid
    }

    var channelText: String {
        guard let channel else { return "—" }
        return L10n.text("format.channel", channel)
    }

    var widthText: String {
        guard let channelWidthMHz else { return "—" }
        return L10n.text("format.width", channelWidthMHz)
    }

    var frequencyText: String {
        guard let frequencyMHz else { return "—" }
        return L10n.text("format.frequency", Double(frequencyMHz) / 1_000)
    }
}

struct CurrentConnection: Equatable {
    let ssid: String?
    let bssid: String?
    let channel: Int?
    let band: WiFiBand?
    let channelWidthMHz: Int?
    let rssi: Int?

    var displayName: String {
        guard let ssid, !ssid.isEmpty else { return L10n.text("connection.nameUnavailable") }
        return ssid
    }

    var channelText: String {
        guard let channel else { return L10n.text("connection.channelUnavailable") }
        return L10n.text("format.channel", channel)
    }
}

struct ScanSnapshot {
    let networks: [WiFiNetwork]
    let currentConnection: CurrentConnection?
    let supported5GHzChannels: [Int]
    let scannedAt: Date
}

enum NetworkFilter: String, CaseIterable, Identifiable {
    case all
    case twoFour
    case five
    case six
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.text("filter.all")
        case .twoFour: L10n.text("band.2_4")
        case .five: L10n.text("band.5")
        case .six: L10n.text("band.6")
        case .mine: L10n.text("filter.mine")
        }
    }

    func includes(_ network: WiFiNetwork) -> Bool {
        switch self {
        case .all: true
        case .twoFour: network.band == .twoFour
        case .five: network.band == .five
        case .six: network.band == .six
        case .mine: network.isCurrent
        }
    }
}

enum ChannelHealth {
    case clear
    case coChannel
    case overlap
    case unavailable

    var title: String {
        switch self {
        case .clear: L10n.text("health.clear")
        case .coChannel: L10n.text("health.shared")
        case .overlap: L10n.text("health.overlap")
        case .unavailable: L10n.text("health.unavailable")
        }
    }

    var symbol: String {
        switch self {
        case .clear: "checkmark.circle.fill"
        case .coChannel: "person.2.fill"
        case .overlap: "exclamationmark.triangle.fill"
        case .unavailable: "questionmark.circle"
        }
    }
}

enum ChannelDiagnostics {
    private static let adjacentOverlap24GHzChannels: Set<Int> = [2, 3, 4, 5, 7, 8, 9, 10]

    static func health(for target: WiFiNetwork, among networks: [WiFiNetwork]) -> ChannelHealth {
        guard let band = target.band, let channel = target.channel else { return .unavailable }

        let peers = networks.filter { $0.id != target.id && $0.band == band }

        if peers.contains(where: { $0.channel == channel }) {
            return .coChannel
        }

        guard band == .twoFour else { return .clear }

        // A 40 MHz 2.4 GHz network spans the standard 20 MHz channel plan.
        if let width = target.channelWidthMHz, width >= 40 {
            return .overlap
        }

        if adjacentOverlap24GHzChannels.contains(channel) {
            return .overlap
        }

        let targetFrequency = Double(target.frequencyMHz ?? (2_407 + channel * 5))
        let targetHalfWidth = Double(target.channelWidthMHz ?? 20) / 2

        let hasAdjacentOverlap = peers.contains { peer in
            guard let peerChannel = peer.channel else { return false }
            let peerFrequency = Double(peer.frequencyMHz ?? (2_407 + peerChannel * 5))
            let peerHalfWidth = Double(peer.channelWidthMHz ?? 20) / 2
            return abs(targetFrequency - peerFrequency) < targetHalfWidth + peerHalfWidth
        }

        return hasAdjacentOverlap ? .overlap : .clear
    }
}

struct ChannelRecommendation {
    let channel: Int
    let estimatedLoad: Double

    var title: String { L10n.text("format.channel", channel) }

    static func best2_4GHz(in networks: [WiFiNetwork]) -> ChannelRecommendation {
        [1, 6, 11]
            .map { ChannelRecommendation(channel: $0, estimatedLoad: load(for: $0, band: .twoFour, in: networks)) }
            .min {
                if $0.estimatedLoad == $1.estimatedLoad { return $0.channel < $1.channel }
                return $0.estimatedLoad < $1.estimatedLoad
            }!
    }

    static func best5GHz(in networks: [WiFiNetwork], supportedChannels: [Int]) -> ChannelRecommendation? {
        let candidates = Array(Set(supportedChannels)).sorted()
        guard !candidates.isEmpty else { return nil }

        return candidates
            .map { ChannelRecommendation(channel: $0, estimatedLoad: load(for: $0, band: .five, in: networks)) }
            .min {
                if $0.estimatedLoad == $1.estimatedLoad { return $0.channel < $1.channel }
                return $0.estimatedLoad < $1.estimatedLoad
            }
    }

    private static func load(for channel: Int, band: WiFiBand, in networks: [WiFiNetwork]) -> Double {
        let candidateFrequency: Double
        switch band {
        case .twoFour: candidateFrequency = Double(channel == 14 ? 2_484 : 2_407 + channel * 5)
        case .five: candidateFrequency = Double(5_000 + channel * 5)
        case .six: candidateFrequency = Double(5_950 + channel * 5)
        }

        return networks
            .filter { !$0.isCurrent && $0.band == band && $0.frequencyMHz != nil }
            .reduce(0) { total, network in
                let networkFrequency = Double(network.frequencyMHz ?? Int(candidateFrequency))
                let networkWidth = Double(network.channelWidthMHz ?? 20)
                let totalHalfWidth = (20 + networkWidth) / 2
                let distance = abs(candidateFrequency - networkFrequency)
                let overlap = max(0, totalHalfWidth - distance) / totalHalfWidth
                let boundedRSSI = min(-20, max(-100, network.rssi))
                let signalWeight = pow(10, Double(boundedRSSI + 100) / 20)
                return total + signalWeight * overlap
            }
    }
}
