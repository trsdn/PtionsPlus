import Foundation

/// Identity metadata embedded in the app bundle at build time.
///
/// Every value is read from `Info.plist` rather than hardcoded here, so the
/// running app can only ever report what the build actually produced. The
/// plist values themselves are derived from the tag and repository during a
/// release and are verified by `scripts/verify-version.sh`.
enum ProductIdentity {
    /// Marketing version, for example `1.1.4`.
    static let version: String = string(for: "CFBundleShortVersionString") ?? "unknown"

    /// Build number, monotonic across releases.
    static let build: String = string(for: "CFBundleVersion") ?? "unknown"

    /// Display name of the product.
    static let name: String =
        string(for: "CFBundleDisplayName") ?? string(for: "CFBundleName") ?? Constants.appName

    /// Copyright holder and year.
    static let copyright: String = string(for: "NSHumanReadableCopyright") ?? ""

    /// SPDX identifier of the licence the product is released under.
    static let licenseIdentifier: String = string(for: "TRSLicenseIdentifier") ?? "MIT"

    /// Source repository.
    static let repositoryURL: URL =
        url(for: "TRSRepositoryURL")
        ?? URL(string: "https://github.com/trsdn/PtionsPlus")!

    /// Issue tracker, where a user should report a defect.
    static let issuesURL: URL =
        url(for: "TRSIssuesURL")
        ?? URL(string: "https://github.com/trsdn/PtionsPlus/issues")!

    /// Full licence text bundled with the app, when present.
    static var licenseText: String? {
        guard let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Human-readable version, for example `1.1.4 (6)`.
    static var versionDisplay: String {
        "\(version) (\(build))"
    }

    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    private static func url(for key: String) -> URL? {
        guard let value = string(for: key) else { return nil }
        return URL(string: value)
    }
}
