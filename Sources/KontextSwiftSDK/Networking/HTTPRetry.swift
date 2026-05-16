import Foundation

/// Errors thrown by `HTTPRetry.fetch` for retry-loop outcomes that
/// don't map cleanly onto a `URLError`.
enum HTTPRetryError: Error, Equatable, Sendable {
    /// HTTP 429 (rate limited) — retried internally; surfaces only after
    /// retries are exhausted on a 429-only response stream.
    case rateLimited(statusCode: Int)
}

/// HTTP fetch with exponential-backoff retries on transient failures.
///
/// Retry policy mirrors `sdk-js/src/utils/request.ts`:
/// - **Network errors** (URLError except `.cancelled`) → retried
/// - **HTTP 429** (rate limited) → retried
/// - **HTTP 5xx** → returned as-is (caller decides; matches sdk-js)
/// - **HTTP 4xx** → returned as-is
///
/// The total request timeout is whatever the caller set on
/// `request.timeoutInterval` and applies to each individual attempt
/// (URLSession enforces it per-call).
///
/// Cooperative cancellation: checks `Task.checkCancellation()` at the
/// top of each attempt and inside the backoff sleep, so the calling
/// task's cancellation is honored within ~1 backoff window at most.
enum HTTPRetry {

    /// Backoff sleep, injectable for tests. Production uses
    /// `Task.sleep(nanoseconds:)`; tests substitute a recorder so
    /// timing assertions can run without real-time sleeps (wall-clock
    /// timing on shared CI runners is too noisy for tight bounds).
    typealias SleepFn = @Sendable (UInt64) async throws -> Void

    static let defaultSleep: SleepFn = { try await Task.sleep(nanoseconds: $0) }

    static func fetch(
        request: URLRequest,
        session: URLSession = .shared,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffFactor: Double = 2.0,
        sleep: SleepFn = HTTPRetry.defaultSleep
    ) async throws -> (Data, URLResponse) {
        precondition(maxRetries >= 0, "HTTPRetry.fetch: maxRetries must be non-negative")

        for attempt in 0...maxRetries {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0

                // 429 enters the retry path via a typed throw.
                // 4xx and 5xx are returned as-is (matches sdk-js).
                if status == 429 {
                    throw HTTPRetryError.rateLimited(statusCode: status)
                }

                return (data, response)
            } catch {
                if !isRetryable(error: error) || attempt == maxRetries {
                    throw error
                }

                let delay = baseDelay * pow(backoffFactor, Double(attempt))
                try await sleep(UInt64(delay * 1_000_000_000))
            }
        }

        // The for-range exhausts only when the loop body never returns or
        // throws — which can't happen given the catch block always either
        // throws or continues. The compiler can't prove this, so trap.
        fatalError("HTTPRetry.fetch fell through the retry loop without returning or throwing")
    }

    /// Whether an error from a single attempt should trigger another retry.
    private static func isRetryable(error: Error) -> Bool {
        // 429 is a typed retry signal we synthesize ourselves.
        if case HTTPRetryError.rateLimited = error {
            return true
        }
        // URLErrors are transient network failures — retry except when
        // the caller cancelled the task.
        if let urlError = error as? URLError {
            return urlError.code != .cancelled
        }
        // CancellationError + everything else → don't retry, propagate.
        return false
    }
}
