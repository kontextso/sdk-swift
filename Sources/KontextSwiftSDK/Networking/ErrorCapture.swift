import Foundation

/// Context for error capture requests.
///
/// All fields except `adServerUrl` are optional — `/init` failures
/// happen before a session is established and only need the URL;
/// `Ad`-side failures populate `bidId` when a bid has been resolved.
struct ErrorContext: Sendable {
    let adServerUrl: String
    let publisherToken: String?
    let conversationId: String?
    let userId: String?
    let bidId: String?

    init(
        adServerUrl: String,
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
        reportEnabled: Bool = true
    ) {
        capture(
            message: error.localizedDescription,
            stack: source ?? String(describing: error),
            context: context,
            reportEnabled: reportEnabled
        )
    }

    /// Sends an error report with a custom message.
    static func capture(
        message: String,
        stack: String? = nil,
        context: ErrorContext?,
        reportEnabled: Bool = true
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

        guard let url = URL(string: "\(adServerUrl)/error") else { return }

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

        // Fire-and-forget — match Init/Preload's async URLSession idiom.
        Task { try? await URLSession.shared.data(for: request) }
    }
}
