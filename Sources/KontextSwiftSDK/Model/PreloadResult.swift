import Foundation

/// Standardised result of a preload operation.
///
/// Internal to the SDK: produced by `Preload.requestAd(...)`, consumed by
/// `Session.applyPreloadResult(...)` and translated into publisher-facing
/// `AdEvent`s. Not exposed in any public API surface — publishers learn
/// outcomes via `Session.eventPublisher` / the `onEvent` callback.
enum PreloadResult: Sendable {
    /// The preload completed successfully. `bids` may be empty if the server
    /// responded OK but no bid won the auction. When multiple placement codes
    /// are enabled, this carries one bid per matching placement.
    /// Mirrors sdk-js's `PreloadSuccess.bids: Bid[]`.
    ///
    /// `sessionId` is optional because trackOnly preloads can come back
    /// with an empty body (no sessionId, no bids) — the server treats
    /// them as analytics-only. Non-trackOnly successful responses
    /// always carry a sessionId.
    case success(bids: [Bid], sessionId: UUID?)
    /// The preload failed. `event` carries the equivalent ad event (if any)
    /// that should be forwarded to the publisher's `onEvent` handler.
    /// `disableSession` indicates the server flagged this session as
    /// permanently disabled and no further preloads should be attempted.
    ///
    /// `sessionId` carries the server session id when the response included
    /// one — skip / no-fill / ads-disabled responses return a sessionId too,
    /// and `Session` must persist it from any of them. Otherwise a session
    /// that only ever skips (trackOnly / frequency-capped) never captures a
    /// sessionId, sends an empty one every request, and the server mints a
    /// fresh session each time. `nil` for the genuinely empty cases (network
    /// / decode failure, 204, or a body without one).
    case failure(reason: String, event: AdEvent?, disableSession: Bool, sessionId: UUID?)
}
