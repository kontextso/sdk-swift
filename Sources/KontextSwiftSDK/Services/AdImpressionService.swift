import AdAttributionKit
import StoreKit

// https://dev.to/arshtechpro/wwdc-adattributionkit-explained-building-on-skadnetworks-foundation-fl3

@available(iOS 17.4, *)
final actor AdAttributionImpressionService: AdImpressionServicing {
    private var impressions: [String: AppImpression] = [:]

    private var defaultEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    func onClickImpression(bidId: String) async {
        // https://developer.apple.com/documentation/adattributionkit/appimpression
        // * Needs UIEventAttributionView placed over view
        // * The handleTap() method must be called within 15 minutes of AppImpression initialisation.
        let attributes = AdAttributes(
            advertisedItemIdentifier: "?",
            publisherItemIdentifier: "?",
            sourceIdentifier: "?"
        )
        let impression = await createAppImpression(attributes)
        try? await impression?.handleTap()

        // When should impression be removed? keep impression here or in AdsProviderActor?
    }

    func onViewStartImpression(bidId: String) async {
        guard let impression = impressions[bidId] else {
            return
        }

        try? await impression.beginView()
    }

    func onViewStartEndImpression(bidId: String) async {
        guard let impression = impressions[bidId] else {
            return
        }

        try? await impression.endView()
    }
}

@available(iOS 17.4, *)
private extension AdAttributionImpressionService {
    func createAppImpression(_ adAttributes: AdAttributes) async -> AppImpression? {
        do {
            let jsonData = try defaultEncoder.encode(adAttributes)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return try await AppImpression(compactJWS: jsonString)
            }
        } catch {
            // TODO: Error
        }

        return nil
    }
}

// MARK: Ad Attributes
@available(iOS 17.4, *)
private extension AdAttributionImpressionService {
    struct AdAttributes: Encodable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case advertisedItemIdentifier = "advertised-item-identifier"
            case publisherItemIdentifier = "publisher-item-identifier"
            case sourceIdentifier = "source-identifier"
        }

        let advertisedItemIdentifier: String
        let publisherItemIdentifier: String
        let sourceIdentifier: String
    }
}
