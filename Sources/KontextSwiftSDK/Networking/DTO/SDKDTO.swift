//
//  SDKDTO.swift
//  KontextSwiftSDK
//

struct SDKDTO: Encodable {
    let name: String
    let version: String
    let platform: String

    init() {
        self.name = SDKInfo.name
        self.version = SDKInfo.version
        self.platform = SDKInfo.platform
    }
}
