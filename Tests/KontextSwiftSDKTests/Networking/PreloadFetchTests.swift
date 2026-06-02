import Foundation
@testable import KontextSwiftSDK
import Testing

/// Drives `Preload.requestAd` against a stubbed `URLSession`. Pins the
/// response-shape branches (success / skip / error / permanent-error /
/// 4xx / 5xx / decode-failure) plus request-shape (URL / headers / body)
/// without hitting the network.
///
/// `@MainActor` because `Preload` is main-actor-isolated. Serialized
/// because `PreloadStubProtocol` carries process-global mutable state
/// (`script` + `attempts`).
@MainActor
@Suite(.serialized)
struct PreloadFetchTests {

    // MARK: - Stub plumbing

    struct StubResponse {
        let status: Int
        let data: Data
        let error: Error?
        /// Stub never finishes loading — used to exercise cancellation.
        let hangsForever: Bool

        static func ok(_ body: String = "{}") -> StubResponse {
            StubResponse(status: 200, data: Data(body.utf8), error: nil, hangsForever: false)
        }

        static func status(_ code: Int, body: String = "") -> StubResponse {
            StubResponse(status: code, data: Data(body.utf8), error: nil, hangsForever: false)
        }

        static func hang() -> StubResponse {
            StubResponse(status: 0, data: Data(), error: nil, hangsForever: true)
        }
    }

    final class PreloadStubProtocol: URLProtocol {

        nonisolated(unsafe) static var script: [StubResponse] = []
        nonisolated(unsafe) static var attempts = 0
        /// URLSession moves `httpBody` to `httpBodyStream` before handing
        /// the request to URLProtocol — capture both surfaces.
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
            PreloadStubProtocol.capturedRequest = request
            PreloadStubProtocol.capturedBody = drainBody(from: request)

            let index = PreloadStubProtocol.attempts
            PreloadStubProtocol.attempts += 1

            guard index < PreloadStubProtocol.script.count else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }

            let stub = PreloadStubProtocol.script[index]

            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            if stub.hangsForever {
                // Don't call urlProtocolDidFinishLoading — the URLSession
                // task will hang until Task cancellation aborts it.
                return
            }

            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.test/preload")!,
                statusCode: stub.status,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}

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

    // MARK: - Helpers

    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PreloadStubProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeConfig() -> ResolvedConfig {
        ResolvedConfig(
            publisherToken: "tok",
            userId: "u1",
            conversationId: "c1",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: URL(string: "https://example.test")!,
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

    private func makeParams(isDisabled: Bool = false) -> PreloadParams {
        PreloadParams(
            config: makeConfig(),
            sessionId: nil,
            timeout: 16000,
            isDisabled: isDisabled,
            advertisingId: nil,
            vendorId: nil
        )
    }

    private func makePreload() -> Preload {
        Preload(messages: [Message(id: "u1", role: .user, content: "Hello")])
    }

    // MARK: - Request shape

    @Test func sendsExpectedHeadersAndUrl() async throws {
        PreloadStubProtocol.reset()
        // Reply with a malformed body — we only care about the request side here.
        PreloadStubProtocol.script = [.ok("{}")]
        let session = makeStubbedSession()

        _ = await makePreload().requestAd(params: makeParams(), session: session)

        let request = try #require(PreloadStubProtocol.capturedRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.test/preload")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Kontextso-Publisher-Token") == "tok")
        #expect(request.value(forHTTPHeaderField: "Kontextso-Is-Disabled") == "0")
    }

    @Test func sendsIsDisabledHeaderWhenDisabled() async throws {
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok("{}")]
        let session = makeStubbedSession()

        _ = await makePreload().requestAd(params: makeParams(isDisabled: true), session: session)

        let request = try #require(PreloadStubProtocol.capturedRequest)
        #expect(request.value(forHTTPHeaderField: "Kontextso-Is-Disabled") == "1")
    }

    @Test func sendsExpectedBodyShape() async throws {
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok("{}")]
        let session = makeStubbedSession()

        _ = await makePreload().requestAd(params: makeParams(), session: session)

        let body = try #require(PreloadStubProtocol.capturedBody)
        let dict = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(dict["publisherToken"] as? String == "tok")
        #expect(dict["userId"] as? String == "u1")
        #expect(dict["conversationId"] as? String == "c1")
        #expect(dict["enabledPlacementCodes"] as? [String] == ["inlineAd"])

        let messages = try #require(dict["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["id"] as? String == "u1")

        // sdk + device + app are sent on every /preload
        #expect(dict["sdk"] is [String: Any])
        #expect(dict["device"] is [String: Any])
        #expect(dict["app"] is [String: Any])
    }

    // MARK: - Success path

    @Test func returnsSuccessOn200WithBids() async {
        let sessionId = UUID()
        let bidId = UUID()
        let body = """
        {
          "sessionId": "\(sessionId.uuidString)",
          "bids": [{"bidId": "\(bidId.uuidString)", "code": "inlineAd"}]
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .success(let bids, let returnedSessionId) = result else {
            Issue.record("Expected success, got \(result)")
            return
        }
        #expect(returnedSessionId == sessionId)
        #expect(bids.count == 1)
        #expect(bids[0].code == "inlineAd")
        #expect(bids[0].bidId == bidId)
    }

    @Test func filtersBidsByEnabledPlacementCodes() async {
        // Server returns a bid for an unmapped placement — should be filtered
        // out, and an empty matching-bid set surfaces to the publisher as
        // `noFill` (not silence). Mirrors the 204 path.
        let sessionId = UUID()
        let bidId = UUID()
        let body = """
        {
          "sessionId": "\(sessionId.uuidString)",
          "bids": [{"bidId": "\(bidId.uuidString)", "code": "popupAd"}]
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "No bids in response")
        #expect(disableSession == false)
        guard case .noFill(let data) = event else {
            Issue.record("Expected noFill event, got \(String(describing: event))")
            return
        }
        #expect(data.skipCode == "unfilled_bid")
    }

    // MARK: - Skip path

    @Test func returnsNoFillFailureOnSkip() async {
        let sessionId = UUID()
        let body = """
        {
          "sessionId": "\(sessionId.uuidString)",
          "skip": true,
          "skipCode": "no_inventory"
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Ad generation skipped")
        #expect(disableSession == false)
        guard case .noFill(let data) = event else {
            Issue.record("Expected noFill event, got \(String(describing: event))")
            return
        }
        #expect(data.skipCode == "no_inventory")
    }

    @Test func skipFailureCarriesServerSessionId() async {
        // The server returns a sessionId on skip / ads-disabled responses;
        // it must reach the failure so Session can persist it.
        let sessionId = UUID()
        let body = """
        {
          "sessionId": "\(sessionId.uuidString)",
          "bids": [],
          "skip": true,
          "skipCode": "ads_disabled"
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(isDisabled: true), session: session)

        guard case .failure(_, _, _, let returnedSessionId) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(returnedSessionId == sessionId)
    }

    @Test func noFillFailureCarriesServerSessionId() async {
        let sessionId = UUID()
        let body = """
        {
          "sessionId": "\(sessionId.uuidString)",
          "bids": []
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(_, _, _, let returnedSessionId) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(returnedSessionId == sessionId)
    }

    // MARK: - Error path (server-side, in 200 body)

    @Test func returnsErrorFailureOnErrCode() async {
        // 200 + errCode set — server-side ad generation error, not permanent.
        let body = """
        {
          "sessionId": "\(UUID().uuidString)",
          "errCode": "generation_failed"
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Ad generation skipped")
        #expect(disableSession == false)
        guard case .error(let data) = event else {
            Issue.record("Expected error event, got \(String(describing: event))")
            return
        }
        #expect(data.errCode == "generation_failed")
    }

    @Test func returnsDisableSessionOnPermanentError() async {
        let body = """
        {
          "sessionId": "\(UUID().uuidString)",
          "errCode": "publisher_disabled",
          "permanent": true
        }
        """
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok(body)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Session is disabled")
        #expect(disableSession == true)
        guard case .error(let data) = event else {
            Issue.record("Expected error event, got \(String(describing: event))")
            return
        }
        #expect(data.errCode == "publisher_disabled")
    }

    // MARK: - HTTP-level failures

    @Test func returnsNoFillOn204() async {
        // 204 = server explicitly opted out of returning a body
        // (publisher disabled / unknown). No decode attempt, no
        // ErrorCapture report. Publisher sees `noFill` so every
        // preload produces exactly one of filled/noFill/error.
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.status(204)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "No content")
        guard case .noFill(let data) = event else {
            Issue.record("Expected noFill event, got \(String(describing: event))")
            return
        }
        #expect(data.skipCode == "unfilled_bid")
        #expect(disableSession == false)
    }

    @Test func returnsFailureOn4xxWithEmptyBody() async {
        // Production servers may return non-JSON 4xx bodies. Preload must
        // route on status before attempting to decode — no false-positive
        // ErrorCapture report.
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.status(400)]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, _, _, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Ad generation skipped")
    }

    @Test func returnsFailureOn5xxWithEmptyBody() async {
        // HTTPRetry returns 5xx as-is (no retry for non-network errors);
        // Preload sees non-2xx and routes through errorFailure without
        // touching the body.
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.status(500, body: "internal server error")]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, _, _, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Ad generation skipped")
    }

    @Test func returnsFailureOnDecodeError() async {
        // 200 + malformed JSON — JSONDecoder throws, caught, routed to
        // handleError.
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.ok("not valid json {{{")]
        let session = makeStubbedSession()

        let result = await makePreload().requestAd(params: makeParams(), session: session)

        guard case .failure(let reason, _, _, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Error preloading ads")
    }

    // MARK: - Cancellation

    @Test func cancelAbortsInFlightRequest() async throws {
        // Stub hangs forever — the only way out is `cancel()` aborting the
        // URLSession task. Verifies sdk-js-parity: cancel must short-circuit
        // the network leg, not just drop the response post-hoc.
        PreloadStubProtocol.reset()
        PreloadStubProtocol.script = [.hang()]
        let session = makeStubbedSession()

        let preload = makePreload()

        let resultTask = Task { await preload.requestAd(params: makeParams(), session: session) }

        // Let the request reach URLSession before cancelling; otherwise
        // we'd be testing pre-flight cancellation which is a different path.
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms

        let start = Date()
        preload.cancel()
        let result = await resultTask.value
        let elapsed = Date().timeIntervalSince(start)

        // Generous bound — sdk-js aborts in ms, but URLSession task-cancel
        // can take a beat. A real "ignored cancel" would block on the
        // request timeout (15s+). The budget is loose to account for slow
        // CI runners (GitHub Actions macOS runners regularly see
        // multi-second URLSession-cancel propagation under load); the
        // test still catches a genuinely ignored cancel because that
        // case blocks on the 15s+ request timeout.
        #expect(elapsed < 10.0, "cancel should abort fast, took \(elapsed)s")

        guard case .failure(let reason, let event, let disableSession, _) = result else {
            Issue.record("Expected failure, got \(result)")
            return
        }
        #expect(reason == "Cancelled")
        #expect(event == nil)
        #expect(disableSession == false)
    }
}
