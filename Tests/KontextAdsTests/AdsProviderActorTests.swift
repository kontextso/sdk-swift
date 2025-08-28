import Testing
@testable import KontextSwiftSDK

// MARK: - Tests

struct AdsProviderActorTests {
    @Test
    func testInitaillyDisabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: true,
            adsServerAPI: adsServerAPI,
            sharedStorage: SharedStorage()
        )

        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testSetDisabedSet() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            sharedStorage: SharedStorage()
        )

        await provider.setDisabled(true)
        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testInitallyEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            sharedStorage: SharedStorage()
        )

        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }

    @Test
    func testSetEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: true,
            adsServerAPI: adsServerAPI,
            sharedStorage: SharedStorage()
        )

        await provider.setDisabled(false)
        try await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }
}
