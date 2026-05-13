import Foundation
import KontextKit

/// Parameters needed to execute a preload request.
/// Passed in so Preload doesn't need to reach into Session.
struct PreloadParams: Sendable {
    let config: ResolvedConfig
    let sessionId: UUID?
    let timeout: TimeInterval
    let isDisabled: Bool
    let advertisingId: String?
    let vendorId: String?
    /// Server-controlled `/error` POST gate, threaded through from
    /// `Session.reportErrors` so Preload's network-failure path
    /// honours the same kill switch as `Session.reportError`. Defaults
    /// to `true` for tests / pre-init paths that don't override.
    var reportErrors: Bool = true
}

/// Represents a single preload operation for a given set of messages.
///
/// Each instance handles a single request lifecycle -- either it results in a bid,
/// or it reaches a terminal failure state. Does not reach into Session's internals.
///
/// `@MainActor` so the mutable state (`bids`, `running`, `task`) is
/// compiler-checked instead of asserted via `@unchecked Sendable` —
/// every caller is already main-actor-isolated (`Session` and the
/// `Task { ... }` it spawns inherit isolation).
@MainActor
final class Preload {
    /// Snapshot of the conversation at request time. Intentionally frozen —
    /// the server's bids were generated against this specific context, and
    /// the ad iframe (loaded inside `AdWebView`) must receive the same
    /// messages via the `update-iframe` postMessage so its creative,
    /// targeting, and viewability signals align with what was bid on.
    ///
    /// DO NOT replace this with a live reference to `Session.getMessages()`
    /// at render time — even if the conversation has advanced, the ad was
    /// chosen for the snapshot's context. Replacing it would break ad
    /// relevance and advertiser targeting guarantees.
    /// Snapshot of messages this preload was constructed with. Read-only
    /// from outside — no `private(set)` needed because the storage is
    /// `let`.
    let messages: [Message]

    /// Indicates an in-flight `requestAd` request. External read,
    /// internal write.
    private(set) var isRunning = false

    private var bids: [Bid] = []

    /// Owns the in-flight `requestAd` work. `cancel()` cancels this Task,
    /// which propagates into `URLSession.data(for:)` (surfaces as
    /// `URLError.cancelled`) and into `HTTPRetry`'s `Task.checkCancellation()`.
    private var task: Task<PreloadResult, Never>?

    init(messages: [Message]) {
        self.messages = messages
    }

    /// `true` when this preload has at least one bid.
    var hasBid: Bool {
        !bids.isEmpty
    }

    /// Returns the bid matching the given placement code, or nil when no
    /// matching bid exists. Mirrors sdk-js's contract — callers must
    /// always know which placement they're asking for.
    func bid(for code: String) -> Bid? {
        bids.first(where: { $0.code == code })
    }

    /// Aborts the in-flight `requestAd` request. Idempotent; safe to call
    /// before / after / multiple times.
    ///
    /// Cancels the owning Task, which makes `URLSession.data(for:)` throw
    /// `URLError.cancelled` immediately (no waiting for the request to
    /// complete naturally) — mirrors sdk-js's `AbortController.abort()`.
    /// The cancellation surfaces in `requestAd`'s catch arm as a
    /// `.failure(reason: "Cancelled", ...)` and is filtered out of
    /// `ErrorCapture`.
    func cancel() {
        task?.cancel()
        isRunning = false
    }

    /// Emits a structured debug event.
    private func debug(_ config: ResolvedConfig, _ name: String, _ data: Any? = nil) {
        config.onDebugEvent?("Preload: \(name)", data)
    }

    /// Sends the preload request to the ad server, evaluates the result,
    /// stores a winning bid if present, and returns a standardised `PreloadResult`.
    ///
    /// Sets `isRunning = true` for the duration of the request; callers can
    /// read `isRunning` to check liveness. `cancel()` aborts the in-flight
    /// request immediately (mirrors sdk-js); the abort surfaces as a
    /// `.failure(reason: "Cancelled", ...)`.
    ///
    /// `session` is injectable purely for tests — production calls always
    /// use `URLSession.shared` via the default.
    func requestAd(params: PreloadParams, session: URLSession = .shared) async -> PreloadResult {
        // Validate before request
        if messages.isEmpty {
            debug(params.config, "no-messages", ["messages": messages])
            return .failure(reason: "No messages", event: nil, disableSession: false)
        }

        isRunning = true
        // The work runs inside an owned Task so `cancel()` can abort it
        // (URLSession honors Task cancellation by surfacing `URLError.cancelled`).
        // Strong `self` capture is fine — we nil out `self.task` in the
        // defer below, which breaks the `self → task → closure → self`
        // cycle synchronously.
        let task = Task { () -> PreloadResult in
            await self.performRequest(params: params, session: session)
        }
        self.task = task
        defer {
            self.task = nil
            isRunning = false
        }
        return await task.value
    }

    private func performRequest(params: PreloadParams, session: URLSession) async -> PreloadResult {
        let config = params.config
        do {
            debug(config, "request-ad-start")

            var request = buildRequest(params: params)
            request.httpBody = try await buildBody(params: params)

            let (data, response) = try await HTTPRetry.fetch(request: request, session: session)
            return try handleResponse(data: data, response: response, config: config)
        } catch {
            return handleError(error, params: params)
        }
    }

    // MARK: - Private

    /// Builds the `URLRequest` (URL + headers + timeout) without a body.
    private func buildRequest(params: PreloadParams) -> URLRequest {
        let config = params.config
        let url = config.adServerUrl.appendingPathComponent("preload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.publisherToken, forHTTPHeaderField: "Kontextso-Publisher-Token")
        request.setValue(params.isDisabled ? "1" : "0", forHTTPHeaderField: "Kontextso-Is-Disabled")
        request.timeoutInterval = params.timeout / 1000.0 // Convert ms to seconds
        return request
    }

    /// Encodes the `/preload` request body via `buildPreloadDTO`.
    private func buildBody(params: PreloadParams) async throws -> Data {
        let dto = await buildPreloadDTO(params: params)
        params.config.onDebugEvent?("Preload: request-ad-body", dto)
        return try JSONEncoder().encode(dto)
    }

    /// Builds a typed `PreloadRequestDTO` from current state and params.
    /// Async because `DeviceCollector.collectAsync` resolves the network-info
    /// leg, which may evaluate a (cached) user-agent string off the main
    /// thread.
    private func buildPreloadDTO(params: PreloadParams) async -> PreloadRequestDTO {
        let config = params.config

        // Merge static regulatory config with live TCF data; only ship
        // the field if at least one signal is non-nil.
        let regulatory = mergedRegulatory(staticConfig: config.regulatory)

        return PreloadRequestDTO(
            publisherToken: config.publisherToken,
            userId: config.userId,
            conversationId: config.conversationId,
            enabledPlacementCodes: config.enabledPlacementCodes,
            messages: messages.map { $0.toDTO() },
            sdk: SDKInfo.current.toDTO(),
            device: await DeviceCollector.collectAsync(),
            app: AppCollector.collect(),
            sessionId: params.sessionId,
            character: config.character?.toDTO(),
            regulatory: regulatory,
            userEmail: config.userEmail,
            variantId: config.variantId,
            advertisingId: params.advertisingId ?? config.advertisingId,
            vendorId: params.vendorId ?? config.vendorId
        )
    }

    /// Overlays live TCF data on top of the publisher's static
    /// regulatory config. Returns `nil` when no signals are available
    /// — keeps the wire shape free of empty objects.
    private func mergedRegulatory(staticConfig: Regulatory?) -> RegulatoryDTO? {
        var reg = staticConfig?.toDTO() ?? RegulatoryDTO()
        let tcf = TCFDataProvider.getTCFData()
        if let gdpr = tcf.gdpr {
            reg.gdpr = gdpr
        }
        if let gdprConsent = tcf.gdprConsent {
            reg.gdprConsent = gdprConsent
        }
        let hasAny = reg.gdpr != nil || reg.gdprConsent != nil || reg.coppa != nil ||
                     reg.gpp != nil || reg.gppSid != nil || reg.usPrivacy != nil
        return hasAny ? reg : nil
    }

    /// Routes an HTTP response into one of four branches:
    /// * **204 No Content** — server explicitly said "nothing to return".
    /// * **non-2xx** — `errorFailure` with an empty DTO; we do not parse
    ///   the body since 4xx/5xx responses may not be JSON-shaped.
    /// * **decode failure** — throws so the caller's catch arm routes
    ///   through `handleError` (becomes an `ErrorCapture` report).
    /// * **2xx with body** — `sessionId` + `errCode` discriminate
    ///   success / skip / server-side error inside the DTO.
    private func handleResponse(
        data: Data,
        response: URLResponse,
        config: ResolvedConfig
    ) throws -> PreloadResult {
        let httpResponse = response as? HTTPURLResponse
        let status = httpResponse?.statusCode ?? 0

        if status == 204 {
            debug(config, "no-content", ["status": 204])
            return .failure(reason: "No content", event: nil, disableSession: false)
        }

        guard (200...299).contains(status) else {
            debug(config, "non-ok-response", ["status": status])
            return errorFailure(config: config, jsonResponse: PreloadResponseDTO.empty)
        }

        let jsonResponse = try JSONDecoder().decode(PreloadResponseDTO.self, from: data)
        debug(config, "request-ad-response", ["jsonResponse": jsonResponse])

        guard let sessionId = jsonResponse.sessionId, jsonResponse.errCode == nil else {
            return errorFailure(config: config, jsonResponse: jsonResponse)
        }

        if jsonResponse.skip == true {
            return skipFailure(config: config, jsonResponse: jsonResponse)
        }

        recordBids(config: config, jsonResponse: jsonResponse)
        return .success(bids: bids, sessionId: sessionId)
    }

    private func errorFailure(config: ResolvedConfig, jsonResponse: PreloadResponseDTO) -> PreloadResult {
        let errCode = jsonResponse.errCode

        if jsonResponse.permanent == true {
            debug(config, "session-disabled", ["jsonResponse": jsonResponse])
            return .failure(
                reason: "Session is disabled",
                event: .error(.init(message: "Session is disabled", errCode: errCode ?? "session_disabled")),
                disableSession: true
            )
        }

        debug(config, "ad-generation-error", ["errCode": errCode as Any])
        return .failure(
            reason: "Ad generation skipped",
            event: .error(.init(message: "Ad generation skipped", errCode: errCode ?? "unknown")),
            disableSession: false
        )
    }

    private func skipFailure(config: ResolvedConfig, jsonResponse: PreloadResponseDTO) -> PreloadResult {
        debug(config, "ad-generation-skipped", ["errCode": jsonResponse.errCode as Any])
        return .failure(
            reason: "Ad generation skipped",
            event: .noFill(.init(skipCode: jsonResponse.skipCode ?? "unknown")),
            disableSession: false
        )
    }

    private func recordBids(config: ResolvedConfig, jsonResponse: PreloadResponseDTO) {
        let enabledCodes = Set(config.enabledPlacementCodes)
        let matchingBids = jsonResponse.bids?.filter { enabledCodes.contains($0.code) } ?? []

        if !matchingBids.isEmpty {
            self.bids = matchingBids.map { $0.toBid() }
            debug(config, "ad-generation-success", ["bids": matchingBids])
        } else {
            debug(config, "no-bids-for-placement-codes", [
                "enabledPlacementCodes": config.enabledPlacementCodes,
                "bids": jsonResponse.bids as Any,
            ])
        }
    }

    /// Routes a network/decode failure into a `PreloadResult.failure` and
    /// reports it to `/error` for diagnostics. Cancellation surfaces as a
    /// clean `.failure(reason: "Cancelled", event: nil)` with no
    /// `ErrorCapture` report — mirrors sdk-js's AbortError branch.
    private func handleError(_ error: Error, params: PreloadParams) -> PreloadResult {
        let config = params.config
        let isCancellation = error is CancellationError ||
            (error as? URLError)?.code == .cancelled

        if isCancellation {
            debug(config, "cancelled")
            return .failure(reason: "Cancelled", event: nil, disableSession: false)
        }

        debug(config, "error-preloading-ads", ["error": error])
        ErrorCapture.capture(error, context: ErrorContext(
            adServerUrl: config.adServerUrl,
            publisherToken: config.publisherToken,
            conversationId: config.conversationId,
            userId: config.userId
        ), reportEnabled: params.reportErrors)

        // Include the underlying error in the in-band event so the
        // publisher's `onEvent` handler has the same context that goes
        // to ErrorCapture (mirrors sdk-js's `Error preloading ads: …`).
        let message = "Error preloading ads: \(error.localizedDescription)"
        return .failure(
            reason: "Error preloading ads",
            event: .error(.init(message: message, errCode: "request_failed")),
            disableSession: false
        )
    }
}
