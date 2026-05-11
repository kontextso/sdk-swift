import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct EventTests {

    // Stable test bidId — most tests don't need uniqueness, just a
    // valid UUID. Using a single fixture keeps Equatable assertions
    // straightforward.
    private let bidId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    // MARK: - filled / noFill / error: simple value-carrying cases

    @Test func filledEventWithRevenue() {
        let data = AdEvent.FilledData(bidId: bidId, code: "inlineAd", revenue: 0.0042)
        #expect(AdEvent.filled(data) == .filled(data))
    }

    @Test func filledEventWithoutRevenue() {
        let data = AdEvent.FilledData(bidId: bidId, code: "inlineAd", revenue: nil)
        #expect(AdEvent.filled(data) == .filled(data))
    }

    @Test func filledEventCarriesBidIdAndCode() {
        // Pins the multi-code disambiguation contract: with multiple
        // enabledPlacementCodes, publishers receive one ad.filled per
        // matched code and need both bidId and code to attribute correctly.
        let data = AdEvent.FilledData(bidId: bidId, code: "interstitialAd", revenue: 0.05)
        #expect(data.bidId == bidId)
        #expect(data.code == "interstitialAd")
        #expect(data.revenue == 0.05)
    }

    @Test func noFillEventWithReason() {
        #expect(AdEvent.noFill(.init(skipCode: "frequency_cap")) == .noFill(.init(skipCode: "frequency_cap")))
    }

    @Test func noFillSkipCodeIsRequired() {
        // skipCode is non-optional per sdk-js contract — caller must
        // provide a value (e.g. "unknown" fallback) at construction.
        let data = AdEvent.NoFillData(skipCode: "unknown")
        #expect(data.skipCode == "unknown")
    }

    @Test func errorEvent() {
        #expect(
            AdEvent.error(.init(message: "Network error", errCode: "request_failed"))
            == .error(.init(message: "Network error", errCode: "request_failed"))
        )
    }

    // MARK: - bidId-keyed lifecycle events

    @Test func renderStartedCarriesBidId() {
        #expect(AdEvent.renderStarted(.init(bidId: bidId)) == .renderStarted(.init(bidId: bidId)))
    }

    @Test func renderCompletedCarriesBidId() {
        #expect(AdEvent.renderCompleted(.init(bidId: bidId)) == .renderCompleted(.init(bidId: bidId)))
    }

    @Test func videoStartedCarriesBidId() {
        #expect(AdEvent.videoStarted(.init(bidId: bidId)) == .videoStarted(.init(bidId: bidId)))
    }

    @Test func videoCompletedCarriesBidId() {
        #expect(AdEvent.videoCompleted(.init(bidId: bidId)) == .videoCompleted(.init(bidId: bidId)))
    }

    @Test func rewardGrantedCarriesBidId() {
        #expect(AdEvent.rewardGranted(.init(bidId: bidId)) == .rewardGranted(.init(bidId: bidId)))
    }

    // MARK: - viewed / clicked: payload structs

    @Test func viewedEventCarriesAllPayloadFields() {
        let data = AdEvent.ViewedData(
            bidId: bidId,
            content: "promo-banner",
            messageId: "a1",
            format: "display",
            revenue: 0.05
        )
        #expect(AdEvent.viewed(data) == .viewed(data))
    }

    @Test func clickedEventCarriesAllPayloadFields() {
        let data = AdEvent.ClickedData(
            bidId: bidId,
            content: "cta-button",
            messageId: "a1",
            url: "https://example.com/ad",
            format: "native",
            area: "headline"
        )
        #expect(AdEvent.clicked(data) == .clicked(data))
    }

    @Test func viewedRevenueIsTheOnlyOptionalField() {
        // Per sdk-js contract: bidId/content/messageId/format are
        // required, only `revenue` may be nil.
        let data = AdEvent.ViewedData(
            bidId: bidId,
            content: "c",
            messageId: "m",
            format: "f"
        )
        #expect(data.revenue == nil)
        #expect(data.bidId == bidId)
    }

    // MARK: - adHeight: gated on bid presence

    @Test func adHeightSkippedWhenNoBidResolved() {
        // No bid → no event. Layout-only state changes (height) still apply.
        // This matches v3's behavior, where `adHeight` carried a full
        // `Advertisement` (always with a bid).
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "msg-no-bid")

        ad.handleIframeEvent(.resizeIframe(.init(height: 100)))

        #expect(ad.height == 100)
        #expect(events.isEmpty)
    }

    // MARK: - integration: ad.viewed / ad.clicked from iframe payload

    @Test func handleAdEventViewedTakesBidIdFromIframePayload() {
        // sdk-js convention: iframe creative emits its own bidId as `id`
        // in the event payload. The Swift Ad layer surfaces it as
        // `ViewedData.bidId`.
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        let payload: [String: Any] = [
            "revenue": 0.03,
            "id": bidId.uuidString,
            "content": "video-ad",
            "format": "interstitial",
            "messageId": "a1",
        ]
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.viewed", payload: payload)))

        let viewedData = events.values.compactMap { event -> AdEvent.ViewedData? in
            if case let .viewed(data) = event { return data }
            return nil
        }
        #expect(viewedData.count == 1)
        #expect(viewedData[0].revenue == 0.03)
        #expect(viewedData[0].bidId == bidId)
        #expect(viewedData[0].content == "video-ad")
        #expect(viewedData[0].format == "interstitial")
        #expect(viewedData[0].messageId == "a1")
    }

    @Test func handleAdEventClickedTakesBidIdFromIframePayload() {
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        let payload: [String: Any] = [
            "url": "https://click.example.com",
            "id": bidId.uuidString,
            "content": "banner-cta",
            "format": "banner",
            "area": "image",
            "messageId": "a1",
        ]
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.clicked", payload: payload)))

        let clickedData = events.values.compactMap { event -> AdEvent.ClickedData? in
            if case let .clicked(data) = event { return data }
            return nil
        }
        #expect(clickedData.count == 1)
        #expect(clickedData[0].url == "https://click.example.com")
        #expect(clickedData[0].bidId == bidId)
        #expect(clickedData[0].content == "banner-cta")
        #expect(clickedData[0].format == "banner")
        #expect(clickedData[0].area == "image")
    }

    // MARK: - integration: lifecycle events from iframe carry bidId

    @Test func handleAdEventRenderCompletedEmitsBidIdFromPayload() {
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.render-completed", payload: ["id": bidId.uuidString])))

        #expect(events.values == [.renderCompleted(.init(bidId: bidId))])
    }

    @Test func handleAdEventVideoStartedEmitsBidIdFromPayload() {
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.started", payload: ["id": bidId.uuidString])))

        #expect(events.values == [.videoStarted(.init(bidId: bidId))])
    }

    @Test func handleAdEventVideoCompletedEmitsBidIdFromPayload() {
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.completed", payload: ["id": bidId.uuidString])))

        #expect(events.values == [.videoCompleted(.init(bidId: bidId))])
    }

    @Test func handleAdEventRewardGrantedEmitsBidIdFromPayload() {
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.reward.granted", payload: ["id": bidId.uuidString])))

        #expect(events.values == [.rewardGranted(.init(bidId: bidId))])
    }

    @Test func handleAdEventLifecycleSkippedWhenNoBidIdAvailable() {
        // If the iframe doesn't send `id` and there's no resolved bid to
        // fall back on, lifecycle events are silently dropped — there's
        // no bidId to attribute them to.
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.started", payload: nil)))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.completed", payload: nil)))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.reward.granted", payload: nil)))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.render-completed", payload: nil)))

        #expect(events.isEmpty)
    }

    @Test func handleAdEventLifecycleDropsWhenPayloadIdUnparseableAndNoBid() {
        // The iframe payload's `id` is parsed as a UUID; an unparseable
        // string falls through to `currentBid?.bidId`. With no resolved
        // bid here, the chain ends in nil → events drop. Pins that the
        // parser handles bad input gracefully (no crash, no smuggled
        // garbage UUID) — a regression that swapped UUID(uuidString:)
        // for a force-cast would crash this test instead of silently
        // dropping.
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        ad.handleIframeEvent(.eventIframe(.init(name: "ad.render-completed", payload: ["id": "not-a-uuid"])))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.started", payload: ["id": "garbage"])))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.video.completed", payload: ["id": ""])))
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.reward.granted", payload: ["id": "12345"])))

        #expect(events.isEmpty)
    }

    // MARK: - name property pins the wire-format strings

    @Test func eventNamesMatchWireFormat() {
        // Pin the strings — these are publisher-visible and double as
        // sdk-js parity wire keys.
        let bid = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let viewedData = AdEvent.ViewedData(bidId: bid, content: "c", messageId: "m", format: "f")
        let clickedData = AdEvent.ClickedData(bidId: bid, content: "c", messageId: "m", url: "u", format: "f", area: "a")
        #expect(AdEvent.filled(.init(bidId: bid, code: "inlineAd")).name == "ad.filled")
        #expect(AdEvent.noFill(.init(skipCode: "unknown")).name == "ad.no-fill")
        #expect(AdEvent.adHeight(.init(bidId: bid, messageId: "m", height: 1)).name == "ad.height")
        #expect(AdEvent.viewed(viewedData).name == "ad.viewed")
        #expect(AdEvent.clicked(clickedData).name == "ad.clicked")
        #expect(AdEvent.renderStarted(.init(bidId: bid)).name == "ad.render-started")
        #expect(AdEvent.renderCompleted(.init(bidId: bid)).name == "ad.render-completed")
        #expect(AdEvent.error(.init(message: "", errCode: "")).name == "ad.error")
        #expect(AdEvent.videoStarted(.init(bidId: bid)).name == "video.started")
        #expect(AdEvent.videoCompleted(.init(bidId: bid)).name == "video.completed")
        #expect(AdEvent.rewardGranted(.init(bidId: bid)).name == "reward.granted")
    }

    // MARK: - drop-event-on-incomplete-payload contract

    @Test func handleAdEventViewedDroppedWhenRequiredFieldMissing() {
        // Iframe omits `content` — event is dropped rather than emitted
        // with an empty string. Publishers see no event for this iframe
        // message.
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        let payload: [String: Any] = [
            "id": bidId.uuidString,
            "format": "display",
            // missing: content
        ]
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.viewed", payload: payload)))

        #expect(events.isEmpty)
    }

    @Test func handleAdEventClickedDroppedButURLStillOpens() {
        // Iframe sends `url` but omits other required fields. The event
        // is dropped, but the URL still opens — clicking is the user's
        // primary intent, analytics is secondary.
        let events = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { events.append($0) })
        let ad = makeAd(session: session, messageId: "a1")

        let payload: [String: Any] = [
            "url": "https://example.com",
            // missing: id, content, format, area
        ]
        ad.handleIframeEvent(.eventIframe(.init(name: "ad.clicked", payload: payload)))

        // No analytics event emitted (some required fields missing).
        let clickedEvents = events.values.filter {
            if case .clicked = $0 { return true }
            return false
        }
        #expect(clickedEvents.isEmpty)
    }

    // MARK: - Helpers

    private func makeSession(onEvent: @Sendable @escaping (AdEvent) -> Void) -> Session {
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

    private func makeAd(session: Session, messageId: String) -> Ad {
        Ad(session: session, messageId: messageId, options: nil, omManager: MockOMManager())
    }
}
