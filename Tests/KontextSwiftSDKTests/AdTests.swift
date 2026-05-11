import Combine
import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct AdTests {

    // MARK: - Helpers

    private func makeSession(onEvent: AdEventHandler? = nil) -> Session {
        let config = ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: "http://0.0.0.0:1",
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: onEvent,
            onDebugEvent: nil
        )
        return Session(config: config)
    }

    // MARK: - Properties

    @Test func adHasCorrectMessageIdCodeTheme() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1", options: AdOptions(code: "banner", theme: "dark"))

        #expect(ad.messageId == "a1")
        #expect(ad.code == "banner")
        #expect(ad.theme == "dark")
    }

    @Test func adDefaultsCodeToInlineAd() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        #expect(ad.code == "inlineAd")
        #expect(ad.theme == nil)
    }

    @Test func adHasUniqueId() {
        let session = makeSession()
        let ad1 = Ad(session: session, messageId: "a1")
        let ad2 = Ad(session: session, messageId: "a2")

        #expect(ad1.id != ad2.id)
    }

    @Test func adInitialState() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        #expect(ad.iframeUrl == nil)
        #expect(ad.height == 0)
        #expect(!ad.isVisible)
        #expect(!ad.destroyed)
    }

    // MARK: - Destroy

    @Test func destroySetsDestroyedFlag() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        #expect(!ad.destroyed)
        ad.destroy()
        #expect(ad.destroyed)
    }

    @Test func destroyIsIdempotent() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.destroy()
        #expect(ad.destroyed)

        // Second destroy should not crash
        ad.destroy()
        #expect(ad.destroyed)
    }

    @Test func destroyRemovesFromSession() {
        let session = makeSession()
        let ad = session.createAd("a1")

        #expect(!ad.destroyed)

        ad.destroy()
        #expect(ad.destroyed)

        // Creating a new ad for the same messageId should work (not find the old one)
        let ad2 = session.createAd("a1")
        #expect(!ad2.destroyed)
    }

    // MARK: - Iframe Event Handling

    @Test func handleResizeEvent() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))
        #expect(ad.height == 250)
    }

    @Test func handleResizeIgnoresNonPositiveHeight() {
        // sdk-rn parity: iframes collapse via `hide-iframe`, not by
        // sending zero/negative resizes. Such messages are dropped
        // rather than overwriting the existing height with 0.
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))
        #expect(ad.height == 250)

        ad.handleIframeEvent(.resizeIframe(.init(height: 0)))
        #expect(ad.height == 250)

        ad.handleIframeEvent(.resizeIframe(.init(height: -10)))
        #expect(ad.height == 250)
    }

    @Test func handleResizeDedupesSameHeight() {
        // v3 sdk-swift parity: an iframe that resends the same height
        // shouldn't refire the `@Published` value or `emitEvent`. The
        // `@Published` wrapper does NOT auto-dedupe — it fires
        // `objectWillChange` on every assignment regardless of value
        // equality — so without the dedupe guard, three resize
        // messages for the same height would trigger three SwiftUI
        // re-renders and three `adHeight` event emits.
        //
        // Observed via the Combine projection of `height`: a fresh
        // sink fires once on subscribe (initial 0), then once per
        // distinct assignment.
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")
        var heightUpdates: [CGFloat] = []
        let cancellable = ad.$height.sink { heightUpdates.append($0) }
        defer { cancellable.cancel() }

        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))
        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))   // dedupe
        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))   // dedupe
        ad.handleIframeEvent(.resizeIframe(.init(height: 300)))
        ad.handleIframeEvent(.resizeIframe(.init(height: 300)))   // dedupe

        // Without the dedupe guard this would be `[0, 250, 250, 250, 300, 300]`.
        #expect(heightUpdates == [0, 250, 300])
    }

    @Test func handleShowEvent() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.showIframe)
        #expect(ad.isVisible)
    }

    @Test func handleHideEvent() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.showIframe)
        #expect(ad.isVisible)

        ad.handleIframeEvent(.hideIframe)
        #expect(!ad.isVisible)
    }

    @Test func handleHidePreservesHeight() {
        // sdk-react-native / sdk-js / v3 sdk-swift parity: hide doesn't
        // reset height. The view layer (`InlineAdView` /
        // `InlineAdUIView`) already gates visibility on `isVisible`, so
        // resetting would be dead code AND would cause a "flash of
        // small ad" on a subsequent show before the iframe re-sends
        // `resize-iframe`.
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.resizeIframe(.init(height: 250)))
        ad.handleIframeEvent(.showIframe)
        ad.handleIframeEvent(.hideIframe)

        #expect(!ad.isVisible)
        #expect(ad.height == 250)
    }

    @Test func handleShowAndHideDedupe() {
        // v3 sdk-swift parity dedupe — `@Published` fires willSet on
        // every assignment, so repeated show/hide messages without
        // dedupe would trigger redundant SwiftUI re-renders and
        // duplicate `$isVisible` Combine deliveries.
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")
        var visibleUpdates: [Bool] = []
        let cancellable = ad.$isVisible.sink { visibleUpdates.append($0) }
        defer { cancellable.cancel() }

        ad.handleIframeEvent(.showIframe)
        ad.handleIframeEvent(.showIframe)   // dedupe
        ad.handleIframeEvent(.showIframe)   // dedupe
        ad.handleIframeEvent(.hideIframe)
        ad.handleIframeEvent(.hideIframe)   // dedupe

        // Without the dedupe guards this would be
        // `[false, true, true, true, false, false]`.
        #expect(visibleUpdates == [false, true, false])
    }

    @Test func handleErrorIframeEmitsAdError() {
        // v4 sdk-js parity: `error-iframe` notifies the publisher via
        // a generic `ad.error` event. Without it the publisher would
        // see the ad disappear (when AdWebView calls `ad.destroy`)
        // with no idea why. The actual teardown is exercised by
        // AdWebView's wire-level handler — here we only assert the
        // notification side-effect.
        let received = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { received.append($0) })
        let ad = Ad(session: session, messageId: "a1")

        ad.handleIframeEvent(.errorIframe)

        #expect(received.values.count == 1)
        if case .error(let data) = received.values.first {
            #expect(data.message == "Error loading iframe")
            #expect(data.errCode == "iframe_error")
        } else {
            Issue.record("Expected .error event, got \(String(describing: received.values.first))")
        }
    }

    @Test func handleEventsIgnoredAfterDestroy() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        ad.destroy()
        ad.handleIframeEvent(.resizeIframe(.init(height: 300)))
        ad.handleIframeEvent(.showIframe)

        #expect(ad.height == 0)
        #expect(!ad.isVisible)
    }
}
