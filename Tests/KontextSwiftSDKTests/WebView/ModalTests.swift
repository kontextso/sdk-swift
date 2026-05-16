import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct ModalTests {

    // MARK: - Helpers

    private func makeSession() -> Session {
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
            onDebugEvent: nil,
            installId: "00000000-0000-7000-8000-000000000000"
        )
        return Session(config: config)
    }

    // MARK: - OpenComponent

    @Test func openComponentDataDefaults() {
        let data = IframeEvent.OpenComponentData()
        #expect(data.timeout == 5000)
        #expect(data.code == nil)
        #expect(data.brightnessDelta == nil)
        #expect(data.componentParams == nil)
    }

    @Test func openComponentDataClampsNegativeTimeout() {
        let data = IframeEvent.OpenComponentData(timeout: -1)
        #expect(data.timeout == 5000)
    }

    @Test func openComponentDataPreservesPositiveTimeout() {
        let data = IframeEvent.OpenComponentData(timeout: 3000)
        #expect(data.timeout == 3000)
    }

    // MARK: - Modal Lifecycle

    @Test func tearDownCleansUp() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        // Initially no modal
        #expect(ad.modalUrl == nil)

        // tearDown should be safe to call even without a modal
        ad.tearDown()
        #expect(ad.modalUrl == nil)
    }

    @Test func closeComponentEventClosesModal() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.closeComponentIframe)
        #expect(ad.modalUrl == nil)
    }

    @Test func errorComponentEventClosesModal() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.errorComponentIframe(.init()))
        #expect(ad.modalUrl == nil)
    }

    @Test func errorComponentForwardsIframePayloadToOnEvent() {
        // v4 sdk-js parity: when the modal creative emits
        // `error-component-iframe` with `{ message, errorType }`, the
        // SDK forwards both fields verbatim as `ad.error`. Without
        // plumbing them through `IframeEvent.ErrorComponentData`, the
        // publisher would only ever see the SDK's hardcoded defaults.
        let received = TestCollector<AdEvent>()
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
            onEvent: { received.append($0) },
            onDebugEvent: nil,
            installId: "00000000-0000-7000-8000-000000000000"
        )
        let session = Session(config: config)
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.errorComponentIframe(
            .init(message: "Render boundary tripped", errorType: "react_error_boundary")
        ))

        #expect(received.values.count == 1)
        if case .error(let data) = received.values.first {
            #expect(data.message == "Render boundary tripped")
            #expect(data.errCode == "react_error_boundary")
        } else {
            Issue.record("Expected .error event, got \(String(describing: received.values.first))")
        }
    }

    @Test func errorComponentFallsBackWhenPayloadEmpty() {
        // Mirrors v4 sdk-js fallback strings — when the iframe sends
        // no `{ message, errorType }`, the publisher still receives
        // a usable `ad.error` with the SDK's defaults.
        let received = TestCollector<AdEvent>()
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
            onEvent: { received.append($0) },
            onDebugEvent: nil,
            installId: "00000000-0000-7000-8000-000000000000"
        )
        let session = Session(config: config)
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.errorComponentIframe(.init()))

        #expect(received.values.count == 1)
        if case .error(let data) = received.values.first {
            #expect(data.message == "Modal component error")
            #expect(data.errCode == "modal_component_error")
        } else {
            Issue.record("Expected .error event, got \(String(describing: received.values.first))")
        }
    }

    @Test func onRequestModalCallbackInvoked() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        var receivedUrl: String?
        var receivedTimeout: Int?
        ad.onRequestModal = { url, timeout in
            receivedUrl = url
            receivedTimeout = timeout
        }

        // Without an iframeUrl set, openComponent is a no-op
        ad.handleIframeEvent(.openComponentIframe(IframeEvent.OpenComponentData(
            timeout: 3000
        )))

        // Since iframeUrl is nil, callback should not be invoked
        #expect(receivedUrl == nil)
        #expect(receivedTimeout == nil)
    }

    @Test func onDismissModalCallbackInvoked() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        var dismissed = false
        ad.onDismissModal = {
            dismissed = true
        }

        ad.tearDown()
        #expect(dismissed)
    }

    // MARK: - SKOverlay component

    @Test func skOverlayDataStoresAllProperties() {
        let data = IframeEvent.SKOverlayData(
            position: "bottomRaised",
            dismissible: false,
            appStoreId: "12345"
        )
        #expect(data.position == "bottomRaised")
        #expect(data.dismissible == false)
        #expect(data.appStoreId == "12345")
    }

    @Test func closeSKOverlayIframeDispatchesWithoutCrash() {
        // The `close-skoverlay-iframe` dispatch path was added when the
        // SKOverlay events split out of the component-iframe family.
        // Verify it routes to `dismissSKOverlay()` without crashing,
        // even when no SKOverlay was presented.
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.closeSKOverlayIframe)
        // No assertion — `dismissSKOverlay` is fire-and-forget and the
        // production manager safely no-ops when nothing is presented.
        // This test fails only on a regression that re-introduces a
        // crash on the dispatch path.
        #expect(!ad.destroyed)
    }
}
