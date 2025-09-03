import Foundation

struct AppInfo  {
    let name: String
    let bundleId: String?
    let version: String
    let storeUrl: String?
    let installTime: Double?
    let updateTime: Double?
    let startTime: Double

    init(
        name: String,
        bundleId: String?,
        version: String,
        storeUrl: String?,
        installTime: Double?,
        updateTime: Double?,
        startTime: Double
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
    static var installTime: Double? {
        // Determine install time as the first creation of the user documents folder.
        if let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path),
               let creationDate = attributes[.creationDate] as? Date {
                return creationDate.timeIntervalSince1970
            }
        }
        return nil
    }

    static var updateTime: Double? {
        // Determine install time as the last modification of the user documents folder.
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
