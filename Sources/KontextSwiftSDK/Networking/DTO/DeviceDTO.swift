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
    
    init(
        os: String,
        systemVersion: String,
        model: String,
        brand: String,
        deviceType: String,
        appBundleId: String,
        appVersion: String,
        appStoreUrl: String?,
        soundOn: Bool,
        additionalInfo: [String : String]
    ) {
        self.os = os
        self.systemVersion = systemVersion
        self.model = model
        self.brand = brand
        self.deviceType = deviceType
        self.appBundleId = appBundleId
        self.appVersion = appVersion
        self.appStoreUrl = appStoreUrl
        self.soundOn = soundOn
        self.additionalInfo = additionalInfo
    }
    
    init(from model: Device) {
        self.init(
            os: model.os,
            systemVersion: model.systemVersion,
            model: model.model,
            brand: model.brand,
            deviceType: model.deviceType,
            appBundleId: model.appBundleId,
            appVersion: model.appVersion,
            appStoreUrl: model.appStoreUrl,
            soundOn: model.soundOn,
            additionalInfo: model.additionalInfo
        )
    }
}
