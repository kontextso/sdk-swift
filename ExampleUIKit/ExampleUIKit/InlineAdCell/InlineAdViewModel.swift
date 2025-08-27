//
//  InlineAdViewModel.swift
//  ExampleUIKit
//

import KontextSwiftSDK

final class InlineAdViewModel {
    let adsProvider: AdsProvider
    let ad: Ad

    init(
        adsProvider: AdsProvider,
        ad: Ad
    ) {
        self.adsProvider = adsProvider
        self.ad = ad
    }
}
