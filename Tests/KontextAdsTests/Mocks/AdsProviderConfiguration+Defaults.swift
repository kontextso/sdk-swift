import Foundation
@testable import KontextSwiftSDK

extension AdsProviderConfiguration {
    static var minimal: AdsProviderConfiguration {
        AdsProviderConfiguration(
            publisherToken: "testPublisherToken",
            userId: "testUserId",
            conversationId: "testConversationId",
            enabledPlacementCodes: ["testPlacementCode"],
            character: nil,
            variantId: nil,
            advertisingId: nil,
            vendorId: nil,
            adServerUrl: URL(string: "https://example.com"),
            otherParams: [:]
        )
    }
}
