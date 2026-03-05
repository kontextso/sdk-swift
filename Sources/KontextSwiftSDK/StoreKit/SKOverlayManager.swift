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
        skan: Skan,
        position: SKOverlayDisplayPosition,
        dismissible: Bool
    ) async -> Bool {
        guard #available(iOS 16.0, *) else {
            os_log(.error, "[SKOverlay]: SKOverlay requires iOS 16.0 or later")
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

        let trimmedItunesItem = skan.itunesItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedItunesItem.isEmpty else {
            os_log(.error, "[SKOverlay]: itunesItem cannot be empty")
            return false
        }

        let config = SKOverlay.AppConfiguration(
            appIdentifier: trimmedItunesItem,
            position: position.asStoreKitPosition
        )
        config.userDismissible = dismissible

        guard Self.applyImpression(skan, to: config) else {
            os_log(
                .error,
                "[SKOverlay]: Failed to apply SKAN impression (missing or invalid fidelity-1 data)"
            )
            return false
        }

        let overlay = SKOverlay(configuration: config)
        overlay.delegate = self
        self.overlay = overlay

        return await withCheckedContinuation { continuation in
            pendingPresentContinuation = continuation
            overlay.present(in: scene)
        }
    }

    func dismiss() async -> Bool {
        guard #available(iOS 16.0, *) else {
            return false
        }

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
    @available(iOS 16.0, *)
    static func fidelity1Values(
        from skan: Skan
    ) -> (nonce: String, timestamp: NSNumber, signature: String)? {
        guard let fidelities = skan.fidelities,
              let f1 = fidelities.first(where: { $0.fidelity == 1 }),
              !f1.nonce.isEmpty,
              !f1.signature.isEmpty else {
            return nil
        }

        let timestamp: NSNumber
        if let intTimestamp = Int(f1.timestamp) {
            timestamp = NSNumber(value: intTimestamp)
        } else {
            return nil
        }

        return (
            nonce: f1.nonce,
            timestamp: timestamp,
            signature: f1.signature
        )
    }

    static func applyImpression(
        _ skan: Skan,
        to config: SKOverlay.AppConfiguration
    ) -> Bool {
        guard #available(iOS 16.0, *) else {
            return false
        }

        guard
            !skan.version.isEmpty,
            !skan.network.isEmpty,
            let itunesItem = Int(skan.itunesItem),
            let f1 = fidelity1Values(from: skan)
        else {
            return false
        }

        let sourceAppInt = Int(skan.sourceApp) ?? 0
        let campaignInt = skan.campaign.flatMap { Int($0) } ?? 0

        let impression = SKAdImpression()
        impression.version = skan.version
        impression.adNetworkIdentifier = skan.network
        impression.advertisedAppStoreItemIdentifier = NSNumber(value: itunesItem)
        impression.sourceAppStoreItemIdentifier = NSNumber(value: sourceAppInt)
        impression.adCampaignIdentifier = NSNumber(value: campaignInt)
        impression.adImpressionIdentifier = f1.nonce
        impression.timestamp = f1.timestamp
        impression.signature = f1.signature

        if #available(iOS 16.1, *),
           let sourceIdentifier = skan.sourceIdentifier,
           let sourceIdentifierInt = Int(sourceIdentifier) {
            impression.sourceIdentifier = NSNumber(value: sourceIdentifierInt)
        }

        config.setAdImpression(impression)
        return true
    }

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
    @available(iOS 16.0, *)
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
