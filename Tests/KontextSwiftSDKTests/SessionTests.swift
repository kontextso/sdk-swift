import Combine
import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct SessionTests {

    // MARK: - Helpers

    private func makeConfig(
        adServerUrl: String = "http://0.0.0.0:1",
        onEvent: AdEventHandler? = nil,
        onDebugEvent: DebugEventHandler? = nil
    ) -> ResolvedConfig {
        return ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: adServerUrl,
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: onEvent,
            onDebugEvent: onDebugEvent
        )
    }

    private func makeSession(
        onEvent: AdEventHandler? = nil,
        onDebugEvent: DebugEventHandler? = nil
    ) -> Session {
        return Session(config: makeConfig(
            onEvent: onEvent,
            onDebugEvent: onDebugEvent
        ))
    }

    // MARK: - addMessage

    @Test func addMessageAccumulatesMessages() {
        let session = makeSession()

        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))
        session.addMessage(Message(id: "a1", role: .assistant, content: "Hi there"))

        let messages = session.messages
        #expect(messages.count == 2)
        #expect(messages[0].id == "u1")
        #expect(messages[1].id == "a1")
    }

    @Test func addMessageCapsAt30Messages() {
        let session = makeSession()

        for i in 0..<35 {
            session.addMessage(Message(id: "m\(i)", role: .user, content: "msg \(i)"))
        }

        let messages = session.messages
        #expect(messages.count == 30)
        // Should keep the last 30 messages
        #expect(messages.first?.id == "m5")
        #expect(messages.last?.id == "m34")
    }

    @Test func addMessageAssistantRoleAccumulatesWithoutPreload() {
        // Assistant messages are stored but don't trigger a preload.
        // (Preload is only fired for user-role messages.)
        let session = makeSession()
        session.addMessage(Message(id: "a1", role: .assistant, content: "Hi"))
        #expect(session.messages.count == 1)
        #expect(session.messages.first?.role == .assistant)
    }

    @Test func addMessageUserRoleAccumulates() {
        // Sync-side contract: the message is appended immediately.
        // The fired-and-forgotten preload Task runs asynchronously and
        // delivers any outcome via onEvent — not via this call.
        let session = makeSession()
        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))
        #expect(session.messages.count == 1)
        #expect(session.messages.first?.role == .user)
    }

    @Test func addMessageWithTrackOnlyOptionAccumulates() {
        // trackOnly is consumed inside the background preload Task; from
        // the caller's point of view, addMessage is still fire-and-forget.
        let session = makeSession()
        session.addMessage(
            Message(id: "u1", role: .user, content: "Hello"),
            options: AddMessageOptions(trackOnly: true)
        )
        #expect(session.messages.count == 1)
    }

    @Test func assistantMessageDuringDebounceDoesNotCancelPreload() {
        // Regression: an assistant message arriving during a user
        // message's debounce window or in-flight preload must NOT
        // cancel the preload — sdk-js parity. Otherwise the bid that's
        // about to land for that assistant message gets dropped.
        //
        // The bug ran `preloadTask?.cancel()` before the role guard,
        // killing the user-msg Task before it ever called
        // `startPreload()`. We assert on the Task's cancellation state
        // synchronously — independent of Task scheduling, so it doesn't
        // flake under parallel test load.
        let session = makeSession()

        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))
        let userPreloadTask = session.preloadTask
        #expect(userPreloadTask != nil)
        #expect(userPreloadTask?.isCancelled == false)

        session.addMessage(Message(id: "a1", role: .assistant, content: "Hi"))

        // After fix: the captured user-msg Task is untouched.
        // Before fix: assistant ran `preloadTask?.cancel()` on it →
        // `isCancelled` flips to true.
        #expect(userPreloadTask?.isCancelled == false)

        session.destroy()
    }

    @Test func disabledSessionEmitsDebugEvent() {
        // When a session is disabled, addMessage still accumulates the
        // message but doesn't fire a preload — and emits a debug event so
        // misuse is observable. Mirrors sdk-js's `if (this.disabled) return`.
        final class DebugBox: @unchecked Sendable { var names: [String] = [] }
        let box = DebugBox()
        let session = makeSession(onDebugEvent: { name, _ in box.names.append(name) })
        session.disabled = true

        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))

        // The disabled path emits a "Session: addMessage-disabled" debug event.
        #expect(box.names.contains(where: { $0 == "Session: addMessage-disabled" }))
    }

    // MARK: - getBid

    @Test func getBidReturnsNilForUnknownMessageId() {
        let session = makeSession()
        #expect(session.bid(messageId: "nonexistent", code: "inlineAd") == nil)
    }

    @Test func getBidReturnsNilWhenNoBidsAssigned() {
        let session = makeSession()

        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))
        session.addMessage(Message(id: "a1", role: .assistant, content: "Hi"))

        // No preload has succeeded, so no bid
        #expect(session.bid(messageId: "a1", code: "inlineAd") == nil)
    }

    // MARK: - createAd

    @Test func createAdReturnsAdWithCorrectProperties() {
        let session = makeSession()
        let ad = session.createAd("a1", options: AdOptions(code: "banner", theme: "dark"))

        #expect(ad.messageId == "a1")
        #expect(ad.code == "banner")
        #expect(ad.theme == "dark")
        #expect(!ad.destroyed)
    }

    @Test func createAdDefaultsCodeToInlineAd() {
        let session = makeSession()
        let ad = session.createAd("a1")

        #expect(ad.code == "inlineAd")
        #expect(ad.theme == nil)
    }

    @Test func createAdReturnsExistingForSameMessageIdAndCode() {
        // sdk-js parity: createAd is idempotent for the same
        // (messageId, code) pair — second call returns the same Ad,
        // does not destroy and recreate. Critical for SwiftUI hosts
        // where the view struct's init runs on every parent body
        // re-evaluation.
        let session = makeSession()

        let ad1 = session.createAd("a1")
        let ad2 = session.createAd("a1")

        #expect(ad1 === ad2)
        #expect(!ad1.destroyed)
    }

    @Test func createAdAllowsMultiplePlacementsPerMessage() {
        // sdk-js parity: ads are keyed by messageId:code composite, so
        // a single message can carry an inline ad and a sidebar ad
        // concurrently.
        let session = makeSession()

        let inline = session.createAd("a1", options: AdOptions(code: "inlineAd"))
        let sidebar = session.createAd("a1", options: AdOptions(code: "sidebar"))

        #expect(inline !== sidebar)
        #expect(inline.code == "inlineAd")
        #expect(sidebar.code == "sidebar")
        #expect(!inline.destroyed)
        #expect(!sidebar.destroyed)
    }

    // MARK: - destroy

    @Test func destroyCleanUp() {
        let session = makeSession()

        let ad1 = session.createAd("a1")
        let ad2 = session.createAd("a2")

        session.destroy()

        #expect(ad1.destroyed)
        #expect(ad2.destroyed)
    }

    // MARK: - subscribeBidUpdates

    @Test func subscribeBidUpdatesReturnsUnsubscribe() {
        let session = makeSession()
        var called = false

        let unsubscribe = session.subscribeBidUpdates {
            called = true
        }

        // Unsubscribe should be callable
        unsubscribe()
        // After unsubscribe, callback should not be called
        #expect(!called)
    }

    // MARK: - sendUserEvent

    @Test func sendUserEventBroadcastsToListeners() {
        let session = makeSession()
        var received: [UserEvent] = []

        _ = session.registerUserEventSender { event in
            received.append(event)
        }

        session.sendUserEvent(.userTypingStarted, payload: ["key": "value"])

        #expect(received.count == 1)
        #expect(received.first?.name == .userTypingStarted)
        #expect(received.first?.payload?["key"] as? String == "value")
    }

    @Test func sendUserEventDefaultsCodeToInlineAd() {
        // Mirrors sdk-js: `code` defaults to `DEFAULT_PLACEMENT_CODE`.
        // The receiving iframe filters on this field, so it has to be
        // present on every dispatched event.
        let session = makeSession()
        var received: [UserEvent] = []
        _ = session.registerUserEventSender { received.append($0) }

        session.sendUserEvent(.userTypingStarted)

        #expect(received.first?.code == "inlineAd")
    }

    @Test func sendUserEventCarriesCustomCode() {
        // Caller-supplied code reaches the sender unchanged so the
        // iframe (or host filter, when added) can target multi-placement
        // setups.
        let session = makeSession()
        var received: [UserEvent] = []
        _ = session.registerUserEventSender { received.append($0) }

        session.sendUserEvent(.userTypingStarted, code: "sidebar")

        #expect(received.first?.code == "sidebar")
    }

    // MARK: - Session configuration

    @Test func sessionHasCorrectConfig() {
        let session = makeSession()

        #expect(session.config.publisherToken == "test-token")
        #expect(session.config.userId == "test-user")
        #expect(session.config.conversationId == "test-conv")
        #expect(session.sessionId == nil)
        #expect(!session.disabled)
    }

    @Test func preloadTimeoutDefault() {
        let session = makeSession()
        #expect(session.preloadTimeout == 16000)
    }

    @Test func reportingFlagsDefaults() {
        // Pre-init defaults: errors are forwarded (matches existing
        // fire-and-forget behaviour) and debug is local-only (privacy).
        // Server flips these via the `/init` response if needed.
        let session = makeSession()
        #expect(session.reportErrors == true)
        #expect(session.reportDebug == false)
    }

    @Test func removePreload() {
        let session = makeSession()

        session.addMessage(Message(id: "u1", role: .user, content: "Hello"))
        session.addMessage(Message(id: "a1", role: .assistant, content: "Hi"))

        // Should not crash even if no preload exists for this message
        session.removePreload("a1")
        #expect(session.preload(messageId: "a1") == nil)
    }

    @Test func removePreloadKeepsPreloadWhenOtherAdReferencesMessage() {
        // sdk-js parity: `removePreload` is a no-op when ads still
        // reference the messageId — destroying one ad in a
        // multi-placement scenario must not yank the bid out from
        // under the surviving sibling.
        final class DebugBox: @unchecked Sendable { var names: [String] = [] }
        let box = DebugBox()
        let session = makeSession(onDebugEvent: { name, _ in box.names.append(name) })

        let inline = session.createAd("m1", options: AdOptions(code: "inlineAd"))
        let sidebar = session.createAd("m1", options: AdOptions(code: "sidebar"))

        inline.destroy()

        // After inline.destroy(): `Ad.destroy()` calls `removeAd` then
        // `removePreload("m1")`. The sidebar's "m1:sidebar" entry is
        // still in `ads`, so the guard short-circuits — observable via
        // the debug-event stream.
        #expect(box.names.contains("Session: removePreload-skip-still-referenced"))
        #expect(!sidebar.destroyed)
    }

    // MARK: - applyPreloadResult

    @Test func applyPreloadResultSynthesizesErrorOnDisableSessionWithNoEvent() {
        // sdk-js parity: when a preload failure says disableSession=true
        // but the server didn't include an explicit `event`, the SDK
        // synthesizes a session_disabled_by_preload ad.error so the
        // publisher's onEvent always fires when the session is disabled.
        let received = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { received.append($0) })

        session.applyPreloadResult(.failure(
            reason: "test-disable",
            event: nil,
            disableSession: true
        ))

        #expect(session.disabled)
        #expect(received.values.count == 1)
        if case .error(let data) = received.values.first {
            #expect(data.errCode == "session_disabled_by_preload")
            #expect(data.message == "Session is disabled")
        } else {
            Issue.record("Expected synthesized .error event, got \(String(describing: received.values.first))")
        }
    }

    @Test func applyPreloadResultEmitsOneFilledEventPerBidWithBidIdAndCode() {
        // Pins the multi-code disambiguation contract: when a publisher
        // registers multiple enabledPlacementCodes and the server fills
        // both, the SDK fans out one ad.filled per matched code, each
        // payload carrying the originating bidId + code so consumers can
        // attribute correctly.
        let received = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { received.append($0) })

        let id1 = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let id2 = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let bids = [
            Bid(bidId: id1, code: "inlineAd", revenue: 0.05),
            Bid(bidId: id2, code: "interstitialAd", revenue: 0.10),
        ]

        session.applyPreloadResult(.success(
            bids: bids,
            sessionId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")
        ))

        let filled = received.values.compactMap { event -> AdEvent.FilledData? in
            if case .filled(let data) = event { return data } else { return nil }
        }
        #expect(filled.count == 2)
        #expect(filled.map(\.bidId) == [id1, id2])
        #expect(filled.map(\.code) == ["inlineAd", "interstitialAd"])
        #expect(filled.map(\.revenue) == [0.05, 0.10])
    }

    @Test func applyPreloadResultDoesNotSynthesizeWhenServerSendsExplicitEvent() {
        // The synthesized error must NOT fire if the server already sent
        // its own — otherwise the publisher would see two error events
        // for one disable.
        let received = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { received.append($0) })

        let serverEvent: AdEvent = .error(.init(message: "Custom server reason", errCode: "custom_code"))
        session.applyPreloadResult(.failure(
            reason: "test-disable",
            event: serverEvent,
            disableSession: true
        ))

        #expect(session.disabled)
        #expect(received.values.count == 1)
        #expect(received.values.first == serverEvent)
    }

    // MARK: - emitEvent

    @Test func emitEventSendsToOnEventCallback() {
        let receivedEvents = TestCollector<AdEvent>()
        let session = makeSession(onEvent: { event in
            receivedEvents.append(event)
        })

        let bidId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        session.emitEvent(.filled(.init(bidId: bidId, code: "inlineAd", revenue: 0.05)))

        #expect(receivedEvents.values == [.filled(.init(bidId: bidId, code: "inlineAd", revenue: 0.05))])
    }

    @Test func emitEventSendsToBothCallbackAndPublisher() {
        let callbackEvents = TestCollector<AdEvent>()
        let publisherEvents = TestCollector<AdEvent>()

        let session = makeSession(onEvent: { event in
            callbackEvents.append(event)
        })

        let cancellable = session.eventPublisher.sink { event in
            publisherEvents.append(event)
        }

        let errorEvent = AdEvent.error(.init(message: "test error", errCode: "test_code"))
        session.emitEvent(errorEvent)

        #expect(callbackEvents.values == [errorEvent])
        #expect(publisherEvents.values == [errorEvent])

        _ = cancellable
    }

    @Test func eventPublisherDeliversAdEventViaCombine() {
        let publisherEvents = TestCollector<AdEvent>()

        let session = makeSession()

        let cancellable = session.eventPublisher.sink { event in
            publisherEvents.append(event)
        }

        let bidId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        session.emitEvent(.renderStarted(.init(bidId: bidId)))
        session.emitEvent(.adHeight(.init(bidId: bidId, messageId: "msg-1", height: 250)))

        #expect(publisherEvents.values == [
            .renderStarted(.init(bidId: bidId)),
            .adHeight(.init(bidId: bidId, messageId: "msg-1", height: 250)),
        ])

        _ = cancellable
    }

    @Test func eventPublisherDoesNotReceiveEventsAfterCancellation() {
        let publisherEvents = TestCollector<AdEvent>()

        let session = makeSession()

        let cancellable = session.eventPublisher.sink { event in
            publisherEvents.append(event)
        }

        let bidId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        session.emitEvent(.filled(.init(bidId: bidId, code: "inlineAd", revenue: 0.01)))
        #expect(publisherEvents.count == 1)

        cancellable.cancel()

        session.emitEvent(.filled(.init(bidId: bidId, code: "inlineAd", revenue: 0.02)))
        #expect(publisherEvents.count == 1) // Still 1, no new event received
    }

    // MARK: - requestTrackingAuthorization config

    @Test func sessionWithRequestTrackingAuthorizationFalse() {
        let config = makeConfig()
        #expect(config.requestTrackingAuthorization == false)

        let session = Session(config: config)
        #expect(session.config.requestTrackingAuthorization == false)
    }
}
