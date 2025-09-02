//
//  SDKDTO.swift
//  KontextSwiftSDK
//

struct SDKDTO: Encodable {
    let name: String
    let version: String
    let platform: String

    init(from model: SDKInfo) {
        self.name = model.name
        self.version = model.version
        self.platform = model.lowercasedPlatform
    }
}
