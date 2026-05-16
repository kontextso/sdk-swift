import Foundation
@testable import KontextSwiftSDK
import Testing

/// Captures every `URLRequest` handed to a stubbed `URLSession` so
/// network-leg assertions can verify that `ErrorCapture.capture(...)`
/// does (or doesn't) actually fire a POST. Carries process-global
/// mutable state, so the suite that uses it must run serialised.
private final class ErrorStubProtocol: URLProtocol {

    nonisolated(unsafe) static var capturedRequest: URLRequest?
    nonisolated(unsafe) static var capturedBody: Data?
    nonisolated(unsafe) static var didFire = false

    static func reset() {
        capturedRequest = nil
        capturedBody = nil
        didFire = false
    }

    // swiftlint:disable static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    // swiftlint:enable static_over_final_class

    override func startLoading() {
        ErrorStubProtocol.capturedRequest = request
        if let body = request.httpBody {
            ErrorStubProtocol.capturedBody = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            ErrorStubProtocol.capturedBody = data
        }
        ErrorStubProtocol.didFire = true

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.test/error")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ErrorStubProtocol.self]
    return URLSession(configuration: config)
}

/// Waits up to `timeoutMs` for `condition` to return true, sampling
/// every 10ms. The fire-and-forget network leg runs on a detached
/// Task so there's no await point on the calling side.
private func waitFor(timeoutMs: Int = 1000, _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

@Suite(.serialized)
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
                installId: "01890000-0000-7000-8000-000000000000",
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
        #expect(additionalData?["installId"] as? String == "01890000-0000-7000-8000-000000000000")
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
                installId: nil,
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

    // MARK: - Network leg

    @Test func reportEnabledFalseSkipsNetworkPost() async {
        // Pins the kill-switch behaviour: when `/init` returns
        // `reportErrors: false`, ErrorCapture must not POST to /error.
        // Without a stubbed URLSession the original test could only
        // verify "doesn't crash" — this one verifies the request never
        // leaves the SDK.
        ErrorStubProtocol.reset()
        let session = makeStubbedSession()

        ErrorCapture.capture(
            message: "suppressed",
            context: ErrorContext(adServerUrl: URL(string: "https://example.test")!),
            reportEnabled: false,
            session: session
        )

        // Give the (skipped) detached Task a window to fire if the
        // gate ever regresses. 100ms is plenty — the actual POST is
        // a single sub-millisecond loopback hop via URLProtocol.
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(!ErrorStubProtocol.didFire)
        #expect(ErrorStubProtocol.capturedRequest == nil)
    }

    @Test func reportEnabledTrueFiresPostToErrorEndpoint() async throws {
        // Positive case: with the default `reportEnabled: true`, the
        // request leaves the SDK with the expected URL, method, and
        // body shape. Complements the DTO-encoding tests by pinning
        // the wire path end-to-end.
        ErrorStubProtocol.reset()
        let session = makeStubbedSession()
        let ctx = ErrorContext(
            adServerUrl: URL(string: "https://example.test")!,
            publisherToken: "tok",
            conversationId: "conv",
            userId: "user",
            bidId: "bid"
        )

        ErrorCapture.capture(
            message: "boom",
            stack: "trace",
            context: ctx,
            session: session
        )

        await waitFor { ErrorStubProtocol.didFire }
        let request = try #require(ErrorStubProtocol.capturedRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/error")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(ErrorStubProtocol.capturedBody)
        let dict = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(dict["error"] as? String == "boom")
        #expect(dict["stack"] as? String == "trace")
        let additionalData = try #require(dict["additionalData"] as? [String: Any])
        #expect(additionalData["publisherToken"] as? String == "tok")
        #expect(additionalData["bidId"] as? String == "bid")
    }
}
