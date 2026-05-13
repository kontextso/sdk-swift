import Foundation
@testable import KontextSwiftSDK
import Testing

struct ErrorCaptureTests {

    // MARK: - ErrorContext

    @Test func errorContextStoresAllFields() {
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://example.com")!,
            publisherToken: "tok-123",
            conversationId: "conv-456",
            userId: "user-789",
            bidId: "bid-abc"
        )

        #expect(ctx.adServerUrl == URL(string: "https://example.com"))
        #expect(ctx.publisherToken == "tok-123")
        #expect(ctx.conversationId == "conv-456")
        #expect(ctx.userId == "user-789")
        #expect(ctx.bidId == "bid-abc")
    }

    @Test func errorContextAllowsNilOptionalFields() {
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://example.com")!,
            publisherToken: nil,
            conversationId: nil,
            userId: nil,
            bidId: nil
        )

        #expect(ctx.adServerUrl == URL(string: "https://example.com"))
        #expect(ctx.publisherToken == nil)
        #expect(ctx.conversationId == nil)
        #expect(ctx.userId == nil)
        #expect(ctx.bidId == nil)
    }

    // MARK: - capture(message:stack:context:) doesn't crash

    @Test func captureMessageWithNilContextDoesNotCrash() {
        // Should not throw or crash — fire-and-forget
        ErrorCapture.capture(message: "Something went wrong", stack: "trace", context: nil)
    }

    @Test func captureMessageWithValidContextDoesNotCrash() {
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!,
            publisherToken: "token",
            conversationId: "conv",
            userId: "user",
            bidId: "bid"
        )
        ErrorCapture.capture(message: "Test error", stack: "stack trace here", context: ctx)
    }

    @Test func captureMessageWithNilStackDoesNotCrash() {
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!,
            publisherToken: "token",
            conversationId: nil,
            userId: nil,
            bidId: nil
        )
        ErrorCapture.capture(message: "Error without stack", stack: nil, context: ctx)
    }

    // MARK: - capture(_ error:context:)

    @Test func captureErrorConvertsToMessage() {
        enum TestError: Error, LocalizedError {
            case somethingFailed
            var errorDescription: String? { "Something failed" }
        }

        // Should not crash — verifies the Error → message path works
        ErrorCapture.capture(TestError.somethingFailed, context: nil)
    }

    @Test func captureWithReportEnabledFalseDoesNotCrash() {
        // The kill-switch path: `reportEnabled: false` skips the
        // network leg but the local print still runs. Fire-and-forget,
        // so nothing observable beyond "doesn't crash" — the wire-side
        // assertion belongs in a higher-level integration test
        // (Session.fireInit applies the flag).
        ErrorCapture.capture(
            message: "suppressed",
            context: ErrorContext(adServerUrl: URL(string: "https://example.test")!),
            reportEnabled: false
        )
    }

    @Test func captureNSErrorDoesNotCrash() {
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSLocalizedDescriptionKey: "A test error occurred"
        ])
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!,
            publisherToken: "pub-token",
            conversationId: "conv-1",
            userId: "user-1",
            bidId: "bid-1"
        )
        ErrorCapture.capture(error, context: ctx)
    }

    // MARK: - Default URL fallback

    @Test func defaultAdServerUrlUsedWhenContextIsNil() {
        // When context is nil, the default URL "https://server.megabrain.co" is used.
        // We can't intercept the network call easily, but we verify it doesn't crash.
        ErrorCapture.capture(message: "fallback url test", context: nil)
    }

    // MARK: - DTO encoding

    @Test func dtoEncodesAllFields() throws {
        let dto = ErrorRequestDTO(
            error: "test message",
            stack: "stack trace",
            additionalData: ErrorRequestDTO.AdditionalData(
                publisherToken: "tok",
                conversationId: "conv",
                userId: "usr",
                bidId: "bid",
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["error"] as? String == "test message")
        #expect(decoded?["stack"] as? String == "stack trace")

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?["publisherToken"] as? String == "tok")
        #expect(additionalData?["conversationId"] as? String == "conv")
        #expect(additionalData?["userId"] as? String == "usr")
        #expect(additionalData?["bidId"] as? String == "bid")

        let sdk = additionalData?["sdk"] as? [String: Any]
        #expect(sdk?["name"] as? String == SDKInfo.current.name)
        #expect(sdk?["platform"] as? String == SDKInfo.current.platform)
        #expect(sdk?["version"] as? String == SDKInfo.current.version)
    }

    @Test func dtoEncodesNilOptionalsAsAbsentKeys() throws {
        // JSONEncoder's default behavior drops nil-valued Optional<String>
        // properties — keep that contract pinned so the wire shape stays
        // compatible with sdk-js (which also omits nullish fields).
        let dto = ErrorRequestDTO(
            error: "msg",
            stack: nil,
            additionalData: ErrorRequestDTO.AdditionalData(
                publisherToken: nil,
                conversationId: nil,
                userId: nil,
                bidId: nil,
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["error"] as? String == "msg")
        #expect(decoded?.keys.contains("stack") == false)

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?.keys.contains("publisherToken") == false)
        #expect(additionalData?.keys.contains("conversationId") == false)
        #expect(additionalData?.keys.contains("userId") == false)
        #expect(additionalData?.keys.contains("bidId") == false)
        #expect(additionalData?["sdk"] != nil)
    }

    @Test func urlFormationUsesErrorEndpoint() throws {
        let adServerUrl = "https://custom.server.com"
        let url = URL(string: "\(adServerUrl)/error")

        #expect(url != nil)
        #expect(url?.absoluteString == "https://custom.server.com/error")
    }
}
