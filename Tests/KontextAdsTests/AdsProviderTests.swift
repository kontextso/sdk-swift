import Foundation
import Testing
import WebKit
@testable import KontextSwiftSDK

struct AdsProviderTests {
    @Test
    func sendUserEventDelegatesToActor() async {
        let adsProviderActing = AdsProviderActingSpy()
        let dependencies = DependencyContainer(
            networking: NoopNetworking(),
            adsServerAPI: NoopAdsServerAPI(),
            adsProviderActing: adsProviderActing,
            omService: NoopOMManager()
        )
        let adsProvider = AdsProvider(
            configuration: makeConfiguration(),
            dependencies: dependencies
        )

        let nextEvent = Task {
            await adsProviderActing.nextUserEvent()
        }

        adsProvider.sendUserEvent(name: .userTypingStarted)

        let sentEvent = await nextEvent.value
        #expect(sentEvent == .userTypingStarted)
        #expect(await adsProviderActing.recordedUserEvents() == [.userTypingStarted])
    }
}

private func makeConfiguration() -> AdsProviderConfiguration {
    AdsProviderConfiguration(
        publisherToken: "publisher-token",
        userId: "user-id",
        conversationId: "conversation-id",
        enabledPlacementCodes: ["inlineAd"]
    )
}

private actor AdsProviderActingSpy: AdsProviderActing {
    private var sentUserEvents: [UserEventName] = []
    private var nextUserEventContinuation: CheckedContinuation<UserEventName, Never>?

    func setDelegate(delegate: AdsProviderActingDelegate?) async {}

    func setDisabled(_ isDisabled: Bool) async {}

    func setMessages(messages: [AdsMessage]) async {}

    func sendUserEvent(name: UserEventName) async {
        sentUserEvents.append(name)
        nextUserEventContinuation?.resume(returning: name)
        nextUserEventContinuation = nil
    }

    func reset() async {}

    func setIFA(advertisingId: String?, vendorId: String?) async {}

    func nextUserEvent() async -> UserEventName {
        if let firstSentUserEvent = sentUserEvents.first {
            return firstSentUserEvent
        }

        await withCheckedContinuation { continuation in
            nextUserEventContinuation = continuation
        }
    }

    func recordedUserEvents() -> [UserEventName] {
        sentUserEvents
    }
}

private struct NoopNetworking: Networking {
    func request<E: Encodable>(
        method: HTTPMethod,
        urlConvertible: any URLConvertible,
        headers: [HTTPHeaderField],
        body: E
    ) async throws {}

    func request<E: Encodable, D: Decodable>(
        method: HTTPMethod,
        urlConvertible: URLConvertible,
        headers: [HTTPHeaderField],
        body: E
    ) async throws -> D {
        fatalError("NoopNetworking.request(_:urlConvertible:headers:body:) should not be called in this test")
    }
}

private struct NoopAdsServerAPI: AdsServerAPI {
    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        isDisabled: Bool,
        advertisingId: String?,
        vendorId: String?,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        fatalError("NoopAdsServerAPI.preload(...) should not be called in this test")
    }

    @MainActor
    func frameURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        otherParams: [String: String]
    ) -> URL? {
        URL(string: "https://example.com/frame")
    }

    @MainActor
    func componentURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        component: String,
        otherParams: [String: String]
    ) -> URL? {
        URL(string: "https://example.com/component")
    }

    func redirectURL(relativeURL: URL) -> URL {
        relativeURL
    }
}

private struct NoopOMManager: OMManaging {
    @discardableResult
    func activate() -> Bool {
        true
    }

    func createSession(_ webView: WKWebView, url: URL?, creativeType: OmCreativeType) throws -> OMSession {
        fatalError("NoopOMManager.createSession(_:url:creativeType:) should not be called in this test")
    }
}
