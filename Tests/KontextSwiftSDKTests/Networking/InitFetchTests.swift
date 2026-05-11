import Foundation
@testable import KontextSwiftSDK
import Testing

/// Drives `Init.fetch` against a stubbed `URLSession`. Pins the
/// status-code branches (200 / 2xx / 204 / non-2xx / empty-body /
/// decode-failure / cancellation) without hitting the network.
///
/// Serialized because `InitStubProtocol` carries process-global
/// mutable state (`script` + `attempts`).
@Suite(.serialized)
struct InitFetchTests {

    // MARK: - Stub plumbing

    struct StubResponse {
        let status: Int
        let data: Data
        let error: Error?

        static func ok(_ body: String = "{}") -> StubResponse {
            StubResponse(status: 200, data: Data(body.utf8), error: nil)
        }

        static func status(_ code: Int, body: String = "") -> StubResponse {
            StubResponse(status: code, data: Data(body.utf8), error: nil)
        }

        static func cancelled() -> StubResponse {
            StubResponse(status: 0, data: Data(), error: URLError(.cancelled))
        }

        static func networkError(_ code: URLError.Code = .timedOut) -> StubResponse {
            StubResponse(status: 0, data: Data(), error: URLError(code))
        }
    }

    final class InitStubProtocol: URLProtocol {

        nonisolated(unsafe) static var script: [StubResponse] = []
        nonisolated(unsafe) static var attempts = 0
        /// Last request observed by the stub. URLSession moves the body
        /// from `httpBody` into `httpBodyStream` before handing the
        /// request to the protocol, so the stub also captures the
        /// drained body bytes (`capturedBody`) for assertions.
        nonisolated(unsafe) static var capturedRequest: URLRequest?
        nonisolated(unsafe) static var capturedBody: Data?

        static func reset() {
            script = []
            attempts = 0
            capturedRequest = nil
            capturedBody = nil
        }

        // swiftlint:disable static_over_final_class
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        // swiftlint:enable static_over_final_class

        override func startLoading() {
            // Capture for shape assertions in tests.
            InitStubProtocol.capturedRequest = request
            InitStubProtocol.capturedBody = drainBody(from: request)

            let index = InitStubProtocol.attempts
            InitStubProtocol.attempts += 1

            guard index < InitStubProtocol.script.count else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }

            let stub = InitStubProtocol.script[index]

            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.test/init")!,
                statusCode: stub.status,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

        /// Reads the request body via either `httpBody` (if present)
        /// or `httpBodyStream` (URLSession's preferred surface for
        /// outbound bodies) into a single `Data`.
        private func drainBody(from request: URLRequest) -> Data? {
            if let body = request.httpBody { return body }
            guard let stream = request.httpBodyStream else { return nil }
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
            return data
        }
    }

    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InitStubProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeConfig() -> ResolvedConfig {
        ResolvedConfig(
            publisherToken: "tok",
            userId: "u1",
            conversationId: "c1",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: "https://example.test",
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
    }

    // MARK: - Request shape

    @Test func sendsExpectedHeadersAndUrl() async throws {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.ok(#"{"enabled": true}"#)]
        let session = makeStubbedSession()

        _ = await Init.fetch(config: makeConfig(), session: session)

        let request = try #require(InitStubProtocol.capturedRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/init")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Kontextso-Publisher-Token") == "tok")
    }

    @Test func sendsExpectedBodyShape() async throws {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.ok(#"{"enabled": true}"#)]
        let session = makeStubbedSession()

        _ = await Init.fetch(config: makeConfig(), session: session)

        let body = try #require(InitStubProtocol.capturedBody)
        let dict = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(dict["publisherToken"] as? String == "tok")
        // userId is sent on every /init so the server can target
        // per-user toggles (reportErrors / reportDebug) in the response.
        #expect(dict["userId"] as? String == "u1")

        let sdk = try #require(dict["sdk"] as? [String: Any])
        #expect(sdk["name"] as? String == "sdk-swift")
        #expect(sdk["platform"] as? String == "ios")
        #expect((sdk["version"] as? String)?.isEmpty == false)

        // app and skan are sent on every /init — even with empty values
        let app = try #require(dict["app"] as? [String: Any])
        #expect(app["bundleId"] is String)
        #expect(app["version"] is String)

        let skan = try #require(dict["skan"] as? [String: Any])
        #expect(skan["items"] is [Any])
    }

    // MARK: - Success paths

    @Test func returnsDecodedResponseOn200() async {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.ok(#"{"preloadTimeout": 8000, "enabled": true}"#)]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result?.preloadTimeout == 8000)
        #expect(result?.enabled == true)
    }

    @Test func returnsDecodedResponseOnOther2xx() async {
        // sdk-js's `response.ok` accepts any 2xx — sdk-swift now matches.
        // Server isn't expected to return 201 for /init today, but the
        // contract is "any 2xx with a parseable body succeeds".
        InitStubProtocol.reset()
        InitStubProtocol.script = [.status(201, body: #"{"enabled": true}"#)]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result?.enabled == true)
    }

    // MARK: - "Not actually a response" paths

    @Test func returnsNilOn204NoContent() async {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.status(204)]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    @Test func returnsNilOnEmptyBodyAt200() async {
        // 200 with empty body — server semantically said "ok" but didn't
        // give us anything to apply. Treated like 204; no decode attempt;
        // no error reported.
        InitStubProtocol.reset()
        InitStubProtocol.script = [.ok("")]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    @Test func returnsNilOnEmptyBodyAtOther2xx() async {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.status(205)]  // 205 = Reset Content, body empty by spec
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    // MARK: - Failure paths

    @Test func returnsNilOn4xx() async {
        InitStubProtocol.reset()
        InitStubProtocol.script = [.status(400, body: #"{"error":"bad request"}"#)]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    @Test func returnsNilOn5xx() async {
        // HTTPRetry's policy returns 5xx as-is (no retry); fetch sees
        // it as a non-2xx and returns nil.
        InitStubProtocol.reset()
        InitStubProtocol.script = [.status(500, body: "internal server error")]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    @Test func returnsNilOnDecodeFailure() async {
        // 200 + malformed JSON — JSONDecoder throws, caught, returns nil.
        // (ErrorCapture is fired here in production; we don't assert that
        // since there's no test hook into the fire-and-forget reporter.)
        InitStubProtocol.reset()
        InitStubProtocol.script = [.ok("not valid json {{{")]
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    // MARK: - Cancellation

    @Test func returnsNilOnURLErrorCancelled() async {
        // URLSession surfaces Task cancellation as URLError.cancelled.
        // fetch's dedicated catch arm filters it out of ErrorCapture.
        // Stubbing the error directly verifies the catch arm without
        // racing against a real Task.cancel during synchronous-stub
        // response. Multiple entries because HTTPRetry retries on
        // network errors; cancelled keeps surfacing the same error
        // until the retry policy gives up.
        InitStubProtocol.reset()
        InitStubProtocol.script = Array(repeating: .cancelled(), count: 4)
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }

    @Test func returnsNilOnGenericNetworkError() async {
        // Non-cancellation network errors hit the catch-all arm —
        // would fire ErrorCapture in production. Verify return value
        // is still nil (the "never throws" contract).
        InitStubProtocol.reset()
        InitStubProtocol.script = Array(repeating: .networkError(.timedOut), count: 4)
        let session = makeStubbedSession()

        let result = await Init.fetch(config: makeConfig(), session: session)

        #expect(result == nil)
    }
}
