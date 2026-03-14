import Foundation

struct AppInfo {
    let name: String
    let bundleId: String?
    let version: String
    let storeUrl: String?
    let installTime: Int64?
    let updateTime: Int64?
    let startTime: Int64

    init(
        name: String,
        bundleId: String?,
        version: String,
        storeUrl: String?,
        installTime: Int64?,
        updateTime: Int64?,
        startTime: Int64    
    ) {
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.storeUrl = storeUrl
        self.installTime = installTime
        self.updateTime = updateTime
        self.startTime = startTime
    }
}

extension AppInfo {
    /// Creates an AppInfo instance with current app information
    static func current() -> AppInfo {
        let bundle = Bundle.main
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Unknown"
        let bundleId = bundle.bundleIdentifier
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let installTime = installTime
        let updateTime = updateTime
        let startTime = startTime

        return AppInfo(
            name: name,
            bundleId: bundleId,
            version: version,
            storeUrl: nil,
            installTime: installTime,
            updateTime: updateTime,
            startTime: startTime
        )
    }
}

private extension AppInfo {
    static var installTime: Int64? {
        // Determine install time as the first creation of the user documents folder.
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
        // Determine install time as the last modification of the user documents folder.
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
