//
//  AppInfo.swift
//  KontextSwiftSDK
//

import Foundation

final class AppInfo  {
    let bundleId: String?
    let version: String
    let storeUrl: String?
    let installTime: Double?
    let updateTime: Double?
    let startTime: Double

    init(
        bundleId: String?,
        version: String,
        storeUrl: String?,
        installTime: Double?,
        updateTime: Double?,
        startTime: Double
    ) {
        self.bundleId = bundleId
        self.version = version
        self.storeUrl = storeUrl
        self.installTime = installTime
        self.updateTime = updateTime
        self.startTime = startTime
    }

    static func current() -> AppInfo {
        // Prepare bundle
        let bundle = Bundle.main
        // Simple properties
        let bundleId = bundle.bundleIdentifier
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        // Store url
        let storeUrl: String? = if let bundleId {
            "https://apps.apple.com/app/id\(bundleId)"
        } else {
            nil
        }
        // More complex calcullations through static properties
        let installTime = Self.installTime
        let updateTime = Self.updateTime
        let startTime = Self.startTime

        return AppInfo(
            bundleId: bundleId,
            version: version,
            storeUrl: storeUrl,
            installTime: installTime,
            updateTime: updateTime,
            startTime: startTime
        )
    }

    // MARK: - More complex properties

    private static var installTime: Double? {
        // Get path to the app's Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
               let creationDate = attributes[.creationDate] as? Date {
                return creationDate.timeIntervalSince1970
            }
        }
        return nil
    }

    private static var updateTime: Double? {
        let bundleURL = Bundle.main.bundleURL
        if let attributes = try? FileManager.default.attributesOfItem(atPath: bundleURL.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate.timeIntervalSince1970
        }
        return nil
    }

    private static var startTime: Double {
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        return now.addingTimeInterval(-uptime).timeIntervalSince1970
    }
}
