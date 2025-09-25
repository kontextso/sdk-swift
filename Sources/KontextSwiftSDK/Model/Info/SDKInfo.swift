import Foundation
import UIKit

struct SDKInfo  {
    static let defaultAdServerURL: URL = URL(string: "https://server.megabrain.co")!
    static let sdkName = "sdk-swift"
    static let sdkVersion = "1.1.4"

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
}

extension SDKInfo {
    @MainActor
    /// Creates a SDKInfo instance with current SDK information
    static func current() -> SDKInfo {
        final class _BundleToken {}
        let platform = UIDevice.current.systemName
        let lowercasedPlatform = platform.lowercased()

        return SDKInfo(
            name: Self.sdkName,
            version: Self.sdkVersion,
            platform: platform,
            lowercasedPlatform: lowercasedPlatform
        )
    }
}
