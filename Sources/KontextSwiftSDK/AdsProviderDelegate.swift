//
//  AdsProviderDelegate.swift
//  KontextSwiftSDK
//

import UIKit

public protocol AdsProviderDelegate: class {
    func adsProvider(_ adsProvider: AdsProvider, didUpdateSizeOfAdAssociatedWith messageId: String)
}

extension UITableViewController: AdsProviderDelegate {
    public func adsProvider(_ adsProvider: AdsProvider, didUpdateSizeOfAdAssociatedWith messageId: String) {
        UIView.animate(withDuration: 0.3) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }
}

extension UICollectionViewController: AdsProviderDelegate {
    public func adsProvider(_ adsProvider: AdsProvider, didUpdateSizeOfAdAssociatedWith messageId: String) {
        self.collectionView.collectionViewLayout.invalidateLayout()
        self.collectionView.performBatchUpdates(nil, completion: nil)
    }
}

final class DefaultAdsProviderDelegate: AdsProviderDelegate {
    public func adsProvider(_ adsProvider: AdsProvider, didUpdateSizeOfAdAssociatedWith messageId: String) {
        // No-op
    }
}
