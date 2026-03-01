import Foundation
import StoreKit

protocol SKAdNetworkManaging: Sendable {
    func initImpression(_ skan: Skan) async -> Bool
    func startImpression() async
    func endImpression() async
    func dispose() async
}

actor DefaultSKAdNetworkManager: SKAdNetworkManaging {
    static let shared = DefaultSKAdNetworkManager()

    func initImpression(_ skan: Skan) async -> Bool {
        await SKAdNetworkManager.shared.initImpression(skan)
    }

    func startImpression() async {
        await SKAdNetworkManager.shared.startImpression()
    }

    func endImpression() async {
        await SKAdNetworkManager.shared.endImpression()
    }

    func dispose() async {
        await SKAdNetworkManager.shared.dispose()
    }
}

@MainActor
final class SKAdNetworkManager: SKAdNetworkManaging, @unchecked Sendable {
    static let shared = SKAdNetworkManager()

    private var skImpressionBox: Any?
    private var isStarted = false

    private init() {}

    @available(iOS 14.5, *)
    private var skImpression: SKAdImpression? {
        get { skImpressionBox as? SKAdImpression }
        set { skImpressionBox = newValue }
    }

    func initImpression(_ skan: Skan) async -> Bool {
        guard #available(iOS 14.5, *) else {
            return false
        }

        func num(_ raw: String?) -> NSNumber? {
            guard let raw else {
                return nil
            }
            return num(raw as Any)
        }

        func num(_ raw: Any?) -> NSNumber? {
            switch raw {
            case let number as NSNumber:
                return number
            case let int as Int:
                return NSNumber(value: int)
            case let double as Double:
                guard double == double.rounded() else {
                    return nil
                }
                return NSNumber(value: Int(double))
            case let string as String:
                guard let int = Int(string) else {
                    return nil
                }
                return NSNumber(value: int)
            default:
                return nil
            }
        }

        func isBlank(_ value: String?) -> Bool {
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        }

        let version = skan.version
        let networkId = skan.network
        let itunesItem = num(skan.itunesItem)
        let sourceApp = num(skan.sourceApp) ?? NSNumber(value: 0)
        let campaign = num(skan.campaign)
        let sourceIdentifier = num(skan.sourceIdentifier)
        let nonce = skan.nonce
        let timestamp = num(skan.timestamp)
        let signature = skan.signature

        let hasFidelities = !(skan.fidelities?.isEmpty ?? true)

        guard
            !isBlank(version),
            !isBlank(networkId),
            itunesItem != nil
        else {
            return false
        }

        if !hasFidelities {
            guard
                !isBlank(nonce),
                timestamp != nil,
                !isBlank(signature)
            else {
                return false
            }
        }

        let previousImpression = isStarted ? skImpression : nil
        isStarted = false

        if #available(iOS 16.0, *) {
            let impression = SKAdImpression(
                sourceAppStoreItemIdentifier: sourceApp,
                advertisedAppStoreItemIdentifier: itunesItem!,
                adNetworkIdentifier: networkId,
                adCampaignIdentifier: campaign ?? NSNumber(value: 0),
                adImpressionIdentifier: nonce ?? "",
                timestamp: timestamp ?? NSNumber(value: 0),
                signature: signature ?? "",
                version: version
            )

            if #available(iOS 16.1, *) {
                if let sourceIdentifier {
                    impression.sourceIdentifier = sourceIdentifier
                }
            }

            if hasFidelities, let fidelities = skan.fidelities {
                parseFidelities(fidelities, into: impression)
            }

            skImpression = impression
        } else {
            let impression = SKAdImpression()
            impression.sourceAppStoreItemIdentifier = sourceApp
            impression.advertisedAppStoreItemIdentifier = itunesItem!
            impression.adNetworkIdentifier = networkId
            impression.adCampaignIdentifier = campaign ?? NSNumber(value: 0)
            impression.adImpressionIdentifier = nonce ?? ""
            impression.timestamp = timestamp ?? NSNumber(value: 0)
            impression.signature = signature ?? ""
            impression.version = version

            if hasFidelities, let fidelities = skan.fidelities {
                parseFidelities(fidelities, into: impression)
            }

            skImpression = impression
        }

        if let previousImpression {
            _ = await endImpression(previousImpression)
        }

        return true
    }

    func startImpression() async {
        guard #available(iOS 14.5, *) else {
            return
        }
        guard let impression = skImpression, !isStarted else {
            return
        }

        isStarted = true
        let didStart = await startImpression(impression)
        if !didStart {
            isStarted = false
        }
    }

    func endImpression() async {
        guard #available(iOS 14.5, *) else {
            return
        }
        guard let impression = skImpression, isStarted else {
            return
        }

        isStarted = false
        let didEnd = await endImpression(impression)
        if !didEnd {
            isStarted = true
        }
    }

    func dispose() async {
        guard #available(iOS 14.5, *) else {
            skImpressionBox = nil
            isStarted = false
            return
        }

        if isStarted, let impression = skImpression {
            isStarted = false
            _ = await endImpression(impression)
        } else {
            isStarted = false
        }

        skImpressionBox = nil
    }
}

private extension SKAdNetworkManager {
    @available(iOS 14.5, *)
    func startImpression(_ impression: SKAdImpression) async -> Bool {
        await withCheckedContinuation { continuation in
            SKAdNetwork.startImpression(impression) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    @available(iOS 14.5, *)
    func endImpression(_ impression: SKAdImpression) async -> Bool {
        await withCheckedContinuation { continuation in
            SKAdNetwork.endImpression(impression) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    @available(iOS 14.5, *)
    func parseFidelities(_ fidelities: [AttributionFidelity], into impression: SKAdImpression) {
        guard let f0 = fidelities.first(where: { $0.fidelity == 0 }) else { return }
        if impression.adImpressionIdentifier.isEmpty {
            impression.adImpressionIdentifier = f0.nonce
        }
        if impression.timestamp == NSNumber(value: 0), let ts = Int(f0.timestamp) {
            impression.timestamp = NSNumber(value: ts)
        }
        if impression.signature.isEmpty {
            impression.signature = f0.signature
        }
    }
}
