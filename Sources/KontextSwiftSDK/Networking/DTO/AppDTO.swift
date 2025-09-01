//
//  AppDTO.swift
//  KontextSwiftSDK
//

/// A data transfer object that contains application-related information.
struct AppDTO: Encodable {
    /// The bundle identifier of the application (e.g. com.example.app)
    let bundleId: String?
    /// The version of the application (e.g. 20.9.1)
    let version: String
    /// App store deeplink URL
    let storeUrl: String?
    /// First installation time as a timestamp
    let firstInstallTime: Double?
    /// Last update time as a timestamp
    let lastUpdateTime: Double?
    /// Current process start time as a timestamp
    let startTime: Double?

    
    /// Initializes a new instance of `AppDTO`.
    init() {
        bundleId = AppInfo.bundleId
        version = AppInfo.version
        storeUrl = AppInfo.storeUrl
        firstInstallTime = AppInfo.installTime
        lastUpdateTime = AppInfo.updateTime
        startTime = AppInfo.startTime
    }
}
