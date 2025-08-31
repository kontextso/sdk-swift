import Foundation

final class SDKInfo  {
    private static var bundle: Bundle { Bundle(for: SDKInfo.self) }
    
    static let defaultAdServerURL: URL = URL(string: "https://server.megabrain.co")!
    
    /// Name of the SDK's bundle, should be sdk-swift
    static var name: String {
        Self.bundle
            .object(forInfoDictionaryKey: "CFBundleName") as? String ?? "sdk-swift"
    }
    
    /// Version of the SDK in Major.Minor.Patch format, e.g. 1.0.0
    static var version: String {
        Self.bundle
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static let platform = "ios"
}
