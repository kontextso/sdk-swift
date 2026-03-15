import Foundation

/// Current application metadata
struct AppInfo {
    let bundleId: String?
    let version: String
    let storeUrl: String?
    let installTime: Int64?
    let updateTime: Int64?
    let startTime: Int64
}

extension AppInfo {
    /// Creates an AppInfo instance with current app information
    static func current() -> AppInfo {
        let bundle = Bundle.main
        return AppInfo(
            bundleId: bundle.bundleIdentifier,
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
            storeUrl: nil,
            installTime: installTime,
            updateTime: updateTime,
            startTime: startTime
        )
    }
}

private extension AppInfo {
    static var installTime: Int64? {
        // Approximated as the creation date of the app's documents directory
        if let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
               let creationDate = attributes[.creationDate] as? Date {
                return Int64(creationDate.timeIntervalSince1970 * 1000)
            }
        }
        return nil
    }

    static var updateTime: Int64? {
        // Approximated as the last modification date of the app bundle
        let bundleURL = Bundle.main.bundleURL
        if let attributes = try? FileManager.default.attributesOfItem(atPath: bundleURL.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            return Int64(modificationDate.timeIntervalSince1970 * 1000)
        }
        return nil
    }

    static var startTime: Int64 {
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        return Int64(now.addingTimeInterval(-uptime).timeIntervalSince1970 * 1000)
    }
}
