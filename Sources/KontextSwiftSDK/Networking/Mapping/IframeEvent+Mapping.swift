import Foundation
import StoreKit

extension IframeEvent.Position {
    func toModel() -> SKOverlay.Position {
        switch self {
        case .bottom: .bottom
        case .bottomRaised: .bottomRaised
        }
    }
}
