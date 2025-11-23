import UIKit

final class OSInfo: Sendable {
    /// "android" | "ios" | "web" | "windows" | ...
    let name: String
    /// "16.5"
    let version: String
    /// BCP-47, e.g. "cs-CZ"
    let locale: String
    /// IANA, e.g. "Europe/Prague"
    let timezone: String

    init(
        name: String,
        version: String,
        locale: String,
        timezone: String
    ) {
        self.name = name
        self.version = version
        self.locale = locale
        self.timezone = timezone
    }

    @MainActor
    static func current() -> OSInfo {
        let localeObj = Locale.current
        let language = localeObj.language.languageCode?.identifier
        let region = localeObj.language.region?.identifier

        let bcp47locale = [language, region].compactMap { $0 }.joined(separator: "-")
        
        let fallback = Locale.current
            .identifier
            .replacingOccurrences(of: "_", with: "-")
        
        let finalLocale = bcp47locale.isEmpty ? fallback : bcp47locale
        
        return OSInfo(
            name:  UIDevice.current.systemName.lowercased(),
            version: UIDevice.current.systemVersion,
            locale: finalLocale,
            timezone: TimeZone.current.identifier
        )
    }
}

