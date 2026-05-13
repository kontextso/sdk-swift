import Foundation
@testable import KontextSwiftSDK
import Testing

/// Captures every `URLRequest` handed to a stubbed `URLSession` so
/// network-leg assertions can verify that `DebugCapture.capture(...)`
/// actually fires a POST with the expected shape. Carries
/// process-global mutable state, so the suite that uses it must run
/// serialised.
private final class DebugStubProtocol: URLProtocol {

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
        DebugStubProtocol.capturedRequest = request
        if let body = request.httpBody {
            DebugStubProtocol.capturedBody = body
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
            DebugStubProtocol.capturedBody = data
        }
        DebugStubProtocol.didFire = true

        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.test/debug")!,
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
    config.protocolClasses = [DebugStubProtocol.self]
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
struct DebugCaptureTests {

    // MARK: - DebugContext

    @Test func debugContextStoresAllFields() {
        let ctx = DebugContext(
            adServerUrl: URL(string: "https://example.com")!,
            publisherToken: "tok-123",
            conversationId: "conv-456",
            userId: "user-789",
            sessionId: "sess-abc"
        )

        #expect(ctx.adServerUrl == URL(string: "https://example.com"))
        #expect(ctx.publisherToken == "tok-123")
        #expect(ctx.conversationId == "conv-456")
        #expect(ctx.userId == "user-789")
        #expect(ctx.sessionId == "sess-abc")
    }

    @Test func debugContextAllowsNilOptionalFields() {
        let ctx = DebugContext(adServerUrl: URL(string: "https://example.com")!)

        #expect(ctx.publisherToken == nil)
        #expect(ctx.conversationId == nil)
        #expect(ctx.userId == nil)
        #expect(ctx.sessionId == nil)
    }

    // MARK: - capture doesn't crash

    @Test func captureWithNilDataDoesNotCrash() {
        // Fire-and-forget: any encoding/network failure must be
        // swallowed. Verifies the nil-data branch.
        DebugCapture.capture(name: "Session: pinged", context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!,
            publisherToken: "tok",
            userId: "user-1",
            sessionId: "sess-1"
        ))
    }

    @Test func captureWithJSONShapedDataDoesNotCrash() {
        DebugCapture.capture(name: "Session: probe", data: ["k": "v"], context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!
        ))
    }

    @Test func captureWithNonJSONDataDoesNotCrash() {
        // Non-JSON values (errors, structs) fall back to
        // `String(describing:)` rather than dropping the field.
        struct Probe { let id = 1 }
        DebugCapture.capture(name: "Session: probe", data: Probe(), context: DebugContext(
            adServerUrl: URL(string: "https://server.megabrain.co")!
        ))
    }

    // MARK: - DTO encoding

    @Test func dtoEncodesAllFields() throws {
        let dto = DebugRequestDTO(
            name: "Session: probe",
            data: #"{"k":"v"}"#,
            additionalData: DebugRequestDTO.AdditionalData(
                publisherToken: "tok",
                conversationId: "conv",
                userId: "usr",
                sessionId: "sess",
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["name"] as? String == "Session: probe")
        #expect(decoded?["data"] as? String == #"{"k":"v"}"#)

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?["publisherToken"] as? String == "tok")
        #expect(additionalData?["conversationId"] as? String == "conv")
        #expect(additionalData?["userId"] as? String == "usr")
        #expect(additionalData?["sessionId"] as? String == "sess")

        let sdk = additionalData?["sdk"] as? [String: Any]
        #expect(sdk?["name"] as? String == SDKInfo.current.name)
        #expect(sdk?["platform"] as? String == SDKInfo.current.platform)
    }

    @Test func dtoEncodesNilOptionalsAsAbsentKeys() throws {
        // Mirrors ErrorRequestDTO's contract: nil-valued optionals are
        // dropped from the wire so the shape stays compatible with
        // sdk-js / sdk-kotlin.
        let dto = DebugRequestDTO(
            name: "msg",
            data: nil,
            additionalData: DebugRequestDTO.AdditionalData(
                publisherToken: nil,
                conversationId: nil,
                userId: nil,
                sessionId: nil,
                sdk: SDKInfo.current.toDTO()
            )
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["name"] as? String == "msg")
        #expect(decoded?.keys.contains("data") == false)

        let additionalData = decoded?["additionalData"] as? [String: Any]
        #expect(additionalData?.keys.contains("publisherToken") == false)
        #expect(additionalData?.keys.contains("conversationId") == false)
        #expect(additionalData?.keys.contains("userId") == false)
        #expect(additionalData?.keys.contains("sessionId") == false)
        #expect(additionalData?["sdk"] != nil)
    }

    @Test func urlFormationUsesDebugEndpoint() {
        // Exercises the same `appendingPathComponent` path
        // `DebugCapture.capture` uses to build the endpoint URL.
        let url = URL(string: "https://custom.server.com")!.appendingPathComponent("debug")
        #expect(url.absoluteString == "https://custom.server.com/debug")
    }

    // MARK: - Network leg

    @Test func captureFiresPostToDebugEndpoint() async throws {
        // Positive case: the request leaves the SDK with the expected
        // URL, method, headers, and body shape. Complements the
        // DTO-encoding tests by pinning the wire path end-to-end.
        DebugStubProtocol.reset()
        let session = makeStubbedSession()
        let ctx = DebugContext(
            adServerUrl: URL(string: "https://example.test")!,
            publisherToken: "tok",
            conversationId: "conv",
            userId: "user",
            sessionId: "sess"
        )

        DebugCapture.capture(
            name: "Session: probe",
            data: ["k": "v"],
            context: ctx,
            session: session
        )

        await waitFor { DebugStubProtocol.didFire }
        let request = try #require(DebugStubProtocol.capturedRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/debug")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(DebugStubProtocol.capturedBody)
        let dict = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(dict["name"] as? String == "Session: probe")
        #expect(dict["data"] as? String == #"{"k":"v"}"#)

        let additionalData = try #require(dict["additionalData"] as? [String: Any])
        #expect(additionalData["publisherToken"] as? String == "tok")
        #expect(additionalData["conversationId"] as? String == "conv")
        #expect(additionalData["userId"] as? String == "user")
        #expect(additionalData["sessionId"] as? String == "sess")
        #expect(additionalData["sdk"] != nil)
    }
}
