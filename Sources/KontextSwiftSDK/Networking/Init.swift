import Foundation
import KontextKit

/// `POST /init` flow — one-shot per-publisher configuration fetch
/// fired at session creation.
///
/// Uninhabited namespace (matches `ErrorCapture` / sdk-js's `Init`
/// class). All public surface is `static`, never instantiated.
enum Init {

    /// Fires a `POST /init` request and returns the parsed response.
    ///
    /// Never throws — returns nil on any failure so the SDK never
    /// blocks the publisher. Network and decode failures are routed
    /// through `handleError`, which filters cancellation out of
    /// `ErrorCapture` reporting and forwards everything else.
    ///
    /// `session` is injectable purely for tests — production calls
    /// always use `URLSession.shared` via the default.
    static func fetch(
        config: ResolvedConfig,
        session: URLSession = .shared
    ) async -> InitResponseDTO? {
        do {
            config.onDebugEvent?("Init: start", nil)

            guard var request = buildRequest(config: config) else {
                config.onDebugEvent?("Init: invalid-url", nil)
                return nil
            }
            request.httpBody = try buildBody(config: config)

            let (data, response) = try await HTTPRetry.fetch(request: request, session: session)
            return handleResponse(data: data, response: response, config: config)
        } catch {
            handleError(error, config: config)
            return nil
        }
    }

    // MARK: - Private

    /// Builds the `URLRequest` (URL + headers + timeout) without a body.
    /// Returns nil if the configured ad-server URL can't be parsed.
    private static func buildRequest(config: ResolvedConfig) -> URLRequest? {
        guard let url = URL(string: "\(config.adServerUrl)/init") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.publisherToken, forHTTPHeaderField: "Kontextso-Publisher-Token")
        request.timeoutInterval = Constants.initTimeoutMs / 1000
        return request
    }

    /// Encodes the `/init` request body. `app` and `skan` are sent on
    /// every request — empty values are a valid positive signal (see
    /// `InitRequestDTO` doc).
    ///
    /// `app` only carries `bundleId` and `version` (narrower than the
    /// `AppDTO` shipped with `/preload`); the bundle reading itself
    /// lives in `KontextKit.AppInfoProvider` for cross-SDK reuse.
    private static func buildBody(config: ResolvedConfig) throws -> Data {
        let appInfo = AppInfoProvider.collect()
        let body = InitRequestDTO(
            publisherToken: config.publisherToken,
            userId: config.userId,
            sdk: SDKInfo.current.toDTO(),
            app: InitRequestDTO.AppMetadata(
                bundleId: appInfo.bundleId,
                version: appInfo.version
            ),
            skan: InitRequestDTO.SKANItems(items: SKAdNetworkIdsProvider.collect())
        )
        return try JSONEncoder().encode(body)
    }

    /// Routes a successful HTTP response into either:
    /// * a parsed `InitResponseDTO` (200 / 2xx with non-empty body), or
    /// * `nil` for the "no useful content" cases (204, non-2xx, empty body).
    /// Decode errors are forwarded to `handleError` so the parsed-failure
    /// path produces the same diagnostic trail as a network-level failure.
    private static func handleResponse(
        data: Data,
        response: URLResponse,
        config: ResolvedConfig
    ) -> InitResponseDTO? {
        guard let httpResponse = response as? HTTPURLResponse else {
            config.onDebugEvent?("Init: non-http-response", nil)
            return nil
        }

        let status = httpResponse.statusCode

        if status == 204 {
            // Server explicitly opted out of returning a body
            // (publisher disabled / unknown).
            config.onDebugEvent?("Init: no-content", ["status": 204])
            return nil
        }

        guard (200...299).contains(status) else {
            config.onDebugEvent?("Init: non-ok", ["status": status])
            return nil
        }

        // Tolerate empty bodies on any 2xx (e.g. 200 with no body
        // or 205 Reset Content) — same intent as 204, just with a
        // less specific status code. Don't try to decode `{}`-less
        // JSON; that would throw and surface as a false positive
        // in ErrorCapture.
        if data.isEmpty {
            config.onDebugEvent?("Init: empty-body", ["status": status])
            return nil
        }

        do {
            let initResponse = try JSONDecoder().decode(InitResponseDTO.self, from: data)
            config.onDebugEvent?("Init: response", ["response": initResponse])
            return initResponse
        } catch {
            handleError(error, config: config)
            return nil
        }
    }

    /// Centralised error sink: cancellation paths are debug-logged but
    /// not reported (Session was destroyed mid-request); everything else
    /// goes to `ErrorCapture` for server-side diagnostics. Always
    /// returns control to the caller, never throws.
    private static func handleError(_ error: Error, config: ResolvedConfig) {
        if error is CancellationError {
            // Session was destroyed while /init was in flight.
            config.onDebugEvent?("Init: cancelled", nil)
            return
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            // URLSession surfaces Task cancellation as URLError.cancelled.
            config.onDebugEvent?("Init: cancelled", nil)
            return
        }

        config.onDebugEvent?("Init: error", ["error": error])
        ErrorCapture.capture(error, source: "Init.fetch", context: ErrorContext(
            adServerUrl: config.adServerUrl,
            publisherToken: config.publisherToken,
            conversationId: config.conversationId,
            userId: config.userId
        ))
    }
}
