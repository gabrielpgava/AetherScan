import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var selectedFilter: NetworkFilter = .all

    private var filteredNetworks: [WiFiNetwork] {
        viewModel.networks.filter(selectedFilter.includes)
    }

    private var recommendation24GHz: ChannelRecommendation? {
        guard viewModel.scannedAt != nil else { return nil }
        return ChannelRecommendation.best2_4GHz(in: viewModel.networks)
    }

    private var recommendation5GHz: ChannelRecommendation? {
        ChannelRecommendation.best5GHz(
            in: viewModel.networks,
            supportedChannels: viewModel.supported5GHzChannels
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            connectionSummary

            VStack(alignment: .leading, spacing: 12) {
                filterBar
                resultsContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            recommendations
            Text(L10n.text("footer.scanLimitations"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(minWidth: 920, minHeight: 680)
        .task { viewModel.startIfNeeded() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshAuthorizationStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            appSymbol
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("AetherScan")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text(L10n.text("app.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let scannedAt = viewModel.scannedAt {
                Text(L10n.text("scan.lastUpdated", scannedAt.formatted(date: .omitted, time: .shortened)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: viewModel.refresh) {
                HStack(spacing: 8) {
                    if viewModel.status.isScanning {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(L10n.text("button.refresh"))
                }
                .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("r", modifiers: .command)
            .disabled(viewModel.status.isScanning)
            .help(L10n.text("button.refresh.help"))
        }
    }

    @ViewBuilder
    private var appSymbol: some View {
        if let symbol = NSImage(systemSymbolName: "wifi.badge.plus", accessibilityDescription: "AetherScan") {
            Image(nsImage: symbol)
        } else {
            Image(systemName: "wifi")
        }
    }

    private var connectionSummary: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.currentConnection == nil ? "wifi.slash" : "wifi")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(viewModel.currentConnection == nil ? Color.secondary : Color.blue)
                .frame(width: 40, height: 40)
                .background(.quaternary, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                if let connection = viewModel.currentConnection {
                    Text(L10n.text("connection.connectedTo", connection.displayName))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 6) {
                        Text(connection.channelText)
                        if let band = connection.band {
                            Text("·")
                            Text(band.title)
                        }
                        if let width = connection.channelWidthMHz {
                            Text("·")
                            Text(L10n.text("format.width", width))
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else if viewModel.status.isScanning || viewModel.status == .awaitingPermission {
                    Text(L10n.text("connection.checking"))
                        .font(.headline)
                    Text(L10n.text("connection.waitingForScan"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(L10n.text("connection.notConnected"))
                        .font(.headline)
                    Text(L10n.text("connection.noActiveNetwork"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let rssi = viewModel.currentConnection?.rssi, rssi != 0 {
                SignalIndicator(rssi: rssi)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            Picker(L10n.text("filter.title"), selection: $selectedFilter) {
                ForEach(NetworkFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 620)

            Spacer(minLength: 8)

            Text(L10n.text("scan.networkCount", filteredNetworks.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var resultsContent: some View {
        switch viewModel.status {
        case .permissionDenied:
            PermissionNotice(
                title: L10n.text("permission.denied.title"),
                message: L10n.text("permission.denied.message"),
                actionTitle: L10n.text("button.openSettings"),
                action: viewModel.openSystemSettings
            )
        case .restricted:
            PermissionNotice(
                title: L10n.text("permission.restricted.title"),
                message: L10n.text("permission.restricted.message"),
                actionTitle: L10n.text("button.openSettings"),
                action: viewModel.openSystemSettings
            )
        case .failed(let message):
            ErrorNotice(message: message, retry: viewModel.refresh)
        case .awaitingPermission:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(L10n.text("permission.waiting"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            if !filteredNetworks.isEmpty {
                networkTable
            } else if viewModel.status.isScanning {
                LoadingRows()
            } else if viewModel.status == .ready, selectedFilter == .mine {
                EmptyResults(
                    title: L10n.text("empty.mine.title"),
                    message: L10n.text("empty.mine.message")
                )
            } else if viewModel.status == .ready {
                EmptyResults(
                    title: L10n.text("empty.scan.title"),
                    message: L10n.text("empty.scan.message")
                )
            } else {
                LoadingRows()
            }
        }
    }

    private var networkTable: some View {
        Table(filteredNetworks) {
            TableColumn(L10n.text("table.network")) { network in
                NetworkNameCell(network: network)
            }
            .width(min: 180, ideal: 260, max: 380)

            TableColumn(L10n.text("table.bandChannel")) { network in
                VStack(alignment: .leading, spacing: 3) {
                    Text(network.band?.title ?? "—")
                        .font(.body)
                    Text(network.channelText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 105, ideal: 130)

            TableColumn(L10n.text("table.frequency")) { network in
                Text(network.frequencyText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 90, ideal: 110)

            TableColumn(L10n.text("table.width")) { network in
                Text(network.widthText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(min: 75, ideal: 90)

            TableColumn(L10n.text("table.signal")) { network in
                SignalIndicator(rssi: network.rssi)
            }
            .width(min: 100, ideal: 118)

            TableColumn(L10n.text("table.health")) { network in
                HealthBadge(health: ChannelDiagnostics.health(for: network, among: viewModel.networks))
            }
            .width(min: 150, ideal: 180)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .accessibilityLabel(L10n.text("table.accessibilityLabel"))
    }

    private var recommendations: some View {
        HStack(alignment: .center, spacing: 18) {
            SignalSpectrumArtwork(
                state: viewModel.scannedAt != nil ? .diagnostic : (viewModel.status.isScanning ? .scanning : .empty)
            )
            .frame(width: 54, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("recommendation.title"))
                    .font(.headline)
                Text(L10n.text("recommendation.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RecommendationItem(
                band: L10n.text("band.2_4"),
                recommendation: recommendation24GHz,
                scanCompleted: viewModel.scannedAt != nil
            )

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1, height: 38)

            RecommendationItem(
                band: L10n.text("band.5"),
                recommendation: recommendation5GHz,
                scanCompleted: viewModel.scannedAt != nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct NetworkNameCell: View {
    let network: WiFiNetwork

    var body: some View {
        HStack(spacing: 9) {
            if network.isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
                    .accessibilityLabel(L10n.text("network.current"))
            } else {
                Image(systemName: "wifi")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(network.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if network.isCurrent {
                    if let bssid = network.bssid {
                        Text(bssid)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(L10n.text("network.current"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                } else if let bssid = network.bssid {
                    Text(bssid)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct SignalIndicator: View {
    let rssi: Int

    private var tint: Color {
        if rssi >= -60 { return .green }
        if rssi >= -75 { return .orange }
        return .red
    }

    var body: some View {
        Label {
            Text(L10n.text("format.rssi", rssi))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "wifi")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
        }
        .labelStyle(.titleAndIcon)
    }
}

private struct HealthBadge: View {
    let health: ChannelHealth

    private var tint: Color {
        switch health {
        case .clear: .green
        case .coChannel: .orange
        case .overlap: .red
        case .unavailable: .secondary
        }
    }

    var body: some View {
        Label(health.title, systemImage: health.symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.11), in: Capsule())
            .accessibilityLabel(health.title)
    }
}

private struct RecommendationItem: View {
    let band: String
    let recommendation: ChannelRecommendation?
    let scanCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(band)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let recommendation {
                Text(recommendation.title)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(L10n.text("recommendation.lowestLoad"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.title3.weight(.semibold))
                Text(L10n.text(scanCompleted ? "recommendation.unavailable" : "recommendation.pending"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 112, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct PermissionNotice: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "location.slash")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ErrorNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30))
                .foregroundStyle(.orange)
            Text(L10n.text("error.title"))
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.text("button.tryAgain"), action: retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct EmptyResults: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            SignalSpectrumArtwork(state: .empty)
                .frame(width: 132, height: 70)
                .padding(.bottom, 4)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct LoadingRows: View {
    private let rowWidths: [CGFloat] = [0.91, 0.78, 0.86, 0.67]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.text("scan.searching"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                SignalSpectrumArtwork(state: .scanning)
                    .frame(width: 42, height: 28)
                ProgressView().controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            ForEach(Array(rowWidths.enumerated()), id: \.offset) { _, width in
                HStack(spacing: 18) {
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 210 * width, height: 11)
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 76, height: 11)
                    RoundedRectangle(cornerRadius: 4).fill(.quaternary).frame(width: 88, height: 11)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 15)
                if width != rowWidths.last {
                    Divider().padding(.leading, 12)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel(L10n.text("scan.searching"))
    }
}
