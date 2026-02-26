import Foundation
import OSLog
import StoreKit
import UIKit

@MainActor
final class SKOverlayManager: NSObject, SKOverlayPresenting {
    static let shared = SKOverlayManager()

    private override init() {
        super.init()
    }

    private var overlay: SKOverlay?
    private var pendingPresentContinuation: CheckedContinuation<Bool, Never>?
    private var pendingDismissContinuation: CheckedContinuation<Bool, Never>?

    func present(
        appStoreId: String,
        position: SKOverlayDisplayPosition,
        dismissible: Bool
    ) async -> Bool {
        guard !appStoreId.isEmpty else {
            os_log(.error, "[SKOverlay]: appStoreId cannot be empty")
            return false
        }

        guard pendingPresentContinuation == nil, pendingDismissContinuation == nil else {
            os_log(.error, "[SKOverlay]: Another operation is already in progress")
            return false
        }

        if overlay != nil {
            _ = await dismiss()
            guard overlay == nil else {
                os_log(.error, "[SKOverlay]: Failed to clear existing overlay before presenting a new one")
                return false
            }
        }

        guard pendingPresentContinuation == nil, pendingDismissContinuation == nil else {
            os_log(.error, "[SKOverlay]: Unable to present while another operation is in progress")
            return false
        }

        guard let scene = activeScene() else {
            os_log(.error, "[SKOverlay]: No active UIWindowScene available")
            return false
        }

        let config = SKOverlay.AppConfiguration(
            appIdentifier: appStoreId,
            position: position.asStoreKitPosition
        )
        config.userDismissible = dismissible

        let overlay = SKOverlay(configuration: config)
        overlay.delegate = self
        self.overlay = overlay

        return await withCheckedContinuation { continuation in
            pendingPresentContinuation = continuation
            overlay.present(in: scene)
        }
    }

    func dismiss() async -> Bool {
        guard pendingDismissContinuation == nil else {
            os_log(.error, "[SKOverlay]: Dismiss operation already in progress")
            return false
        }

        guard pendingPresentContinuation == nil else {
            os_log(.error, "[SKOverlay]: Cannot dismiss while present is in progress")
            return false
        }

        guard overlay != nil else {
            return false
        }

        guard let scene = activeScene() else {
            os_log(.error, "[SKOverlay]: No active UIWindowScene available for dismiss")
            return false
        }

        return await withCheckedContinuation { continuation in
            pendingDismissContinuation = continuation
            SKOverlay.dismiss(in: scene)
        }
    }
}

extension SKOverlayManager: @unchecked Sendable {}

private extension SKOverlayManager {
    func activeScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first {
                $0.activationState == .foregroundActive ||
                $0.activationState == .foregroundInactive
            }
    }

    func completePresent(_ success: Bool) {
        let continuation = pendingPresentContinuation
        pendingPresentContinuation = nil
        continuation?.resume(returning: success)
    }

    func completeDismiss(_ success: Bool) {
        let continuation = pendingDismissContinuation
        pendingDismissContinuation = nil
        continuation?.resume(returning: success)
    }
}

@MainActor
private extension SKOverlayDisplayPosition {
    var asStoreKitPosition: SKOverlay.Position {
        switch self {
        case .bottom:
            .bottom
        case .bottomRaised:
            .bottomRaised
        }
    }
}

@MainActor
extension SKOverlayManager: SKOverlayDelegate {
    func storeOverlayDidFailToLoad(_ overlay: SKOverlay, error: Error) {
        if let trackedOverlay = self.overlay, trackedOverlay === overlay {
            self.overlay = nil
        }
        os_log(.error, "[SKOverlay]: Failed to load with error: \(error.localizedDescription)")
        completePresent(false)
    }

    func storeOverlayDidFinishPresentation(
        _ overlay: SKOverlay,
        transitionContext: SKOverlay.TransitionContext
    ) {
        completePresent(true)
    }

    func storeOverlayDidFinishDismissal(
        _ overlay: SKOverlay,
        transitionContext: SKOverlay.TransitionContext
    ) {
        if let trackedOverlay = self.overlay, trackedOverlay === overlay {
            self.overlay = nil
        }
        completeDismiss(true)
    }
}
