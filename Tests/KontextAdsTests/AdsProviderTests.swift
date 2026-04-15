import Combine
import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests for the public AdsProvider facade.
/// Covers: delegate forwarding, eventPublisher delivery, main-thread delivery,
/// and setMessages/enable/disable/configuration forwarding via the injected
/// dependency container.
@MainActor
struct AdsProviderTests {
    // MARK: - Stub actor

    actor StubActor: AdsProviderActing {
        private weak var _delegate: AdsProviderActingDelegate?
        private(set) var setDisabledCalls: [Bool] = []
        private(set) var setMessagesCalls: [[AdsMessage]] = []
        private(set) var resetCalls = 0
        private(set) var setIFACalls: [(ad: String?, vendor: String?)] = []

        func setDelegate(delegate: AdsProviderActingDelegate?) async {
            _delegate = delegate
        }

        func setDisabled(_ isDisabled: Bool) async {
            setDisabledCalls.append(isDisabled)
        }

        func setMessages(messages: [AdsMessage]) async {
            setMessagesCalls.append(messages)
        }

        func reset() async {
            resetCalls += 1
        }

        func setIFA(advertisingId: String?, vendorId: String?) async {
            setIFACalls.append((advertisingId, vendorId))
        }

        /// Test helper: send an event to the wired delegate.
        func emit(_ event: AdsEvent) async {
            _delegate?.adsProviderActing(self, didReceiveEvent: event)
        }
    }

    // MARK: - Test-scope DI container

    private func makeSUT(
        delegate: AdsProviderDelegate? = nil,
        configuration: AdsProviderConfiguration = .testConfig(),
        isDisabled: Bool = false
    ) async -> (AdsProvider, StubActor) {
        let stubActor = StubActor()
        let container = DependencyContainer(
            networking: Network(),
            adsServerAPI: StubAdsServerAPI(),
            adsProviderActing: stubActor,
            omService: StubOMManager()
        )
        let provider = AdsProvider(
            configuration: configuration,
            sessionId: nil,
            isDisabled: isDisabled,
            dependencies: container,
            delegate: delegate
        )
        // The internal init spawns a Task to wire the delegate — wait a tick.
        try? await Task.sleep(seconds: 0.1)
        return (provider, stubActor)
    }

    // MARK: - Configuration passthrough

    @Test
    func configurationIsExposedVerbatim() async {
        let config = AdsProviderConfiguration(
            publisherToken: "tok", userId: "u", conversationId: "c",
            enabledPlacementCodes: ["inlineAd"]
        )
        let (provider, _) = await makeSUT(configuration: config)
        #expect(provider.configuration.publisherToken == "tok")
        #expect(provider.configuration.userId == "u")
        #expect(provider.configuration.enabledPlacementCodes == ["inlineAd"])
    }

    // MARK: - setMessages forwarding

    @Test
    func setMessagesForwardsConvertedMessagesToActor() async {
        let (provider, actor) = await makeSUT()
        provider.setMessages([
            AdsMessage(id: "u1", role: .user, content: "Hi", createdAt: Date(timeIntervalSince1970: 0))
        ])
        // setMessages spawns a Task — give it a moment to complete.
        try? await Task.sleep(seconds: 0.1)

        let calls = await actor.setMessagesCalls
        #expect(calls.count == 1)
        #expect(calls.first?.count == 1)
        #expect(calls.first?.first?.id == "u1")
        #expect(calls.first?.first?.role == .user)
    }

    @Test
    func setMessagesViaRepresentableProvidingForwards() async {
        struct Provider: MessageRepresentableProviding {
            var message: MessageRepresentable
        }
        let (provider, actor) = await makeSUT()
        let msg = AdsMessage(id: "u1", role: .user, content: "Hi", createdAt: Date(timeIntervalSince1970: 0))
        provider.setMessages([Provider(message: msg)])
        try? await Task.sleep(seconds: 0.1)

        let calls = await actor.setMessagesCalls
        #expect(calls.first?.first?.id == "u1")
    }

    // MARK: - enable/disable forwarding

    @Test
    func enableForwardsFalseToActor() async {
        let (provider, actor) = await makeSUT()
        provider.enable()
        try? await Task.sleep(seconds: 0.1)
        let calls = await actor.setDisabledCalls
        #expect(calls == [false])
    }

    @Test
    func disableForwardsTrueToActor() async {
        let (provider, actor) = await makeSUT()
        provider.disable()
        try? await Task.sleep(seconds: 0.1)
        let calls = await actor.setDisabledCalls
        #expect(calls == [true])
    }

    // MARK: - eventPublisher delivery

    @Test
    func eventPublisherDeliversEventsFromActor() async throws {
        let (provider, actor) = await makeSUT()

        final class Collector: @unchecked Sendable {
            var events: [AdsEvent] = []
            var cancellable: AnyCancellable?
        }
        let collector = Collector()
        collector.cancellable = provider.eventPublisher.sink { collector.events.append($0) }

        await actor.emit(.cleared)
        await actor.emit(.noFill(AdsEvent.NoFillData(messageId: "m", skipCode: "skip")))

        // Events fly through main-thread hop inside the facade.
        try? await Task.sleep(seconds: 0.2)

        let names = collector.events.map(\.name)
        #expect(names.contains("ad.cleared"))
        #expect(names.contains("ad.no-fill"))

        collector.cancellable = nil
    }

    // MARK: - Delegate delivery on main thread

    @Test
    func delegateReceivesEventsOnMainThread() async {
        final class Spy: AdsProviderDelegate, @unchecked Sendable {
            var receivedOnMain: [Bool] = []
            func adsProvider(_ provider: AdsProvider, didReceiveEvent event: AdsEvent) {
                receivedOnMain.append(Thread.isMainThread)
            }
        }
        let spy = Spy()
        let (provider, actor) = await makeSUT(delegate: spy)

        await actor.emit(.cleared)
        await actor.emit(.filled([]))
        try? await Task.sleep(seconds: 0.2)

        #expect(spy.receivedOnMain.count == 2)
        #expect(spy.receivedOnMain.allSatisfy { $0 == true })
        _ = provider // keep provider alive until the assertions run
    }

    @Test
    func eventPublisherEmitsOnMainThread() async throws {
        let (provider, actor) = await makeSUT()
        final class Collector: @unchecked Sendable {
            var wasMain: [Bool] = []
            var cancellable: AnyCancellable?
        }
        let collector = Collector()
        collector.cancellable = provider.eventPublisher.sink { _ in
            collector.wasMain.append(Thread.isMainThread)
        }

        await actor.emit(.cleared)
        try? await Task.sleep(seconds: 0.2)

        #expect(!collector.wasMain.isEmpty)
        #expect(collector.wasMain.allSatisfy { $0 == true })
        collector.cancellable = nil
    }

    // MARK: - Delegate assignment

    @Test
    func changingDelegateAtRuntimeRedirectsEvents() async {
        final class Spy: AdsProviderDelegate, @unchecked Sendable {
            var received: [AdsEvent] = []
            func adsProvider(_ provider: AdsProvider, didReceiveEvent event: AdsEvent) {
                received.append(event)
            }
        }
        let first = Spy()
        let second = Spy()
        let (provider, actor) = await makeSUT(delegate: first)

        await actor.emit(.cleared)
        try? await Task.sleep(seconds: 0.15)

        provider.delegate = second
        await actor.emit(.cleared)
        try? await Task.sleep(seconds: 0.15)

        #expect(first.received.count == 1)
        #expect(second.received.count == 1)
    }
}
