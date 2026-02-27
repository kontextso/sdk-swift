import Combine
import Foundation
import OSLog
import UIKit

@MainActor
final class InlineAdViewModel: ObservableObject {
    @Published var ad: Advertisement
    private var disposedAdIds: Set<UUID> = []

    init(ad: Advertisement) {
        self.ad = ad
    }

    func replaceAd(_ newAd: Advertisement) {
        if newAd.id != ad.id {
            disposeAttributionIfNeeded(for: ad)
        }
        ad = newAd
    }

    func disposeCurrentAttributionIfNeeded() {
        disposeAttributionIfNeeded(for: ad)
    }
}

private extension InlineAdViewModel {
    func disposeAttributionIfNeeded(for ad: Advertisement) {
        let isFirstDispose = disposedAdIds.insert(ad.id).inserted
        guard isFirstDispose else {
            return
        }

        ad.webViewData.onDispose()
    }
}
