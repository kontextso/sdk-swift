//
//  AdsProviderDelegate.swift
//  KontextSwiftSDK
//

import UIKit

public protocol AdsProviderDelegate: class {

    func adsProvider(didChangeAvailableAdsTo ads: [Advertisment])

    func adsProvider(didUpdateHeightForAd ad: Advertisment)
}
