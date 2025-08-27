//
//  AdsProviderDelegate.swift
//  KontextSwiftSDK
//

import UIKit

public protocol AdsProviderDelegate: class {

    func adsProvider(_ adsProvider: AdsProvider, didChangeAvailableAdsTo ads: [Advertisment])

    func adsProvider(_ adsProvider: AdsProvider, didUpdateHeightForAd ad: Advertisment)
}
