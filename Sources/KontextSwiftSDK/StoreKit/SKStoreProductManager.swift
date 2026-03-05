import Foundation
import OSLog
import StoreKit
import UIKit

@MainActor
final class SKStoreProductManager: NSObject, SKStoreProductPresenting {
    static let shared = SKStoreProductManager()

    private override init() {
        super.init()
    }

    private weak var presentedViewController: SKStoreProductViewController?
    private var pendingPresentContinuation: CheckedContinuation<Bool, Never>?
    private var pendingDismissContinuation: CheckedContinuation<Bool, Never>?

    func present(skan: Skan) async -> Bool {
        let trimmedItunesItem = skan.itunesItem.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedItunesItem.isEmpty else {
            os_log(.error, "[SKStoreProduct]: itunesItem cannot be empty")
            return false
        }

        guard let itemId = Int(trimmedItunesItem) else {
            os_log(.error, "[SKStoreProduct]: itunesItem must be a valid integer string")
            return false
        }

        guard pendingPresentContinuation == nil, pendingDismissContinuation == nil else {
            os_log(.error, "[SKStoreProduct]: Another operation is already in progress")
            return false
        }

        if presentedViewController != nil {
            _ = await dismiss()
        }

        guard presentedViewController == nil else {
            os_log(.error, "[SKStoreProduct]: Failed to dismiss existing controller before presenting a new one")
            return false
        }

        guard pendingPresentContinuation == nil, pendingDismissContinuation == nil else {
            os_log(.error, "[SKStoreProduct]: Unable to present while another operation is in progress")
            return false
        }

        let viewController = SKStoreProductViewController()
        viewController.delegate = self

        var params: [String: Any] = [
            SKStoreProductParameterITunesItemIdentifier: NSNumber(value: itemId)
        ]
        Self.applySkanParams(skan, into: &params)

        return await withCheckedContinuation { continuation in
            pendingPresentContinuation = continuation

            viewController.loadProduct(withParameters: params) { [weak self] loaded, error in
                Task { @MainActor in
                    guard let self else {
                        continuation.resume(returning: false)
                        return
                    }

                    guard loaded else {
                        os_log(
                            .error,
                            "[SKStoreProduct]: Failed to load product: \(error?.localizedDescription ?? "unknown error")"
                        )
                        self.completePresent(false)
                        return
                    }

                    guard let topController = self.topViewController() else {
                        os_log(.error, "[SKStoreProduct]: No top view controller available")
                        self.completePresent(false)
                        return
                    }

                    topController.present(viewController, animated: true) { [weak self] in
                        guard let self else {
                            return
                        }
                        self.presentedViewController = viewController
                        self.completePresent(true)
                    }
                }
            }
        }
    }

    func dismiss() async -> Bool {
        guard pendingDismissContinuation == nil else {
            os_log(.error, "[SKStoreProduct]: Dismiss operation already in progress")
            return false
        }

        guard pendingPresentContinuation == nil else {
            os_log(.error, "[SKStoreProduct]: Cannot dismiss while present is in progress")
            return false
        }

        let targetViewController: SKStoreProductViewController?
        if let presentedViewController {
            targetViewController = presentedViewController
        } else if let top = topViewController() as? SKStoreProductViewController {
            targetViewController = top
        } else {
            targetViewController = nil
        }

        guard let targetViewController else {
            return false
        }

        return await withCheckedContinuation { continuation in
            pendingDismissContinuation = continuation
            targetViewController.dismiss(animated: true) { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }
                self.presentedViewController = nil
                self.completeDismiss(true)
            }
        }
    }
}

extension SKStoreProductManager: @unchecked Sendable {}

@MainActor
extension SKStoreProductManager: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true) { [weak self] in
            self?.presentedViewController = nil
        }
    }
}

private extension SKStoreProductManager {
    static func fidelity1Values(
        from skan: Skan
    ) -> (nonce: UUID, timestamp: String, signature: String)? {
        guard let fidelities = skan.fidelities,
              let f1 = fidelities.first(where: { $0.fidelity == 1 }),
              !f1.nonce.isEmpty,
              let nonce = UUID(uuidString: f1.nonce),
              !f1.timestamp.isEmpty,
              !f1.signature.isEmpty else {
            return nil
        }

        return (
            nonce: nonce,
            timestamp: f1.timestamp,
            signature: f1.signature
        )
    }

    static func applySkanParams(_ skan: Skan, into params: inout [String: Any]) {
        guard #available(iOS 14.0, *) else {
            return
        }

        guard
            !skan.version.isEmpty,
            !skan.network.isEmpty,
            let f1 = fidelity1Values(from: skan)
        else {
            return
        }

        let sourceAppInt = Int(skan.sourceApp) ?? 0
        let campaignInt = skan.campaign.flatMap { Int($0) } ?? 0
        let timestampInt = Int(f1.timestamp) ?? 0

        params[SKStoreProductParameterAdNetworkVersion] = skan.version
        params[SKStoreProductParameterAdNetworkIdentifier] = skan.network
        params[SKStoreProductParameterAdNetworkSourceAppStoreIdentifier] = NSNumber(value: sourceAppInt)
        params[SKStoreProductParameterAdNetworkCampaignIdentifier] = NSNumber(value: campaignInt)
        params[SKStoreProductParameterAdNetworkTimestamp] = NSNumber(value: timestampInt)
        params[SKStoreProductParameterAdNetworkAttributionSignature] = f1.signature
        params[SKStoreProductParameterAdNetworkNonce] = f1.nonce

        if #available(iOS 16.1, *),
           let sourceIdentifier = skan.sourceIdentifier,
           let sourceIdentifierInt = Int(sourceIdentifier) {
            params[SKStoreProductParameterAdNetworkSourceIdentifier] = NSNumber(value: sourceIdentifierInt)
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

    func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let seedController: UIViewController? = base ?? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first {
                    $0.activationState == .foregroundActive ||
                    $0.activationState == .foregroundInactive
                }?
                .windows
                .first(where: \.isKeyWindow)?
                .rootViewController
        }()

        guard let seedController else {
            return nil
        }

        if let navigationController = seedController as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }

        if let tabBarController = seedController as? UITabBarController {
            return topViewController(base: tabBarController.selectedViewController)
        }

        if let presentedViewController = seedController.presentedViewController {
            return topViewController(base: presentedViewController)
        }

        return seedController
    }
}
