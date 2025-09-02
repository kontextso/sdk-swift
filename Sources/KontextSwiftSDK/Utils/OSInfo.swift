//
//  OSInfo.swift
//  KontextSwiftSDK
//

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
        OSInfo(
            name:  UIDevice.current.systemName.lowercased(),
            version: UIDevice.current.systemVersion,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier
        )
    }
}

