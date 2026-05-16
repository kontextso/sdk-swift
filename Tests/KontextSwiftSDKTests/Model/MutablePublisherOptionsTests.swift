import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct MutablePublisherOptionsTests {

    // MARK: - Helpers

    private func makeConfig(
        character: Character? = nil,
        variantId: String? = nil,
        regulatory: Regulatory? = nil,
        userEmail: String? = nil,
        advertisingId: String? = nil,
        vendorId: String? = nil
    ) -> ResolvedConfig {
        ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: URL(string: "http://0.0.0.0:1")!,
            character: character,
            variantId: variantId,
            regulatory: regulatory,
            userEmail: userEmail,
            advertisingId: advertisingId,
            vendorId: vendorId,
            requestTrackingAuthorization: false,
            onEvent: nil,
            onDebugEvent: nil,
            installId: "00000000-0000-7000-8000-000000000000"
        )
    }

    // MARK: - Construction

    @Test func defaultInitAllNil() {
        let opts = MutablePublisherOptions()
        #expect(opts.variantId == nil)
        #expect(opts.regulatory == nil)
        #expect(opts.userEmail == nil)
        #expect(opts.advertisingId == nil)
        #expect(opts.vendorId == nil)
    }

    @Test func customInitPreservesValues() {
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "consent-string")
        let opts = MutablePublisherOptions(
            variantId: "v1",
            regulatory: regulatory,
            userEmail: "user@example.com",
            advertisingId: "ad-id",
            vendorId: "vendor-id"
        )

        #expect(opts.variantId == "v1")
        #expect(opts.regulatory == regulatory)
        #expect(opts.userEmail == "user@example.com")
        #expect(opts.advertisingId == "ad-id")
        #expect(opts.vendorId == "vendor-id")
    }

    // MARK: - Session.updateOptions

    @Test func updateOptionsAppliesAllNonNilFields() {
        let session = Session(config: makeConfig())
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "abc")

        session.updateOptions(MutablePublisherOptions(
            variantId: "v1",
            regulatory: regulatory,
            userEmail: "user@example.com",
            advertisingId: "ad-id",
            vendorId: "vendor-id"
        ))

        #expect(session.config.variantId == "v1")
        #expect(session.config.regulatory == regulatory)
        #expect(session.config.userEmail == "user@example.com")
        #expect(session.config.advertisingId == "ad-id")
        #expect(session.config.vendorId == "vendor-id")
    }

    @Test func updateOptionsPreservesExistingValuesForNilFields() {
        // Start with an already-populated session.
        let originalCharacter = Character(id: "c1", name: "Bot", avatarUrl: URL(string: "https://example.com/bot.png")!)
        let session = Session(config: makeConfig(
            character: originalCharacter,
            variantId: "original-variant",
            userEmail: "original@example.com"
        ))

        // Partial update touches only one field.
        session.updateOptions(MutablePublisherOptions(variantId: "new-variant"))

        // Updated field changed.
        #expect(session.config.variantId == "new-variant")
        // Other fields preserved (nil in the partial means "don't change").
        // `character` is set-once at construction (no longer mutable via
        // updateOptions); the original survives any updateOptions call.
        #expect(session.config.character == originalCharacter)
        #expect(session.config.userEmail == "original@example.com")
    }

    @Test func updateOptionsCannotChangeCharacter() {
        // Pins the contract: character is set-once at session construction.
        // Switching personas requires a new Session because the message
        // history accumulated in the existing one belongs to the original
        // character.
        let originalCharacter = Character(id: "c1", name: "Original", avatarUrl: URL(string: "https://example.com/original.png")!)
        let session = Session(config: makeConfig(character: originalCharacter))

        session.updateOptions(MutablePublisherOptions(variantId: "v"))

        #expect(session.config.character == originalCharacter)
    }

    // Note: a previous "updateOptionsAfterDestroyIsNoOp" test was
    // removed when `addMessage`/`updateOptions`/`sendUserEvent` started
    // tripping `assertionFailure` after destroy. That trap is the new
    // contract in DEBUG (catches misuse during development); release
    // builds preserve the silent no-op for host-app safety. The test
    // would crash in DEBUG and can't observe release-only behaviour.

    @Test func updateOptionsEmitsDebugEvent() {
        // Capture into a class-wrapped box so the closure capture is Sendable-safe.
        final class EventBox: @unchecked Sendable {
            var names: [String] = []
        }
        let box = EventBox()
        let session = Session(config: ResolvedConfig(
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
            onDebugEvent: { name, _ in box.names.append(name) },
            installId: "00000000-0000-7000-8000-000000000000"
        ))

        session.updateOptions(MutablePublisherOptions(variantId: "v1"))

        // Session prefixes debug events with "Session: " — match against that.
        #expect(box.names.contains(where: { $0 == "Session: options-updated" }))
    }
}
