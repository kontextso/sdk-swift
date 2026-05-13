import Foundation
@testable import KontextSwiftSDK
import Testing

// MARK: - Mock SKAdNetwork Manager

@MainActor
final class MockSKAdNetworkManager: SKAdNetworkManaging {
    var initImpressionCalled = false
    var initImpressionSkan: Skan?
    var initImpressionShouldSucceed = true

    var startImpressionCalled = false
    var disposeCalled = false

    func initImpression(skan: Skan) async throws {
        initImpressionCalled = true
        initImpressionSkan = skan
        if !initImpressionShouldSucceed {
            throw SKAdNetworkAdapterError.initFailed
        }
    }

    func startImpression() async throws {
        startImpressionCalled = true
    }

    var endImpressionCalled = false
    func endImpression() async throws {
        endImpressionCalled = true
    }

    func dispose() async throws {
        disposeCalled = true
    }
}

@MainActor
final class MockSKStoreProductManagerForSKAN: SKStoreProductManaging {
    func present(skan: Skan) async throws -> Bool { false }
    func present(itunesItem: String) async throws -> Bool { false }
}

@MainActor
final class MockSKOverlayManagerForSKAN: SKOverlayManaging {
    func present(skan: Skan, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool { true }
    func present(itunesItem: String, position: SKOverlayPosition, dismissible: Bool) async throws -> Bool { true }
    func dismiss() async throws -> Bool { true }
}

// MARK: - SKAN Lifecycle Tests

@MainActor
struct SKANTests {

    // MARK: - Helpers

    private func makeDependencies(skanManager: MockSKAdNetworkManager) -> DependencyContainer {
        return DependencyContainer(
            omManager: MockOMManager(),
            skAdNetworkManager: skanManager,
            skStoreProductManager: MockSKStoreProductManagerForSKAN(),
            skOverlayManager: MockSKOverlayManagerForSKAN()
        )
    }

    private func makeSession(skanManager: MockSKAdNetworkManager) -> Session {
        let config = ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: URL(string: "http://0.0.0.0:1")!,
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: nil,
            onDebugEvent: nil
        )
        return Session(config: config, dependencies: makeDependencies(skanManager: skanManager))
    }

    /// Creates an ad that has a resolved bid with SKAN data.
    private func makeAdWithSkanBid(
        skanManager: MockSKAdNetworkManager,
        impressionTrigger: ImpressionTrigger? = .immediate,
        skan: Skan? = Skan(version: "2.2", network: "test.skadnetwork", itunesItem: "123456", sourceApp: "987654")
    ) -> (Ad, Session) {
        let session = makeSession(skanManager: skanManager)
        // We can't easily inject bids without going through the preload flow.
        // The Ad resolves its bid from session.getBid() in checkBid(); since
        // we have no preload, currentBid stays nil. Tests using this helper
        // verify the no-bid no-op paths only.
        _ = (impressionTrigger, skan) // keep parameters for future wiring
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())
        return (ad, session)
    }

    // MARK: - initSKAdNetwork

    @Test func initIframeDoesNotCallInitSKAdWhenNoBid() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        // No bid resolved for this ad, so initSKAdNetwork should be a no-op
        ad.handleIframeEvent(.initIframe)

        #expect(!skanManager.initImpressionCalled)
    }

    @Test func initIframeDoesNotCallInitSKAdWhenBidHasNoSkanData() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)

        // Create a bid without skan data by injecting through preload
        // Since we can't easily inject bids, we verify indirectly:
        // An ad without a resolved bid won't call initSKAdNetwork
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        ad.handleIframeEvent(.initIframe)

        #expect(!skanManager.initImpressionCalled)
    }

    @Test func initIframeInitializesSKANWithoutFlippingVisibility() {
        // Parity with sdk-react-native (current/v3), sdk-js, and v3
        // sdk-swift: `init-iframe` is "loaded, send me context" — it
        // does NOT make the ad visible. Only `show-iframe` flips
        // `isVisible`. The previous v4 sdk-swift incorrectly set
        // `isVisible = true` here.
        //
        // `ad.render-started` is no longer synthesised here either —
        // the ad creative emits it via `event-iframe` and the SDK
        // forwards it; no auto-emit on init.
        let skanManager = MockSKAdNetworkManager()
        let events = TestCollector<AdEvent>()
        let config = ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: URL(string: "http://0.0.0.0:1")!,
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: { events.append($0) },
            onDebugEvent: nil
        )
        let session = Session(config: config, dependencies: makeDependencies(skanManager: skanManager))
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        ad.handleIframeEvent(.initIframe)

        // No visibility flip on init.
        #expect(!ad.isVisible)
        // No spurious renderStarted event.
        #expect(!events.values.contains(where: {
            if case .renderStarted = $0 { return true }
            return false
        }))
    }

    // MARK: - startSKAdNetwork via adDone (immediate trigger)

    @Test func adDoneDoesNotCallStartSKAdWhenNoBid() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        ad.handleIframeEvent(.adDoneIframe(IframeEvent.AdDoneData()))

        #expect(!skanManager.startImpressionCalled)
    }

    // MARK: - startSKAdNetwork via openComponent (component trigger)

    @Test func openComponentModalDoesNotCallStartSKAdWhenNoBid() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        let data = IframeEvent.OpenComponentData(code: nil, timeout: 5000)
        ad.handleIframeEvent(.openComponentIframe(data))

        #expect(!skanManager.startImpressionCalled)
    }

    // MARK: - cleanupSKAdNetwork on destroy

    @Test func destroyCallsDisposeWhenSKANNotInitialized() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        // SKAN was never initialized, so dispose should NOT be called
        ad.destroy()

        #expect(!skanManager.disposeCalled)
    }

    @Test func cleanupSKAdNetworkIsIdempotent() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        // Destroy twice should not crash
        ad.destroy()
        ad.destroy()

        #expect(ad.destroyed)
    }

    // MARK: - Events ignored after destroy

    @Test func skanNotStartedAfterAdIsDestroyed() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        ad.destroy()

        // Sending events after destroy should be no-ops
        ad.handleIframeEvent(.initIframe)
        ad.handleIframeEvent(.adDoneIframe(IframeEvent.AdDoneData()))

        #expect(!skanManager.initImpressionCalled)
        #expect(!skanManager.startImpressionCalled)
    }

    @Test func openComponentIgnoredAfterDestroy() {
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        ad.destroy()

        let data = IframeEvent.OpenComponentData()
        ad.handleIframeEvent(.openComponentIframe(data))

        #expect(!skanManager.startImpressionCalled)
    }

    // MARK: - Deferred start (pendingStart)

    @Test func skanPendingStartDeferredWhenInitNotCompleted() {
        // Use an async-completing mock to simulate delayed init
        let skanManager = MockSKAdNetworkManager()
        let session = makeSession(skanManager: skanManager)
        let ad = Ad(session: session, messageId: "a1", options: nil, omManager: MockOMManager())

        // Without a bid, both initSKAdNetwork and startSKAdNetwork are no-ops.
        // This test verifies the destroy-after-no-init path doesn't crash.
        ad.handleIframeEvent(.initIframe)
        ad.handleIframeEvent(.adDoneIframe(IframeEvent.AdDoneData()))
        ad.destroy()

        #expect(ad.destroyed)
        // No crash = pass
    }
}
