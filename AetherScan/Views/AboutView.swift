import AppKit
import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var updateController: AppUpdateController
    @State private var isInstallConfirmationPresented = false

    private let companyWebsite = URL(string: "https://www.idealopposite.com")!

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("AetherScan")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                    Text(L10n.text("about.tagline"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.text("about.version", appVersion))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 20)

            Divider()

            HStack(spacing: 16) {
                Image("IdealOppositeMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityLabel(L10n.text("about.companyLogo"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("about.developedBy"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Ideal Opposite")
                        .font(.headline)
                    Text(L10n.text("about.companyDescriptor"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Link(L10n.text("about.website"), destination: companyWebsite)
                        .font(.callout)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("about.frameworksHeading"))
                    .font(.headline)
                Text(L10n.text("about.frameworks"))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.text("about.noThirdParty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 18)

            updatesSection

            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(width: 500, height: 500)
        .alert(L10n.text("update.confirm.title"), isPresented: $isInstallConfirmationPresented) {
            Button(L10n.text("update.confirm.install")) {
                updateController.installUpdate()
            }
            Button(L10n.text("update.confirm.later"), role: .cancel) {}
        } message: {
            Text(L10n.text("update.confirm.message"))
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 14)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("update.sectionTitle"))
                        .font(.headline)
                    Text(updateController.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(updateController.failureMessageKey == nil ? Color.secondary : Color.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if updateController.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 3)
                } else if updateController.hasReadyUpdate {
                    Button(L10n.text("update.installButton")) {
                        isInstallConfirmationPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!updateController.canInstallUpdate)
                } else {
                    Button(updateButtonTitle, action: updateController.checkForUpdates)
                        .buttonStyle(.bordered)
                }
            }

            if updateController.requiresAdministratorAuthorization {
                Label(L10n.text("update.authorizationNote"), systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if updateController.hasReadyUpdate {
                Text(L10n.text("update.integrityNote"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 2)
    }

    private var updateButtonTitle: String {
        switch updateController.phase {
        case .idle, .upToDate:
            L10n.text("update.checkButton")
        case .failed:
            L10n.text("update.retryButton")
        case .checking, .downloading, .ready, .installing:
            L10n.text("update.checkButton")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

#Preview("About and updates") {
    AboutView()
        .environmentObject(AppUpdateController())
}
