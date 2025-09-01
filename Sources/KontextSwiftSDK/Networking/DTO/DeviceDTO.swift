import Foundation

struct DeviceDTO: Encodable {
    let os: String
    let systemVersion: String
    let model: String
    let brand: String
    let deviceType: String
    let appBundleId: String
    let appVersion: String
    let appStoreUrl: String?
    let soundOn: Bool
    let locale: String
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let isDarkMode: Bool
    let additionalInfo: [String: String]

    init(from model: Device) {
        os = model.os
        systemVersion = model.systemVersion
        self.model = model.model
        brand = model.brand
        deviceType = model.deviceType
        appBundleId = model.appBundleId
        appVersion = model.appVersion
        appStoreUrl = model.appStoreUrl
        soundOn = model.soundOn
        locale = model.locale
        screenWidth = model.screenWidth
        screenHeight = model.screenHeight
        isDarkMode = model.isDarkMode
        additionalInfo = model.additionalInfo
    }
}
