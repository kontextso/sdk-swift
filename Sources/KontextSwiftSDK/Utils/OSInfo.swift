//
//  OSInfo.swift
//  KontextSwiftSDK
//

import UIKit

public class OSInfo: Encodable {
    /// "android" | "ios" | "web" | "windows" | ...
    static var name: String {
        UIDevice.current.systemName
    }
    /// "16.5"
    static var version: String {
        UIDevice.current.systemVersion
    }
    /// BCP-47, e.g. "cs-CZ"
    static var locale: String {
        Locale.current.identifier
    }
    /// IANA, e.g. "Europe/Prague"
    static var timezone: String {
        TimeZone.current.identifier
    }
}

