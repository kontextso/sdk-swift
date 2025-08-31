//
//  Untitled.swift
//  KontextSwiftSDK
//

struct OSDTO: Encodable {
    let name: String        // "android" | "ios" | "web" | "windows" | ...
    let version: String     // "16.5"
    let locale: String      // BCP-47, e.g. "cs-CZ"
    let timezone: String   // IANA, e.g. "Europe/Prague"

    init(from model: Device) {
        name = model.os
        version = model.systemVersion
        locale = model.locale
        timezone = model.timezone
    }
};

