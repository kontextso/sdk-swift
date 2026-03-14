import UIKit

/// Current device operating system properties
struct OSInfo {
    /// "android" | "ios" | "web" | "windows" | ...
    let name: String
    /// "16.5"
    let version: String
    /// BCP-47, e.g. "cs-CZ"
    let locale: String
    /// IANA, e.g. "Europe/Prague"
    let timezone: String
}

extension OSInfo {
    /// Creates an OSInfo instance with current OS information
    @MainActor
    static func current() -> OSInfo {
        OSInfo(
            name: UIDevice.current.systemName.lowercased(),
            version: UIDevice.current.systemVersion,
            locale: bcp47Locale(Locale.current.identifier),
            timezone: TimeZone.current.identifier
        )
    }

    /// Converts an Apple locale identifier to BCP-47 format (e.g. "cs_CZ" → "cs-CZ")
    static func bcp47Locale(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-")
    }
}
