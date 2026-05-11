import Foundation
@testable import KontextSwiftSDK
import Testing

/// Default-value tests for the public `*Options` types.
struct OptionsTests {

    @Test func sessionOptionsDefaults() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv"
        )

        #expect(options.publisherToken == "tok")
        #expect(options.userId == "user")
        #expect(options.conversationId == "conv")
        // enabledPlacementCodes / adServerUrl are publisher-input
        // optionals — defaults fire later inside resolveConfig (see
        // ConfigTests.resolveConfigAppliesDefaults).
        #expect(options.enabledPlacementCodes == nil)
        #expect(options.adServerUrl == nil)
        #expect(options.character == nil)
        #expect(options.requestTrackingAuthorization == true)
        #expect(options.onEvent == nil)
    }

    @Test func addMessageOptionsDefaults() {
        let options = AddMessageOptions()
        #expect(!options.trackOnly)
    }

    @Test func adOptionsDefaults() {
        let options = AdOptions()
        #expect(options.code == "inlineAd")
        #expect(options.theme == nil)
    }
}
