import Foundation
@testable import KontextSwiftSDK
import Testing

/// Drives `HTTPRetry.fetch` against a stubbed `URLSession` so each
/// retry-policy branch (200, 4xx, 5xx, 429, network error, cancellation)
/// can be verified in isolation, without hitting the network.
///
/// Serialized because `StubProtocol` carries process-global mutable state
/// (`script` + `attempts`) — Swift Testing's default parallel execution
/// would interleave reset/set/read between tests.
@Suite(.serialized)
struct HTTPRetryTests {

    // MARK: - Stub plumbing

    /// `URLProtocol` subclass that lets the test enumerate stubbed
    /// responses. Each `startLoading` call pulls the next scripted
    /// outcome off the queue, so a multi-attempt retry can simulate
    /// "fail twice, then succeed" without spinning up a real server.
    /// One scripted outcome per attempt. `error != nil` simulates a
    /// connection failure; otherwise the protocol returns an
    /// `HTTPURLResponse` with the given status and body.
    struct StubResponse {
        let status: Int
        let data: Data
        let error: Error?

        static func ok(_ body: String = "") -> StubResponse {
            StubResponse(status: 200, data: Data(body.utf8), error: nil)
        }

        static func status(_ code: Int, body: String = "") -> StubResponse {
            StubResponse(status: code, data: Data(body.utf8), error: nil)
        }

        static func networkError(_ error: URLError) -> StubResponse {
            StubResponse(status: 0, data: Data(), error: error)
        }
    }

    final class StubProtocol: URLProtocol {

        nonisolated(unsafe) static var script: [StubResponse] = []
        nonisolated(unsafe) static var attempts = 0

        static func reset() {
            script = []
            attempts = 0
        }

        // swiftlint:disable static_over_final_class
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        // swiftlint:enable static_over_final_class

        override func startLoading() {
            let index = StubProtocol.attempts
            StubProtocol.attempts += 1

            guard index < StubProtocol.script.count else {
                client?.urlProtocol(self, didFailWithError: URLError(.unknown))
                return
            }

            let stub = StubProtocol.script[index]

            if let error = stub.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }

            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.test")!,
                statusCode: stub.status,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func makeStubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://example.test/preload")!)
    }

    /// Tiny backoff so multi-attempt tests don't spend seconds sleeping.
    private let fastBackoff: (TimeInterval, Double) = (0.001, 1.0)

    // MARK: - 200 / 2xx — happy path

    @Test func returnsImmediatelyOn200() async throws {
        StubProtocol.reset()
        StubProtocol.script = [.ok("ok")]
        let session = makeStubbedSession()

        let (data, response) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(StubProtocol.attempts == 1)
    }

    // MARK: - 4xx — returned as-is, NOT retried

    @Test func returns4xxAsIsWithoutRetry() async throws {
        StubProtocol.reset()
        StubProtocol.script = [.status(404, body: "not found")]
        let session = makeStubbedSession()

        let (_, response) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect((response as? HTTPURLResponse)?.statusCode == 404)
        #expect(StubProtocol.attempts == 1)
    }

    // MARK: - 5xx — returned as-is, NOT retried (matches sdk-js)

    @Test func returns5xxAsIsWithoutRetry() async throws {
        StubProtocol.reset()
        StubProtocol.script = [.status(503, body: "unavailable")]
        let session = makeStubbedSession()

        let (_, response) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect((response as? HTTPURLResponse)?.statusCode == 503)
        // sdk-js parity: 5xx is returned as-is, no retries.
        #expect(StubProtocol.attempts == 1)
    }

    // MARK: - 429 — IS retried

    @Test func retriesOn429ThenSucceeds() async throws {
        StubProtocol.reset()
        StubProtocol.script = [
            .status(429),
            .status(429),
            .ok("recovered"),
        ]
        let session = makeStubbedSession()

        let (data, response) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "recovered")
        #expect(StubProtocol.attempts == 3)
    }

    @Test func exhausts429RetriesThenThrows() async {
        StubProtocol.reset()
        StubProtocol.script = Array(repeating: .status(429), count: 4) // attempt 0 + 3 retries
        let session = makeStubbedSession()

        await #expect(throws: HTTPRetryError.rateLimited(statusCode: 429)) {
            try await HTTPRetry.fetch(
                request: makeRequest(),
                session: session,
                maxRetries: 3,
                baseDelay: fastBackoff.0,
                backoffFactor: fastBackoff.1
            )
        }
        #expect(StubProtocol.attempts == 4)
    }

    // MARK: - Network errors — IS retried

    @Test func retriesOnNetworkErrorThenSucceeds() async throws {
        StubProtocol.reset()
        StubProtocol.script = [
            .networkError(URLError(.notConnectedToInternet)),
            .networkError(URLError(.timedOut)),
            .ok("late ok"),
        ]
        let session = makeStubbedSession()

        let (data, _) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect(String(data: data, encoding: .utf8) == "late ok")
        #expect(StubProtocol.attempts == 3)
    }

    @Test func exhaustsNetworkRetriesThenThrows() async {
        StubProtocol.reset()
        StubProtocol.script = Array(repeating: .networkError(URLError(.timedOut)), count: 4)
        let session = makeStubbedSession()

        await #expect(throws: URLError.self) {
            try await HTTPRetry.fetch(
                request: makeRequest(),
                session: session,
                maxRetries: 3,
                baseDelay: fastBackoff.0,
                backoffFactor: fastBackoff.1
            )
        }
        #expect(StubProtocol.attempts == 4)
    }

    // MARK: - Mixed: network error then 5xx (which is returned as-is)

    @Test func networkErrorThen5xxStopsRetrying() async throws {
        StubProtocol.reset()
        StubProtocol.script = [
            .networkError(URLError(.notConnectedToInternet)),
            .status(502, body: "bad gateway"),
        ]
        let session = makeStubbedSession()

        let (_, response) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        // First attempt is a network error → retried.
        // Second attempt returns 502 → not a retryable status, returned as-is.
        #expect((response as? HTTPURLResponse)?.statusCode == 502)
        #expect(StubProtocol.attempts == 2)
    }

    // MARK: - maxRetries = 0 (single-attempt mode)

    @Test func maxRetriesZeroRunsOnceOnSuccess() async throws {
        StubProtocol.reset()
        StubProtocol.script = [.ok("once")]
        let session = makeStubbedSession()

        let (data, _) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 0,
            baseDelay: fastBackoff.0,
            backoffFactor: fastBackoff.1
        )

        #expect(String(data: data, encoding: .utf8) == "once")
        #expect(StubProtocol.attempts == 1)
    }

    @Test func maxRetriesZeroRunsOnceOnRetryableError() async {
        StubProtocol.reset()
        // Even though the error is retryable, with maxRetries=0 we get
        // exactly one attempt and then propagate the error.
        StubProtocol.script = [.networkError(URLError(.timedOut))]
        let session = makeStubbedSession()

        await #expect(throws: URLError.self) {
            try await HTTPRetry.fetch(
                request: makeRequest(),
                session: session,
                maxRetries: 0,
                baseDelay: fastBackoff.0,
                backoffFactor: fastBackoff.1
            )
        }
        #expect(StubProtocol.attempts == 1)
    }

    // MARK: - Backoff timing

    /// Records each `sleep` call's nanosecond duration so timing
    /// assertions can run against the formula directly, with no
    /// wall-clock noise. Drop-in for the default `Task.sleep`.
    final class SleepRecorder: @unchecked Sendable {
        // @unchecked: only used inside a single test's call-stack — no
        // concurrent writers. Avoids forcing every test through an
        // actor for a glorified array.
        var calls: [UInt64] = []
        func sleep(_ nanos: UInt64) async throws { calls.append(nanos) }
    }

    @Test func appliesExponentialBackoffBetweenAttempts() async {
        // Verifies the backoff *formula* (delay = base * factor^attempt)
        // by recording each sleep call's requested duration. Decoupled
        // from wall-clock so the test can't flake on slow CI runners
        // (the prior wall-clock variant was the chronic CI flake of
        // this suite — too noisy under shared-runner load even at a
        // 10s upper bound).
        StubProtocol.reset()
        StubProtocol.script = Array(repeating: .networkError(URLError(.timedOut)), count: 4)
        let session = makeStubbedSession()

        let baseDelay: TimeInterval = 0.05
        let backoffFactor = 2.0
        let recorder = SleepRecorder()

        await #expect(throws: URLError.self) {
            try await HTTPRetry.fetch(
                request: makeRequest(),
                session: session,
                maxRetries: 3,
                baseDelay: baseDelay,
                backoffFactor: backoffFactor,
                sleep: { try await recorder.sleep($0) }
            )
        }

        // 4 attempts → 3 backoff sleeps (final attempt throws without
        // sleeping). Expected pattern: 50ms, 100ms, 200ms.
        #expect(StubProtocol.attempts == 4)
        let expected: [UInt64] = [
            UInt64(0.05 * 1_000_000_000),
            UInt64(0.10 * 1_000_000_000),
            UInt64(0.20 * 1_000_000_000),
        ]
        #expect(recorder.calls == expected, "backoff sequence drifted: \(recorder.calls)")
    }

    @Test func successOnFirstAttemptDoesNotSleep() async throws {
        // Behavior assertion (not timing): no sleep calls happen on
        // first-attempt success. Wall-clock variant flaked on slow
        // CI runners; the recorder makes the assertion exact.
        StubProtocol.reset()
        StubProtocol.script = [.ok("immediate")]
        let session = makeStubbedSession()
        let recorder = SleepRecorder()

        let (data, _) = try await HTTPRetry.fetch(
            request: makeRequest(),
            session: session,
            maxRetries: 3,
            baseDelay: 5.0,
            backoffFactor: 2.0,
            sleep: { try await recorder.sleep($0) }
        )

        #expect(String(data: data, encoding: .utf8) == "immediate")
        #expect(recorder.calls.isEmpty, "no sleep should fire on first-attempt success: \(recorder.calls)")
    }

    // MARK: - Cancellation

    @Test func cancellationStopsRetryLoop() async {
        StubProtocol.reset()
        StubProtocol.script = Array(repeating: .networkError(URLError(.timedOut)), count: 4)
        let session = makeStubbedSession()

        let task = Task<Void, Error> {
            _ = try await HTTPRetry.fetch(
                request: makeRequest(),
                session: session,
                maxRetries: 3,
                // Long backoff so the task spends most of its time in
                // `Task.sleep`, where cancellation lands deterministically.
                baseDelay: 0.5,
                backoffFactor: 1.0
            )
        }

        // Let the task start and reach a suspension point; exact moment
        // is platform-dependent, so don't assert on attempt count.
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        // The throw could be CancellationError (from Task.checkCancellation
        // or Task.sleep) or URLError(.cancelled) (if URLSession was mid-call
        // when cancellation arrived) — both are valid.
        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }
}
