//
//  InlineAdViewModel.swift
//  ExampleUIKit
//

import KontextSwiftSDK

class InlineAdViewModel {
    let adsProvider: AdsProvider
    let code: String
    let messageId: String
    let otherParams: [String: String]

    init(adsProvider: AdsProvider, code: String, messageId: String, otherParams: [String : String]) {
        self.adsProvider = adsProvider
        self.code = code
        self.messageId = messageId
        self.otherParams = otherParams
    }
}
