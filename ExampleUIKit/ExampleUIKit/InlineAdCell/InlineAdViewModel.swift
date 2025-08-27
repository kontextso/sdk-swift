//
//  InlineAdViewModel.swift
//  ExampleUIKit
//

import KontextSwiftSDK

final class InlineAdViewModel {
    let adsProvider: AdsProvider
    let ad: Advertisment

    init(
        adsProvider: AdsProvider,
        ad: Advertisment
    ) {
        self.adsProvider = adsProvider
        self.ad = ad
    }
}
