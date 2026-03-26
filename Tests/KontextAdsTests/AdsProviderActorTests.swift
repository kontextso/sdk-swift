import Testing
@testable import KontextSwiftSDK

@MainActor
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
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
        )

        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called even when disabled")
    }

    @Test
    func testSetDisabledSet() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
        )

        await provider.setDisabled(true)
        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called even when disabled")
    }

    @Test
    func testInitiallyEnabled() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
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
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
        )

        await provider.setDisabled(false)
        await provider.setMessages(messages: AdsMessage.variation1)
        #expect(adsServerAPI.preloadCalled == true, "Preload should be called when enabled")
    }

    @Test
    func testIFAPassedToPreload() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
        )

        await provider.setIFA(advertisingId: "test-idfa", vendorId: "test-idfv")
        await provider.setMessages(messages: AdsMessage.variation1)

        #expect(adsServerAPI.preloadAdvertisingId == "test-idfa")
        #expect(adsServerAPI.preloadVendorId == "test-idfv")
    }

    @Test
    func testNilIFAPassedToPreloadWhenNotSet() async throws {
        let adsServerAPI = MockAdsServerAPI()
        let provider = await AdsProviderActor(
            configuration: .minimal,
            sessionId: nil,
            isDisabled: false,
            adsServerAPI: adsServerAPI,
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
        )

        await provider.setMessages(messages: AdsMessage.variation1)

        #expect(adsServerAPI.preloadAdvertisingId == nil)
        #expect(adsServerAPI.preloadVendorId == nil)
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
            urlOpener: MockURLOpener(),
            skOverlayPresenter: MockSKOverlayPresenter(),
            skStoreProductPresenter: MockSKStoreProductPresenter()
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
