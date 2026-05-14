import Foundation
@testable import KontextSwiftSDK
import Testing

struct ConfigTests {

    @Test func resolveConfigAppliesDefaults() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv"
        )
        let config = resolveConfig(options)

        #expect(config.publisherToken == "tok")
        #expect(config.userId == "user")
        #expect(config.conversationId == "conv")
        #expect(config.enabledPlacementCodes == ["inlineAd"])
        #expect(config.adServerUrl == URL(string: "https://server.megabrain.co"))
        #expect(config.character == nil)
        #expect(config.variantId == nil)
        #expect(config.regulatory == nil)
        #expect(config.userEmail == nil)
        #expect(config.advertisingId == nil)
        #expect(config.vendorId == nil)
        #expect(config.onEvent == nil)
        #expect(config.onDebugEvent == nil)
    }

    @Test func resolveConfigUsesProvidedValues() {
        let character = Character(
            id: "c1",
            name: "Bot",
            avatarUrl: URL(string: "https://example.com/bot.png")!,
            persona: "Friendly assistant"
        )
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "consent-string")
        let options = SessionOptions(
            publisherToken: "my-token",
            userId: "my-user",
            conversationId: "my-conv",
            enabledPlacementCodes: ["banner", "inlineAd"],
            character: character,
            variantId: "variant-a",
            regulatory: regulatory,
            userEmail: "test@example.com",
            adServerUrl: URL(string: "https://custom.server.com"),
            advertisingId: "ad-id",
            vendorId: "vendor-id"
        )
        let config = resolveConfig(options)

        #expect(config.publisherToken == "my-token")
        #expect(config.userId == "my-user")
        #expect(config.conversationId == "my-conv")
        #expect(config.enabledPlacementCodes == ["banner", "inlineAd"])
        #expect(config.adServerUrl == URL(string: "https://custom.server.com"))
        #expect(config.character?.id == "c1")
        #expect(config.character?.name == "Bot")
        #expect(config.character?.persona == "Friendly assistant")
        #expect(config.variantId == "variant-a")
        #expect(config.regulatory?.gdpr == 1)
        #expect(config.regulatory?.gdprConsent == "consent-string")
        #expect(config.userEmail == "test@example.com")
        #expect(config.advertisingId == "ad-id")
        #expect(config.vendorId == "vendor-id")
    }

    @Test func defaultAdServerUrl() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv"
        )
        let config = resolveConfig(options)
        #expect(config.adServerUrl == URL(string: "https://server.megabrain.co"))
    }

    @Test func defaultEnabledPlacementCodes() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv"
        )
        let config = resolveConfig(options)
        #expect(config.enabledPlacementCodes == ["inlineAd"])
    }

    @Test func emptyPlacementCodesDefaultsToInlineAd() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv",
            enabledPlacementCodes: []
        )
        let config = resolveConfig(options)
        #expect(config.enabledPlacementCodes == ["inlineAd"])
    }

    @Test func nilAdServerUrlDefaultsToProductionEndpoint() {
        // resolveConfig is the resolution boundary — when the publisher
        // omits adServerUrl, the default fires here (not at SessionOptions
        // construction). Mirrors sdk-js's pattern.
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv",
            adServerUrl: nil
        )
        let config = resolveConfig(options)
        #expect(config.adServerUrl == URL(string: "https://server.megabrain.co"))
    }

    @Test func requestTrackingAuthorizationDefaultsTrue() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv"
        )
        let config = resolveConfig(options)
        #expect(config.requestTrackingAuthorization == true)
    }

    @Test func requestTrackingAuthorizationCanBeFalse() {
        let options = SessionOptions(
            publisherToken: "tok",
            userId: "user",
            conversationId: "conv",
            requestTrackingAuthorization: false
        )
        let config = resolveConfig(options)
        #expect(config.requestTrackingAuthorization == false)
    }
}
