import Foundation

/// Context for error capture requests.
///
/// All fields except `adServerUrl` are optional — `/init` failures
/// happen before a session is established and only need the URL;
/// `Ad`-side failures populate `bidId` when a bid has been resolved.
struct ErrorContext: Sendable {
    let adServerUrl: URL
    let publisherToken: String?
    let conversationId: String?
    let userId: String?
    let bidId: String?

    init(
        adServerUrl: URL,
        publisherToken: String? = nil,
        conversationId: String? = nil,
        userId: String? = nil,
        bidId: String? = nil
    ) {
        self.adServerUrl = adServerUrl
        self.publisherToken = publisherToken
        self.conversationId = conversationId
        self.userId = userId
        self.bidId = bidId
    }
}

/// Reports SDK errors to the ad server for diagnostics.
///
/// Two-leg behaviour: the local leg (`print`) always runs so a publisher
/// running in the simulator / a debugger sees the error in real time;
/// the network leg (`POST /error`) is gated by `reportEnabled` so the
/// server can flip a feedback-loop firehose off per-user via the
/// `/init` response (`reportErrors: false`). Defaults to `true` for
/// pre-init failures (e.g. `/init` itself), matching the
/// `InitResponseDTO.reportErrors` default.
///
/// Fire-and-forget on the network leg: encoding/network errors during
/// reporting are silently swallowed so a failed report never disrupts
/// the publisher's app. Mirrors the typed-DTO + JSONEncoder pattern
/// used by `/init` and `/preload`.
enum ErrorCapture {
    /// Sends an error report to the `/error` endpoint.
    ///
    /// - Parameters:
    ///   - error: The error to report.
    ///   - source: Optional short label identifying the failing
    ///     operation (e.g. `"ad-om-session-creation"`). When set,
    ///     overrides the wire `stack` field — server-side log readers
    ///     usually want the call-site label, not a stringified Swift
    ///     error. Mirrors sdk-js's `captureError(err, componentStack)`
    ///     parameter.
    ///   - context: Optional session / bid context for attribution.
    ///   - reportEnabled: When `false`, the network POST is suppressed
    ///     while the local log still runs. Defaults to `true` so
    ///     pre-init call sites (which can't know the server flag yet)
    ///     stay consistent with the documented `reportErrors: true`
    ///     default.
    static func capture(
        _ error: Error,
        source: String? = nil,
        context: ErrorContext?,
        reportEnabled: Bool = true,
        session: URLSession = .shared
    ) {
        capture(
            message: error.localizedDescription,
            stack: source ?? String(describing: error),
            context: context,
            reportEnabled: reportEnabled,
            session: session
        )
    }

    /// Sends an error report with a custom message.
    ///
    /// `session` is injectable purely for tests — production calls
    /// always use `URLSession.shared` via the default.
    static func capture(
        message: String,
        stack: String? = nil,
        context: ErrorContext?,
        reportEnabled: Bool = true,
        session: URLSession = .shared
    ) {
        // Local leg: always runs. Mirrors `console.error` in sdk-js
        // and `Log.e` in sdk-kotlin so a publisher debugging in the
        // simulator / via Xcode console sees the error inline.
        // Prefix is grep-friendly and identifies the SDK in mixed
        // app logs.
        let stackLine = stack.map { "\n  \($0)" } ?? ""
        print("[KontextAds] error: \(message)\(stackLine)")

        guard reportEnabled else { return }

        let adServerUrl = context?.adServerUrl ?? Constants.defaultAdServerUrl
        let url = adServerUrl.appendingPathComponent("error")

        let dto = ErrorRequestDTO(
            error: message,
            stack: stack,
            additionalData: ErrorRequestDTO.AdditionalData(
                publisherToken: context?.publisherToken,
                conversationId: context?.conversationId,
                userId: context?.userId,
                bidId: context?.bidId,
                sdk: SDKInfo.current.toDTO()
            )
        )

        guard let body = try? JSONEncoder().encode(dto) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // Shorter than init/preload — fire-and-forget, don't keep
        // many URLSession tasks alive on a slow network.
        request.timeoutInterval = Constants.errorReportTimeoutMs / 1000

        // Detached so the request survives the caller's lifetime —
        // a plain `Task { ... }` inherits the caller's actor, which
        // means destroying a Session mid-flight cancels the diagnostic
        // POST and the report is lost. `URLSession.shared` is process-wide,
        // so it's safe to detach from the actor context. Mirrors
        // sdk-kotlin's process-wide `SupervisorJob + Dispatchers.IO`
        // scope and sdk-js's `keepalive: true`.
        Task.detached { try? await session.data(for: request) }
    }
}
