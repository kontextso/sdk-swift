//
//  AppInfo.swift
//  KontextSwiftSDK
//

import Foundation

final class AppInfo  {
    private static var bundle: Bundle { Bundle.main }

    static var bundleId: String? {
        Self.bundle.bundleIdentifier
    }

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

    static var storeUrl: String? {
        guard let bundleIdentifier = Self.bundleId else { return nil }
        return "https://apps.apple.com/app/id\(bundleIdentifier)"
    }

    static let platform = "ios"

    static var installTime: Double? {
        // Get path to the app's Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
               let creationDate = attributes[.creationDate] as? Date {
                return creationDate.timeIntervalSince1970
            }
        }
        return nil
    }

    static var updateTime: Double? {
        let bundleURL = Bundle.main.bundleURL
        if let attributes = try? FileManager.default.attributesOfItem(atPath: bundleURL.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate.timeIntervalSince1970
        }
        return nil
    }

    static var startTime: Double {
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        return now.addingTimeInterval(-uptime).timeIntervalSince1970
    }
}
