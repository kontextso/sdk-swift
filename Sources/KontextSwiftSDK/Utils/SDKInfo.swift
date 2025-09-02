import Foundation
import UIKit

final class SDKInfo  {
    static let defaultAdServerURL: URL = URL(string: "https://server.megabrain.co")!

    /// Name of the SDK's bundle, should be sdk-swift
    let name: String
    /// Version of the SDK in Major.Minor.Patch format, e.g. 1.0.0
    let version: String
    ///  "iOS" | "Android" | "Web"
    let platform: String
    ///  "android" | "ios" | "web"
    let lowercasedPlatform: String

    init(
        name: String,
        version: String,
        platform: String,
        lowercasedPlatform: String
    ) {
        self.name = name
        self.version = version
        self.platform = platform
        self.lowercasedPlatform = lowercasedPlatform
    }

    static func current() -> SDKInfo {
        let bundle = Bundle(for: SDKInfo.self)
        let name = bundle
            .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "sdk-swift"
        let version = bundle
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let platform = UIDevice.current.systemName
        let lowercasedPlatform = platform.lowercased()

        return SDKInfo(
            name: name,
            version: version,
            platform: platform,
            lowercasedPlatform: lowercasedPlatform
        )
    }
}
