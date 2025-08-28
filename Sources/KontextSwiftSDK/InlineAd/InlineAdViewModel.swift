import Combine
import Foundation
import OSLog
import UIKit

@MainActor
final class InlineAdViewModel: ObservableObject {
    @Published var ad: Advertisement

    init(ad: Advertisement) {
        self.ad = ad
    }
}

