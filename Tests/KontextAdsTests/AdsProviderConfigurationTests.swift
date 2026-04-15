import Foundation
import Testing
@testable import KontextSwiftSDK

struct AdsProviderConfigurationTests {
    // MARK: - Required field pass-through

    @Test
    func requiredFieldsAreStoredVerbatim() {
        let config = AdsProviderConfiguration(
            publisherToken: "pub-tok",
            userId: "u-1",
            conversationId: "c-1",
            enabledPlacementCodes: ["inlineAd", "boxAd"]
        )

        #expect(config.publisherToken == "pub-tok")
        #expect(config.userId == "u-1")
        #expect(config.conversationId == "c-1")
        #expect(config.enabledPlacementCodes == ["inlineAd", "boxAd"])
    }

    // MARK: - Defaults

    @Test
    func adServerUrlFallsBackToDefaultWhenNil() {
        let config = makeMinimalConfig()
        #expect(config.adServerUrl == URL(string: "https://server.megabrain.co")!)
    }

    @Test
    func adServerUrlUsesExplicitValueWhenProvided() {
        let custom = URL(string: "https://custom.example.com")!
        let config = AdsProviderConfiguration(
            publisherToken: "t",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: [],
            adServerUrl: custom
        )
        #expect(config.adServerUrl == custom)
    }

    @Test
    func requestTrackingAuthorizationDefaultsToTrue() {
        #expect(makeMinimalConfig().requestTrackingAuthorization == true)
    }

    @Test
    func requestTrackingAuthorizationRespectsExplicitFalse() {
        let config = AdsProviderConfiguration(
            publisherToken: "t",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: [],
            requestTrackingAuthorization: false
        )
        #expect(config.requestTrackingAuthorization == false)
    }

    @Test
    func otherParamsDefaultsToEmptyDictionary() {
        #expect(makeMinimalConfig().otherParams.isEmpty)
    }

    @Test
    func optionalFieldsDefaultToNil() {
        let config = makeMinimalConfig()
        #expect(config.character == nil)
        #expect(config.variantId == nil)
        #expect(config.advertisingId == nil)
        #expect(config.vendorId == nil)
        #expect(config.regulatory == nil)
        #expect(config.userEmail == nil)
    }

    // MARK: - Optional field pass-through

    @Test
    func optionalFieldsArePassedThrough() {
        let character = Character(
            id: "char-1", name: "Max", avatarUrl: URL(string: "https://cdn/a.png"),
            isNsfw: false, greeting: "Hi", persona: "friendly", tags: ["fantasy"]
        )
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "CONSENT")

        let config = AdsProviderConfiguration(
            publisherToken: "t",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: ["x"],
            character: character,
            variantId: "v-42",
            advertisingId: "idfa-1",
            vendorId: "idfv-1",
            adServerUrl: URL(string: "https://ads.example.com"),
            regulatory: regulatory,
            otherParams: ["theme": "dark", "locale": "cs-CZ"],
            userEmail: "user@example.com",
            requestTrackingAuthorization: false
        )

        #expect(config.character?.id == "char-1")
        #expect(config.character?.name == "Max")
        #expect(config.variantId == "v-42")
        #expect(config.advertisingId == "idfa-1")
        #expect(config.vendorId == "idfv-1")
        #expect(config.regulatory?.gdpr == 1)
        #expect(config.regulatory?.gdprConsent == "CONSENT")
        #expect(config.otherParams == ["theme": "dark", "locale": "cs-CZ"])
        #expect(config.userEmail == "user@example.com")
        #expect(config.requestTrackingAuthorization == false)
    }

    // MARK: - Sendable

    @Test
    func configurationIsSafeToSendAcrossActors() async {
        let config = makeMinimalConfig()
        let publisherToken = await Task.detached { config.publisherToken }.value
        #expect(publisherToken == config.publisherToken)
    }

    // MARK: - Helpers

    private func makeMinimalConfig() -> AdsProviderConfiguration {
        AdsProviderConfiguration(
            publisherToken: "t",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: []
        )
    }
}
