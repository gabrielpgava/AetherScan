import AppKit
import SwiftUI

struct AboutView: View {
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

            Spacer(minLength: 0)
        }
        .padding(26)
        .frame(width: 480, height: 400)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
