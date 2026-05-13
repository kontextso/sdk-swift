import Foundation

/// Context for debug capture requests.
///
/// Parallel to `ErrorContext` minus `bidId` — debug events are
/// session-scoped, not bid-scoped. `sessionId` is included because
/// debug forwarding is enabled on a live session and the id lets the
/// server filter for one diagnostic session at a time.
struct DebugContext: Sendable {
    let adServerUrl: URL
    let publisherToken: String?
    let conversationId: String?
    let userId: String?
    let sessionId: String?

    init(
        adServerUrl: URL,
        publisherToken: String? = nil,
        conversationId: String? = nil,
        userId: String? = nil,
        sessionId: String? = nil
    ) {
        self.adServerUrl = adServerUrl
        self.publisherToken = publisherToken
        self.conversationId = conversationId
        self.userId = userId
        self.sessionId = sessionId
    }
}

/// Forwards `Session.debug(...)` events to the ad server when the
/// publisher has been opted in via the `/init` response
/// (`reportDebug: true`).
///
/// The publisher's `onDebugEvent` callback is the local leg and runs
/// unconditionally inside `Session.debug` — `DebugCapture` is purely
/// the network leg, so the entry point is a single `capture(...)`
/// instead of the dual-leg shape `ErrorCapture` uses.
///
/// Fire-and-forget, mirroring `ErrorCapture`. Defaults to off because
/// debug payloads can be large and contain structured session state;
/// the server flips it on per-userId only when actively diagnosing.
enum DebugCapture {
    /// Sends a debug event to the `/debug` endpoint.
    ///
    /// - Parameters:
    ///   - name: Debug event label (e.g. `"Session: cancelled"`).
    ///     Already namespaced by the caller — `Session.debug` prefixes
    ///     `"Session: "` before this is reached.
    ///   - data: Optional structured payload from the call site.
    ///     Serialised to JSON when possible, falls back to
    ///     `String(describing:)` for non-JSON-representable values
    ///     (errors, dates, etc.). nil when omitted.
    ///   - context: Session attribution metadata.
    static func capture(name: String, data: Any? = nil, context: DebugContext) {
        let url = context.adServerUrl.appendingPathComponent("debug")

        let dto = DebugRequestDTO(
            name: name,
            data: stringify(data),
            additionalData: DebugRequestDTO.AdditionalData(
                publisherToken: context.publisherToken,
                conversationId: context.conversationId,
                userId: context.userId,
                sessionId: context.sessionId,
                sdk: SDKInfo.current.toDTO()
            )
        )

        guard let body = try? JSONEncoder().encode(dto) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // Same fire-and-forget budget as `/error` — debug forwarding
        // is opt-in but should never stall the publisher's network.
        request.timeoutInterval = Constants.errorReportTimeoutMs / 1000

        Task { try? await URLSession.shared.data(for: request) }
    }

    /// Best-effort serialisation of an arbitrary `data: Any?` to a
    /// JSON-shaped string. Falls back to `String(describing:)` so
    /// non-JSON values (errors, structs, dates) still survive on the
    /// wire — the server treats `data` as opaque text either way.
    private static func stringify(_ value: Any?) -> String? {
        guard let value = value else { return nil }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return String(describing: value)
    }
}
