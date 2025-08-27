//
//  InlineAdViewModel.swift
//  ExampleUIKit
//

import KontextSwiftSDK

final class InlineAdViewModel {
    let adsProvider: AdsProvider
    let ad: Advertisement

    init(
        adsProvider: AdsProvider,
        ad: Advertisement
    ) {
        self.adsProvider = adsProvider
        self.ad = ad
    }
}
