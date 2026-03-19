import UIKit

/// SDK identification and version information
struct SDKInfo {
    /// Default ad server URL
    static let defaultAdServerURL: URL = URL(string: "https://server.megabrain.co")!
    /// SDK name identifier
    static let sdkName = "sdk-swift"
    /// Current SDK version in Major.Minor.Patch format
    static let sdkVersion = "2.0.4"

    /// Name of the SDK's bundle, should be sdk-swift
    let name: String
    /// Version of the SDK in Major.Minor.Patch format, e.g. 1.0.0
    let version: String
    /// Platform name in lowercase, e.g. "ios"
    let platform: String
}

extension SDKInfo {
    /// Creates a SDKInfo instance with current SDK information
    @MainActor
    static func current() -> SDKInfo {
        SDKInfo(
            name: Self.sdkName,
            version: Self.sdkVersion,
            platform: UIDevice.current.systemName.lowercased()
        )
    }
}
