//
//  AppInfo.swift
//  KontextSwiftSDK
//


final class AppInfo  {
    private static var bundle: Bundle { Bundle.main }

    static var bundleID: String {
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

    static var storeURL: String {
       "https://apps.apple.com/app/id\(Bundle.main.bundleIdentifier)")
    }

    static let platform = "ios"

    func appInstallTime() -> Double? {
        // Get path to the app's Documents directory
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
               let creationDate = attributes[.creationDate] as? Date {
                return creationDate?.timeIntervalSince1970
            }
        }
        return nil
    }

    func appUpdateTime() -> Double? {
        let bundleURL = Bundle.main.bundleURL
        if let attributes = try? FileManager.default.attributesOfItem(atPath: bundleURL.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            return modificationDate?.timeIntervalSince1970
        }
        return nil
    }

    func appStartTime() -> Double {
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        return now.addingTimeInterval(-uptime).timeIntervalSince1970
    }
}

extension AppInfo {
    var asDTO: AppDTO {
        AppDTO(
            bundleId: Self.bundleID,
            version: Self.version,
            storeUrl: Self.storeURL,
            firstInstallTime: appInstallTime() ?? 0,
            lastUpdateTime: appUpdateTime() ?? 0,
            startTime: appStartTime()
        )
    }
}
