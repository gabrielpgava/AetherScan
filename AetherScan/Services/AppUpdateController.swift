import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class AppUpdateController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading
        case ready
        case installing
        case upToDate
        case failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var availableVersion: String?
    @Published private(set) var failureMessageKey: String?

    private let defaults = UserDefaults.standard
    private let installedVersion: SemanticVersion
    private var stagedAppURL: URL?
    private var updateTask: Task<Void, Never>?
    private var automaticCheckTask: Task<Void, Never>?
    private var installerProcess: Process?

    private static let repository = "gabrielpgava/AetherScan"
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    private static let maximumArchiveSize = 100 * 1024 * 1024
    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private static let lastCheckKey = "AetherScan.Updater.lastSuccessfulCheck"
    private static let pendingVersionKey = "AetherScan.Updater.pendingVersion"
    private static let pendingPathKey = "AetherScan.Updater.pendingAppPath"
    private static let installAttemptKey = "AetherScan.Updater.installAttempt"

    private static let installScript = #"""
        set -eu
        process_id="$1"
        destination="$2"
        source="$3"
        staging="$4"
        ready_marker="$5"
        case "$destination" in
            /*/AetherScan.app) ;;
            *) exit 64 ;;
        esac
        [ "$destination" != "/AetherScan.app" ] || exit 64
        [ -d "$source" ] || exit 65
        backup="${destination}.aetherscan-update-backup"
        if [ -e "$staging" ] || [ -L "$staging" ] || [ -e "$backup" ] || [ -L "$backup" ]; then exit 1; fi
        if ! /usr/bin/ditto "$source" "$staging"; then
            /bin/rm -rf "$staging"
            exit 1
        fi
        /usr/bin/touch "$ready_marker"
        while /bin/kill -0 "$process_id" 2>/dev/null; do
            /bin/sleep 0.25
        done
        /bin/rm -f "$ready_marker"
        if ! /bin/mv "$destination" "$backup"; then
            /bin/rm -rf "$staging"
            /usr/bin/open -n -a "$destination" || true
            exit 1
        fi
        if ! /bin/mv "$staging" "$destination"; then
            /bin/mv "$backup" "$destination" || true
            /bin/rm -rf "$staging"
            /usr/bin/open -n -a "$destination" || true
            exit 1
        fi
        /bin/rm -rf "$backup"
        if [ "$(/usr/bin/id -u)" -eq 0 ]; then
            console_uid="$(/usr/bin/stat -f '%u' /dev/console)"
            if [ "$console_uid" -gt 0 ]; then
                /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "#$console_uid" /usr/bin/open -n -a "$destination" || /usr/bin/open -n -a "$destination"
            else
                /usr/bin/open -n -a "$destination"
            fi
        else
            /usr/bin/open -n -a "$destination"
        fi
        """#

    private static let authorizationAppleScript = """
        on run argv
            do shell script (item 1 of argv) with administrator privileges
        end run
        """

    init() {
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        installedVersion = SemanticVersion(versionString) ?? .zero
        restoreSavedUpdateState()
    }

    var isBusy: Bool {
        phase == .checking || phase == .downloading || phase == .installing
    }

    var hasReadyUpdate: Bool {
        phase == .ready && stagedAppURL != nil
    }

    var canInstallUpdate: Bool {
        hasReadyUpdate && !isDevelopmentBuild
    }

    var requiresAdministratorAuthorization: Bool {
        guard canInstallUpdate else { return false }
        return !FileManager.default.isWritableFile(atPath: installBundleURL.deletingLastPathComponent().path)
    }

    var statusMessage: String {
        if let failureMessageKey {
            return L10n.text(failureMessageKey)
        }

        switch phase {
        case .idle:
            return L10n.text("update.status.idle")
        case .checking:
            return L10n.text("update.status.checking")
        case .downloading:
            return L10n.text("update.status.downloading", availableVersion ?? "")
        case .ready:
            return canInstallUpdate
                ? L10n.text("update.status.ready", availableVersion ?? "")
                : L10n.text("update.status.developmentBuild")
        case .installing:
            return L10n.text("update.status.installing")
        case .upToDate:
            return L10n.text("update.status.upToDate")
        case .failed:
            return L10n.text("update.status.checkFailed")
        }
    }

    func startAutomaticChecks() {
        guard automaticCheckTask == nil else { return }
        checkForUpdatesIfNeeded()

        automaticCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 86_400_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.checkForUpdatesIfNeeded()
            }
        }
    }

    func checkForUpdatesIfNeeded() {
        guard !isBusy, !hasReadyUpdate else { return }
        if let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date {
            let elapsed = Date().timeIntervalSince(lastCheck)
            if elapsed >= 0, elapsed < Self.automaticCheckInterval { return }
        }
        checkForUpdates()
    }

    func checkForUpdates() {
        guard !isBusy, !hasReadyUpdate else { return }
        phase = .checking
        failureMessageKey = nil

        updateTask = Task { [weak self] in
            guard let self else { return }
            defer { self.updateTask = nil }

            do {
                let release = try await self.fetchLatestRelease()
                self.defaults.set(Date(), forKey: Self.lastCheckKey)

                guard release.version > self.installedVersion else {
                    self.discardPendingUpdate()
                    self.phase = .upToDate
                    return
                }

                self.availableVersion = release.version.description
                self.phase = .downloading
                let appURL = try await self.downloadAndPrepare(release)
                self.stagedAppURL = appURL
                self.defaults.set(release.version.description, forKey: Self.pendingVersionKey)
                self.defaults.set(appURL.path, forKey: Self.pendingPathKey)
                self.failureMessageKey = nil
                self.phase = .ready
            } catch let error as UpdateError {
                self.failureMessageKey = error.messageKey
                self.phase = .failed
            } catch {
                self.failureMessageKey = self.phase == .downloading
                    ? "update.status.downloadFailed"
                    : "update.status.checkFailed"
                self.phase = .failed
            }
        }
    }

    func installUpdate() {
        guard canInstallUpdate, let stagedAppURL else {
            failureMessageKey = "update.status.developmentBuild"
            return
        }

        let destination = installBundleURL
        guard destination.lastPathComponent == "AetherScan.app",
              Bundle.main.bundleIdentifier == "com.aetherscan.mac",
              destination.deletingLastPathComponent().path != "/"
        else {
            failureMessageKey = "update.status.installFailed"
            return
        }

        let markerID = UUID().uuidString
        let destinationDirectory = destination.deletingLastPathComponent()
        let readyMarker = destinationDirectory.appendingPathComponent(".AetherScan-update-\(markerID).ready")
        let staging = destinationDirectory.appendingPathComponent(
            ".AetherScan-update-\(markerID).app",
            isDirectory: true
        )

        defaults.set(availableVersion, forKey: Self.installAttemptKey)
        failureMessageKey = nil
        phase = .installing

        let arguments = [
            String(ProcessInfo.processInfo.processIdentifier),
            destination.path,
            stagedAppURL.path,
            staging.path,
            readyMarker.path,
        ]

        let process = Process()
        if requiresAdministratorAuthorization {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            let commandArguments = ["/bin/sh", "-c", Self.installScript, "aetherscan-update"] + arguments
            let shellCommand = commandArguments.map(Self.shellQuoted).joined(separator: " ")
            process.arguments = ["-e", Self.authorizationAppleScript, shellCommand]
        } else {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", Self.installScript, "aetherscan-update"] + arguments
        }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            installerProcess = process
        } catch {
            defaults.removeObject(forKey: Self.installAttemptKey)
            failureMessageKey = "update.status.installFailed"
            phase = .ready
            return
        }

        Task { [weak self] in
            while process.isRunning {
                if FileManager.default.fileExists(atPath: readyMarker.path) {
                    NSApplication.shared.terminate(nil)
                    return
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }

            guard let self else { return }
            if FileManager.default.fileExists(atPath: readyMarker.path) {
                NSApplication.shared.terminate(nil)
                return
            }

            self.defaults.removeObject(forKey: Self.installAttemptKey)
            self.failureMessageKey = "update.status.authorizationCancelled"
            self.phase = .ready
        }
    }

    private func fetchLatestRelease() async throws -> ReleaseDescriptor {
        var request = URLRequest(url: Self.latestReleaseURL)
        request.timeoutInterval = 30
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AetherScan-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw UpdateError.checkFailed
        }

        let latest = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !latest.draft, !latest.prerelease,
              let version = SemanticVersion(latest.tagName)
        else {
            throw UpdateError.invalidRelease
        }

        let expectedName = "AetherScan-\(version)-macOS-universal.zip"
        guard let asset = latest.assets.first(where: { $0.name == expectedName }),
              let digest = asset.digest?.lowercased(),
              digest.hasPrefix("sha256:"),
              digest.dropFirst("sha256:".count).count == 64,
              digest.dropFirst("sha256:".count).allSatisfy(\.isHexDigit),
              let downloadURL = URL(string: asset.browserDownloadURL),
              let components = URLComponents(url: downloadURL, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == "github.com",
              components.path == "/\(Self.repository)/releases/download/\(latest.tagName)/\(expectedName)"
        else {
            throw UpdateError.invalidRelease
        }

        if let size = asset.size, size <= 0 || size > Self.maximumArchiveSize {
            throw UpdateError.invalidRelease
        }

        return ReleaseDescriptor(
            version: version,
            archiveName: expectedName,
            downloadURL: downloadURL,
            digest: String(digest.dropFirst("sha256:".count)),
            size: asset.size
        )
    }

    private func downloadAndPrepare(_ release: ReleaseDescriptor) async throws -> URL {
        var request = URLRequest(url: release.downloadURL)
        request.timeoutInterval = 120
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("AetherScan-Updater", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              let finalURL = response.url,
              finalURL.scheme?.lowercased() == "https",
              ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"]
                .contains(finalURL.host?.lowercased() ?? "")
        else {
            throw UpdateError.downloadFailed
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 0, fileSize <= Int64(Self.maximumArchiveSize),
              release.size == nil || fileSize == release.size
        else {
            throw UpdateError.verificationFailed
        }

        let archiveData = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
        let actualDigest = SHA256.hash(data: archiveData).map { String(format: "%02x", $0) }.joined()
        guard actualDigest == release.digest else {
            throw UpdateError.verificationFailed
        }

        let updateDirectory = updatesRoot.appendingPathComponent(release.version.description, isDirectory: true)
        if FileManager.default.fileExists(atPath: updateDirectory.path) {
            try FileManager.default.removeItem(at: updateDirectory)
        }
        try FileManager.default.createDirectory(at: updateDirectory, withIntermediateDirectories: true)

        let archiveURL = updateDirectory.appendingPathComponent(release.archiveName)
        try FileManager.default.moveItem(at: temporaryURL, to: archiveURL)

        let extractionDirectory = updateDirectory.appendingPathComponent("Extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
        try await Self.runProcess(
            "/usr/bin/ditto",
            arguments: ["-x", "-k", archiveURL.path, extractionDirectory.path]
        )

        let candidateApp = extractionDirectory.appendingPathComponent("AetherScan.app", isDirectory: true)
        guard let candidateBundle = Bundle(url: candidateApp),
              candidateBundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              let bundleVersion = candidateBundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              SemanticVersion(bundleVersion) == release.version,
              let executableName = candidateBundle.object(forInfoDictionaryKey: "CFBundleExecutable") as? String,
              FileManager.default.fileExists(
                atPath: candidateApp.appendingPathComponent("Contents/MacOS", isDirectory: true)
                    .appendingPathComponent(executableName).path
              )
        else {
            throw UpdateError.verificationFailed
        }

        try await Self.runProcess(
            "/usr/bin/codesign",
            arguments: ["--verify", "--deep", "--strict", candidateApp.path]
        )
        let candidateExecutable = candidateApp.appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(executableName).path
        for architecture in ["arm64", "x86_64"] {
            try await Self.runProcess(
                "/usr/bin/lipo",
                arguments: [candidateExecutable, "-verify_arch", architecture]
            )
        }
        return candidateApp
    }

    private func restoreSavedUpdateState() {
        let attemptedVersion = defaults.string(forKey: Self.installAttemptKey)
            .flatMap(SemanticVersion.init)
        if let attemptedVersion, installedVersion >= attemptedVersion {
            discardPendingUpdate()
            defaults.removeObject(forKey: Self.installAttemptKey)
            phase = .upToDate
            return
        }

        if let pendingVersionString = defaults.string(forKey: Self.pendingVersionKey),
           let pendingVersion = SemanticVersion(pendingVersionString),
           pendingVersion > installedVersion,
           let pendingPath = defaults.string(forKey: Self.pendingPathKey),
           FileManager.default.fileExists(atPath: pendingPath) {
            availableVersion = pendingVersion.description
            stagedAppURL = URL(fileURLWithPath: pendingPath)
            phase = .ready
            if attemptedVersion != nil {
                failureMessageKey = "update.status.installFailed"
            }
            return
        }

        if attemptedVersion != nil {
            defaults.removeObject(forKey: Self.installAttemptKey)
            failureMessageKey = "update.status.installFailed"
            phase = .failed
        }
    }

    private func discardPendingUpdate() {
        if let pendingPath = defaults.string(forKey: Self.pendingPathKey) {
            let pendingURL = URL(fileURLWithPath: pendingPath).standardizedFileURL
            let managedRoot = updatesRoot.standardizedFileURL.path + "/"
            if pendingURL.path.hasPrefix(managedRoot) {
                let releaseDirectory = pendingURL
                    .deletingLastPathComponent()
                    .deletingLastPathComponent()
                try? FileManager.default.removeItem(at: releaseDirectory)
            }
        }
        defaults.removeObject(forKey: Self.pendingPathKey)
        defaults.removeObject(forKey: Self.pendingVersionKey)
        stagedAppURL = nil
        availableVersion = nil
    }

    private var installBundleURL: URL {
        Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    private var isDevelopmentBuild: Bool {
        installBundleURL.path.contains("/DerivedData/")
    }

    private var updatesRoot: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AetherScan", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runProcess(_ executable: String, arguments: [String]) async throws {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                throw UpdateError.verificationFailed
            }
        }.value
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let digest: String?
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case digest
        case size
    }
}

private struct ReleaseDescriptor {
    let version: SemanticVersion
    let archiveName: String
    let downloadURL: URL
    let digest: String
    let size: Int64?
}

private struct SemanticVersion: Comparable, Equatable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    static let zero = SemanticVersion(major: 0, minor: 0, patch: 0)

    init?(_ value: String) {
        let normalized = value.hasPrefix("v") || value.hasPrefix("V")
            ? String(value.dropFirst())
            : value
        let components = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2])
        else {
            return nil
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    private init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    var description: String { "\(major).\(minor).\(patch)" }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

private enum UpdateError: Error {
    case checkFailed
    case invalidRelease
    case downloadFailed
    case verificationFailed

    var messageKey: String {
        switch self {
        case .checkFailed:
            "update.status.checkFailed"
        case .invalidRelease:
            "update.status.invalidRelease"
        case .downloadFailed:
            "update.status.downloadFailed"
        case .verificationFailed:
            "update.status.verificationFailed"
        }
    }
}
