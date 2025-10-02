import Testing
@testable import KontextSwiftSDK

// MARK: - Tests
struct AdsProviderActorTests {
    @Test
    func testInitiallyDisabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: true,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener()
        )

        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testSetDisabledSet() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener()
        )

        await provider.setDisabled(true)
        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == false, "Preload should not be called when disabled")
    }

    @Test
    func testInitiallyEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener()
        )

        await provider.setMessages(messages: AdsMessage.variation1)
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
            urlOpener: MockURLOpener()
        )

        await provider.setDisabled(false)
        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }

    @Test
    func testAdNoFillSent() async throws {
        let adsServerAPI = MockAdsServerAPI(.adNotAvailable)
        let delegate = MockAdsProviderActingDelegate()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener()
        )
        await provider.setDelegate(delegate: delegate)
        await provider.setMessages(messages: AdsMessage.variation1)

        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
        if case .noFill(let data) = delegate.lastEvent {
            #expect(data.messageId == "3")
        } else {
            #expect(Bool(false), "Expected ad.no-fill event")
        }
    }
}
