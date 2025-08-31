//
//  AppDTO.swift
//  KontextSwiftSDK
//

struct AppDTO: Encodable {
    let bundleId: String          // e.g. com.example.app
    let version: String           // e.g. 20.9.1
    let storeUrl: String?         // app store deeplink
    let firstInstallTime: Double  // first installation time
    let lastUpdateTime: Double    // last update time
    let startTime: Double         // current process start time

    init() {
        bundleId = AppInfo.bundleId
        version = AppInfo.version
        storeUrl = AppInfo.storeUrl
        firstInstallTime = AppInfo.firstInstallTime
        lastUpdateTime = AppInfo.lastUpdateTime
        startTime = AppInfo.startTime
    }
}
