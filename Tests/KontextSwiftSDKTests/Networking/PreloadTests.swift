import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct PreloadTests {

    // MARK: - Helpers

    private func makeConfig() -> ResolvedConfig {
        return ResolvedConfig(
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
    }

    private func makeParams(config: ResolvedConfig? = nil, isDisabled: Bool = false) -> PreloadParams {
        return PreloadParams(
            config: config ?? makeConfig(),
            sessionId: nil,
            timeout: 16000,
            isDisabled: isDisabled,
            advertisingId: nil,
            vendorId: nil
        )
    }

    // MARK: - Initial State

    @Test func hasBidReturnsFalseInitially() {
        let preload = Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])
        #expect(!preload.hasBid)
    }

    @Test func getBidReturnsNilInitially() {
        let preload = Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])
        #expect(preload.bid(for: "inlineAd") == nil)
    }

    @Test func getMessagesReturnsSnapshot() {
        let messages = [
            Message(id: "u1", role: .user, content: "Hello"),
            Message(id: "a1", role: .assistant, content: "Hi"),
        ]
        let preload = Preload(messages: messages)

        let retrieved = preload.messages
        #expect(retrieved.count == 2)
        #expect(retrieved[0].id == "u1")
        #expect(retrieved[1].id == "a1")
    }

    @Test func isRunningReturnsFalseInitially() {
        let preload = Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])
        #expect(!preload.isRunning)
    }

    // MARK: - Cancel

    @Test func cancelStopsRunning() {
        let preload = Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])
        preload.cancel()
        #expect(!preload.isRunning)
    }

    // MARK: - requestAd

    @Test func requestAdReturnsFailureOnNoMessages() async {
        let preload = Preload(messages: [])
        let result = await preload.requestAd(params: makeParams())

        if case .failure(let reason, _, _, _) = result {
            #expect(reason == "No messages")
        } else {
            Issue.record("Expected failure for empty messages")
        }
    }

    @Test func requestAdReturnsFailureOnNetworkError() async {
        let messages = [Message(id: "u1", role: .user, content: "Hello")]
        let preload = Preload(messages: messages)

        // Connecting to 0.0.0.0:1 should fail
        let result = await preload.requestAd(params: makeParams())

        if case .failure(let reason, _, _, _) = result {
            #expect(reason == "Error preloading ads")
        } else {
            Issue.record("Expected failure for network error")
        }
    }

    @Test func getBidFiltersByCode() {
        let preload = Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])

        // No bids set, filtering by code should still return nil
        #expect(preload.bid(for: "banner") == nil)
        #expect(preload.bid(for: "inlineAd") == nil)
    }
}
