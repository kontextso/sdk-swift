import Testing
@testable import KontextSwiftSDK

// MARK: - Tests

struct AdsProviderActorTests {
    @Test
    func testInitiallyDisabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: true,
            adsServerAPI: adsServerAPI
        )

        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testSetDisabledSet() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI
        )

        await provider.setDisabled(true)
        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testInitiallyEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI
        )

        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }

    @Test
    func testSetEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: true,
            adsServerAPI: adsServerAPI
        )

        await provider.setDisabled(false)
        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }
}
