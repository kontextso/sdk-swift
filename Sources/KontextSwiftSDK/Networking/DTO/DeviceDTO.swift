//
//  DeviceDTO.swift
//  KontextSwiftSDK
//

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
        additionalInfo = model.additionalInfo
    }
}
