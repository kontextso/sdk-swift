import Foundation
import StoreKit

/// Data passed to the SKOverlay StoreKit component.
struct SKOverlayParams {
    let appStoreId: String
    let position: SKOverlay.Position
    let dismissible: Bool
}
