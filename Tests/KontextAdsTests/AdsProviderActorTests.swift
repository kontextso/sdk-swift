import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests for the core state machine in AdsProviderActor.
///
/// The actor is 1000 LOC and exposes its behavior through the
/// `AdsProviderActing` protocol. We inject stubs for every collaborator
/// (AdsServerAPI, URLOpening, OMManaging, SKAdNetworkManaging,
/// SKOverlayPresenting, SKStoreProductPresenting) and capture delegate
/// events to assert the public contract.
@MainActor
struct AdsProviderActorTests {
    // MARK: - Test-scope factory

    private func makeSUT(
        api: StubAdsServerAPI? = nil,
        urlOpener: StubURLOpener? = nil,
        om: StubOMManager? = nil,
        skan: StubSKAdNetworkManager? = nil,
        overlay: StubSKOverlayPresenter? = nil,
        store: StubSKStoreProductPresenter? = nil,
        isDisabled: Bool = false,
        sessionId: String? = nil,
        configuration: AdsProviderConfiguration = .testConfig()
    ) -> (AdsProviderActor, CapturingDelegate, StubAdsServerAPI) {
        let api = api ?? StubAdsServerAPI()
        let urlOpener = urlOpener ?? StubURLOpener()
        let om = om ?? StubOMManager()
        let skan = skan ?? StubSKAdNetworkManager()
        let overlay = overlay ?? StubSKOverlayPresenter()
        let store = store ?? StubSKStoreProductPresenter()
        let actor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: api,
            urlOpener: urlOpener,
            omService: om,
            skAdNetworkManager: skan,
            skOverlayPresenter: overlay,
            skStoreProductPresenter: store
        )
        let delegate = CapturingDelegate()
        Task { await actor.setDelegate(delegate: delegate) }
        return (actor, delegate, api)
    }

    private func waitForEvents(_ delegate: CapturingDelegate, timeout: TimeInterval = 3.0, minCount: Int = 1) async {
        // Events fly via delegate, but Tasks spawned inside the actor complete
        // out of band. We poll briefly because a hard-coded sleep would be flaky.
        let deadline = Date().addingTimeInterval(timeout)
        while delegate.events.count < minCount && Date() < deadline {
            try? await Task.sleep(seconds: 0.05)
        }
    }

    private func userMessage(_ id: String, content: String = "Hi") -> AdsMessage {
        AdsMessage(id: id, role: .user, content: content, createdAt: Date(timeIntervalSince1970: 0))
    }

    private func assistantMessage(_ id: String, content: String = "Hello") -> AdsMessage {
        AdsMessage(id: id, role: .assistant, content: content, createdAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - setMessages

    @Test
    func setMessagesWithNoUserMessageDoesNotPreload() async {
        let (actor, delegate, api) = makeSUT()
        await actor.setMessages(messages: [assistantMessage("a1")])
        try? await Task.sleep(seconds: 0.1)
        #expect(api.preloadCallCount == 0)
        #expect(delegate.events.isEmpty)
    }

    @Test
    func setMessagesWithEmptyArrayDoesNotPreload() async {
        let (actor, delegate, api) = makeSUT()
        await actor.setMessages(messages: [])
        try? await Task.sleep(seconds: 0.1)
        #expect(api.preloadCallCount == 0)
        #expect(delegate.events.isEmpty)
    }

    @Test
    func setMessagesWithUserMessageTriggersPreload() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)

        #expect(api.preloadCallCount == 1)
    }

    @Test
    func setMessagesBindsBidsAndEmitsFilledEvent() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData(position: .afterAssistantMessage))
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1"), assistantMessage("a1")])
        await waitForEvents(delegate, minCount: 1)

        #expect(delegate.eventNames.contains("ad.filled"))
        let filled = delegate.events.first { $0.name == "ad.filled" }
        if case .filled(let ads) = filled ?? .cleared {
            #expect(!ads.isEmpty)
        } else {
            Issue.record("Expected .filled event with advertisements")
        }
    }

    @Test
    func setMessagesTwiceWithSameLastUserMessageDoesNotRePreload() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)
        let firstCount = api.preloadCallCount

        await actor.setMessages(messages: [userMessage("u1"), assistantMessage("a1")])
        try? await Task.sleep(seconds: 0.2)
        #expect(api.preloadCallCount == firstCount)
    }

    @Test
    func setMessagesWithNewUserMessageTriggersNewPreloadAndClearsFirst() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)
        #expect(api.preloadCallCount == 1)

        delegate.reset()

        await actor.setMessages(messages: [userMessage("u1"), assistantMessage("a1"), userMessage("u2")])
        await waitForEvents(delegate, timeout: 5.0, minCount: 1)

        #expect(api.preloadCallCount == 2)
        // A second user message should trigger a "cleared" event before the new preload begins.
        #expect(delegate.eventNames.contains("ad.cleared"))
    }

    // MARK: - Preload outcomes

    @Test
    func skipResponseEmitsNoFill() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(emptyPreloadedData(skip: true, skipCode: "no_fill"))
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)

        #expect(delegate.eventNames.contains("ad.no-fill"))
    }

    @Test
    func permanentErrorEmitsNoFillAndMarksProviderDisabled() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(emptyPreloadedData(skipCode: "forbidden", permanentError: true))
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)
        #expect(delegate.eventNames.contains("ad.no-fill"))

        // Subsequent messages should still hit the API (isDisabled affects header, not call behavior).
        // But the preload result permanentError=true resets state, so bids stay cleared.
        delegate.reset()
        api.setPreloadResponse(preloadedData())
        await actor.setMessages(messages: [userMessage("u2")])
        await waitForEvents(delegate, timeout: 5.0, minCount: 1)

        // After permanentError, the actor is in an isDisabled state. Preload still fires
        // (since the last-preload-user-message-id moved on) but ads are suppressed.
        let lastCall = api.preloadCalls.last
        #expect(lastCall?.isDisabled == true)
    }

    @Test
    func noBidsEmitsNoFillNotFilled() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(emptyPreloadedData(skipCode: "empty"))
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, minCount: 1)

        #expect(delegate.eventNames.contains("ad.no-fill"))
        #expect(!delegate.eventNames.contains("ad.filled"))
    }

    @Test
    func preloadErrorEmitsNoFillAndErrorEvents() async {
        let api = StubAdsServerAPI()
        struct BoomError: Error {}
        api.setPreloadError(BoomError())
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, timeout: 5.0, minCount: 2)

        #expect(delegate.eventNames.contains("ad.no-fill"))
        #expect(delegate.eventNames.contains("ad.error"))
    }

    // MARK: - Placement filtering

    @Test
    func bidsFilteredByAdDisplayPosition() async {
        let api = StubAdsServerAPI()
        // Configure two bids with different positions but the same code
        let userBid = Bid(
            bidId: UUID(), code: "inlineAd",
            adDisplayPosition: .afterUserMessage,
            skan: nil, impressionTrigger: .immediate, creativeType: nil
        )
        let assistantBid = Bid(
            bidId: UUID(), code: "inlineAd",
            adDisplayPosition: .afterAssistantMessage,
            skan: nil, impressionTrigger: .immediate, creativeType: nil
        )
        api.setPreloadResponse(PreloadedData(
            sessionId: "s",
            bids: [userBid, assistantBid],
            remoteLogLevel: nil,
            permanentError: nil,
            skip: nil,
            skipCode: nil
        ))
        let (actor, delegate, _) = makeSUT(api: api)

        await actor.setMessages(messages: [userMessage("u1"), assistantMessage("a1")])
        await waitForEvents(delegate, timeout: 5.0, minCount: 1)

        // Both bids should bind — one to u1 (afterUserMessage), one to a1 (afterAssistantMessage).
        let filled = delegate.events.filter { $0.name == "ad.filled" }
        #expect(!filled.isEmpty)
    }

    // MARK: - reset

    @Test
    func resetAlwaysDismissesOverlayAndStoreKitPresenter() async {
        let overlay = StubSKOverlayPresenter()
        let store = StubSKStoreProductPresenter()
        let (actor, _, _) = makeSUT(overlay: overlay, store: store)

        await actor.reset()

        // reset() unconditionally calls overlay.dismiss() and storeProduct.dismiss(),
        // regardless of whether anything is currently presented.
        #expect(overlay.dismissCalls == 1)
        #expect(store.dismissCalls == 1)
        // SKAdNetwork cleanup is guarded by skanOwner; a fresh actor has nothing to dispose,
        // so no dispose() call is expected here (see cleanupSKAdNetwork guard).
    }

    // MARK: - setDisabled

    @Test
    func setDisabledTrueCausesPreloadsToBeSentWithDisabledHeader() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, _, _) = makeSUT(api: api, isDisabled: false)

        await actor.setDisabled(true)
        await actor.setMessages(messages: [userMessage("u1")])
        try? await Task.sleep(seconds: 0.2)

        #expect(api.preloadCalls.first?.isDisabled == true)
    }

    @Test
    func setDisabledFalseCausesPreloadsToBeSentNotDisabled() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, _, _) = makeSUT(api: api, isDisabled: true)

        await actor.setDisabled(false)
        await actor.setMessages(messages: [userMessage("u1")])
        try? await Task.sleep(seconds: 0.2)

        #expect(api.preloadCalls.first?.isDisabled == false)
    }

    // MARK: - setIFA

    @Test
    func setIFAForwardsToPreloadCalls() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, _, _) = makeSUT(api: api)

        await actor.setIFA(advertisingId: "ad-id", vendorId: "v-id")
        await actor.setMessages(messages: [userMessage("u1")])
        try? await Task.sleep(seconds: 0.2)

        #expect(api.preloadCalls.first?.advertisingId == "ad-id")
        #expect(api.preloadCalls.first?.vendorId == "v-id")
    }

    @Test
    func setIFAWithNilValuesSendsNilInPreload() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, _, _) = makeSUT(api: api)

        await actor.setIFA(advertisingId: nil, vendorId: nil)
        await actor.setMessages(messages: [userMessage("u1")])
        try? await Task.sleep(seconds: 0.2)

        #expect(api.preloadCalls.first?.advertisingId == nil)
        #expect(api.preloadCalls.first?.vendorId == nil)
    }

    // MARK: - sessionId propagation

    @Test
    func initialSessionIdIsSentOnFirstPreload() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData(sessionId: "s-server"))
        let (actor, _, _) = makeSUT(api: api, sessionId: "s-from-init")

        await actor.setMessages(messages: [userMessage("u1")])
        try? await Task.sleep(seconds: 0.2)

        #expect(api.preloadCalls.first?.sessionId == "s-from-init")
    }

    @Test
    func serverReturnedSessionIdIsSentOnNextPreload() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData(sessionId: "s-server"))
        let (actor, delegate, _) = makeSUT(api: api, sessionId: nil)

        await actor.setMessages(messages: [userMessage("u1")])
        await waitForEvents(delegate, timeout: 5.0, minCount: 1)

        await actor.setMessages(messages: [userMessage("u1"), assistantMessage("a1"), userMessage("u2")])
        try? await Task.sleep(seconds: 2.5) // allow preload to settle

        // Second preload should reuse the server-assigned sessionId.
        #expect(api.preloadCalls.last?.sessionId == "s-server")
    }

    // MARK: - Message windowing

    @Test
    func preloadSendsOnlyLast30Messages() async {
        let api = StubAdsServerAPI()
        api.setPreloadResponse(preloadedData())
        let (actor, _, _) = makeSUT(api: api)

        // 40 messages total; actor should trim to trailing 30.
        var messages: [AdsMessage] = []
        for i in 0..<40 {
            messages.append(AdsMessage(id: "m-\(i)", role: i % 2 == 0 ? .user : .assistant, content: "#\(i)", createdAt: Date(timeIntervalSince1970: 0)))
        }
        await actor.setMessages(messages: messages)
        try? await Task.sleep(seconds: 0.3)

        #expect(api.preloadCalls.first?.messages.count == 30)
        #expect(api.preloadCalls.first?.messages.first?.id == "m-10")
        #expect(api.preloadCalls.first?.messages.last?.id == "m-39")
    }
}
