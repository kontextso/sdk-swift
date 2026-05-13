import Foundation

/// SDK-wide defaults and timing constants.
///
/// Mirrors `sdk-js/src/constants.ts` to keep cross-SDK behaviour aligned.
/// OMID partner identity lives here too — `omidPartnerName` is shared
/// across all Kontext SDKs, but `omidPartnerVersion` is per-SDK because
/// each SDK has its own externally-registered IAB certification version.
///
/// Time-valued constants are named in milliseconds (matching the sdk-js
/// naming) and converted to `TimeInterval` (seconds) at the use site.
/// `defaultAdServerUrl` and `defaultPlacementCode` are intentionally `public` —
/// they're referenced as default argument values by the public `SessionOptions.init`,
/// so Swift requires them to match that visibility. Everything else stays internal.
public enum Constants {
    // MARK: - Server

    /// Production ad-server base URL.
    public static let defaultAdServerUrl = URL(string: "https://server.megabrain.co")!

    /// Default placement code used when the publisher omits `enabledPlacementCodes`
    /// or doesn't pass `code` to `Session.createAd()`. For the array form, wrap:
    /// `[Constants.defaultPlacementCode]`.
    public static let defaultPlacementCode = "inlineAd"

    // MARK: - Session lifecycle

    /// Maximum number of messages retained in a session. Older messages are
    /// trimmed from `messages` and their preloads swept via `removePreload(_:)`.
    static let maxMessages = 30

    /// `Session.addMessage` debounce window. Rapid consecutive calls
    /// (e.g. loading conversation history in a loop) coalesce into a single
    /// preload request. Multiply by 1_000_000 to feed `Task.sleep(nanoseconds:)`.
    static let addMessageDebounceMs: Int = 10

    // MARK: - Network

    /// Default `/preload` request timeout. Overridable per-session by the
    /// `preloadTimeout` field of the `/init` response. Consumed as ms.
    static let defaultPreloadTimeoutMs: TimeInterval = 16_000

    /// `/init` request timeout. Divide by 1000 when assigning to
    /// `URLRequest.timeoutInterval` (seconds).
    static let initTimeoutMs: TimeInterval = 16_000

    /// `/error` request timeout. Shorter than `initTimeoutMs` /
    /// `defaultPreloadTimeoutMs` because error reporting is fire-and-forget
    /// — if many errors fire on a slow network we don't want to keep that
    /// many in-flight `URLSession` tasks open for 16s each. Loss of a single
    /// error report is acceptable; resource accumulation isn't.
    static let errorReportTimeoutMs: TimeInterval = 5_000

    // MARK: - UI / iframe

    /// Default modal auto-close timeout. Overridable per-creative via the
    /// `timeout` field of the `open-component-iframe` payload. Wire format
    /// is integer ms — keep type as Int.
    static let defaultModalTimeoutMs: Int = 5_000

    /// Interval at which the SDK reports container dimensions (and viewport
    /// position / keyboard height) to the ad iframe. Divide by 1000 for
    /// `Timer` intervals (seconds).
    static let dimensionReportIntervalMs: TimeInterval = 200

    // MARK: - OMID

    /// Partner name registered with IAB Tech Lab. Same across all Kontext
    /// SDKs — identifies the company.
    static let omidPartnerName = "Kontextso"

    /// sdk-swift's OMID-implementation version. Bumped only as part of a
    /// coordinated IAB certification update. Independent of the SDK
    /// release version.
    static let omidPartnerVersion = "1.0.0"
}
