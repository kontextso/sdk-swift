//
//  Untitled.swift
//  KontextSwiftSDK
//

struct OSDTO: Encodable {
    /// "android" | "ios" | "web" | "windows" | ...
    let name: String
    /// "16.5"
    let version: String
    /// BCP-47, e.g. "cs-CZ"
    let locale: String
    /// IANA, e.g. "Europe/Prague"
    let timezone: String

    init(from model: OSInfo) {
        name = model.name
        version = model.version
        locale = model.locale
        timezone = model.timezone
    }
};

