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
            locale: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"),
            timezone: TimeZone.current.identifier
        )
    }
}
