import SwiftUI

/// About window: states the exact version this build is, and gives the user a
/// route to the repository and the issue tracker from inside the product.
struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ProductIdentity.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Version \(ProductIdentity.versionDisplay)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityLabel(
                            "Version \(ProductIdentity.version), build \(ProductIdentity.build)")

                    Text("Maps extra mouse buttons to keyboard shortcuts, per app.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Link("Source repository", destination: ProductIdentity.repositoryURL)
                    .accessibilityHint("Opens the Ptions+ source repository in your browser")

                Link("Report an issue", destination: ProductIdentity.issuesURL)
                    .accessibilityHint("Opens the Ptions+ issue tracker in your browser")
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if !ProductIdentity.copyright.isEmpty {
                    Text(ProductIdentity.copyright)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("Released under the \(ProductIdentity.licenseIdentifier) licence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Ptions+ makes no network requests and collects no data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(
                """
                Not affiliated with, endorsed by, or associated with Logitech or Logi. \
                Product names are used solely to identify compatibility.
                """
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 380, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About \(ProductIdentity.name)")
    }
}
