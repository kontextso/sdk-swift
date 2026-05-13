import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct MessageRepresentableTests {

    /// Mirrors a typical publisher-side message model — different field
    /// names than the SDK's `Message`, raw String for role, UUID for id —
    /// so the test exercises the actual translation work, not a no-op.
    private struct PublisherMessage: MessageRepresentable {
        let id: UUID
        let role: String
        let body: String
        let sentAt: Date

        var asKontextMessage: Message {
            Message(
                id: id.uuidString,
                role: role == "user" ? .user : .assistant,
                content: body,
                createdAt: sentAt
            )
        }
    }

    // MARK: - Identity conformance

    @Test func messageReturnsSelfFromAsKontextMessage() {
        let date = Date()
        let original = Message(id: "m1", role: .user, content: "hi", createdAt: date)
        let asKontext = original.asKontextMessage

        // The built-in conformance must be identity — no copy, no mutation.
        #expect(asKontext == original)
        #expect(asKontext.id == "m1")
        #expect(asKontext.role == .user)
        #expect(asKontext.content == "hi")
        #expect(asKontext.createdAt == date)
    }

    // MARK: - Custom type conformance

    @Test func customTypeConvertsToMessageCorrectly() {
        let id = UUID()
        let date = Date()
        let pub = PublisherMessage(id: id, role: "user", body: "hello", sentAt: date)

        let converted = pub.asKontextMessage

        #expect(converted.id == id.uuidString)
        #expect(converted.role == .user)
        #expect(converted.content == "hello")
        #expect(converted.createdAt == date)
    }

    @Test func customTypeRoleMappingHandlesAssistant() {
        let pub = PublisherMessage(id: UUID(), role: "assistant", body: "ok", sentAt: Date())
        #expect(pub.asKontextMessage.role == .assistant)
    }

    // MARK: - Session.addMessage convenience overload

    @Test func sessionAcceptsCustomTypeViaConvenienceOverload() {
        let session = makeSession()
        let pub = PublisherMessage(id: UUID(), role: "user", body: "via custom type", sentAt: Date())

        // Compiles + runs without manual conversion at call site.
        session.addMessage(pub)

        #expect(session.messages.count == 1)
        #expect(session.messages.first?.content == "via custom type")
        #expect(session.messages.first?.role == .user)
    }

    @Test func sessionAcceptsMessageDirectly() {
        let session = makeSession()
        let msg = Message(id: "m1", role: .assistant, content: "direct", createdAt: Date())

        // The same protocol-based overload accepts `Message` itself
        // (because Message conforms to MessageRepresentable).
        session.addMessage(msg)

        #expect(session.messages.count == 1)
        #expect(session.messages.first?.content == "direct")
    }

    // MARK: - Helper

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
            onDebugEvent: nil
        )
        return Session(config: config)
    }
}
