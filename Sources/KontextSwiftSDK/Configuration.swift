import Foundation

/// Fully-resolved SDK configuration.
///
/// Identity / server-binding fields (`publisherToken`, `userId`,
/// `conversationId`, `adServerUrl`, `enabledPlacementCodes`,
/// `character`, `requestTrackingAuthorization`, callbacks) are
/// immutable for the lifetime of the session. `character` is in
/// this group because the accumulated conversation history is
/// targeted at the original persona — swap it via session
/// recreation, not mid-session mutation.
///
/// Preload-scoped fields (`variantId`, `regulatory`, `userEmail`,
/// `advertisingId`, `vendorId`) are settable via
/// `Session.updateOptions(_:)` so publishers can update targeting /
/// consent / IFA mid-session without recreating the session. The
/// next `/preload` request reads the new values.
public struct ResolvedConfig: Sendable {
    public let publisherToken: String
    public let userId: String
    public let conversationId: String
    public let enabledPlacementCodes: [String]
    public let adServerUrl: URL
    public let character: Character?
    public internal(set) var variantId: String?
    public internal(set) var regulatory: Regulatory?
    public internal(set) var userEmail: String?
    public internal(set) var advertisingId: String?
    public internal(set) var vendorId: String?
    public let requestTrackingAuthorization: Bool
    public let onEvent: AdEventHandler?
    public let onDebugEvent: DebugEventHandler?
}

/// Resolves raw publisher options into an immutable `ResolvedConfig`.
///
/// Applies defaults at the resolution boundary (mirrors sdk-js, which
/// defaults inside the `Session` constructor):
/// * `enabledPlacementCodes` — nil or empty array falls back to
///   `[Constants.defaultPlacementCode]`. The `isEmpty` guard is a
///   defensive check so a publisher accidentally passing `[]` doesn't
///   silently disable all placements.
/// * `adServerUrl` — nil falls back to `Constants.defaultAdServerUrl`.
///
/// Internal: only `KontextAds.createSession` calls this; tests reach
/// it via `@testable import`.
func resolveConfig(_ options: SessionOptions) -> ResolvedConfig {
    let placementCodes = options.enabledPlacementCodes ?? []
    return ResolvedConfig(
        publisherToken: options.publisherToken,
        userId: options.userId,
        conversationId: options.conversationId,
        enabledPlacementCodes: placementCodes.isEmpty ? [Constants.defaultPlacementCode] : placementCodes,
        adServerUrl: options.adServerUrl ?? Constants.defaultAdServerUrl,
        character: options.character,
        variantId: options.variantId,
        regulatory: options.regulatory,
        userEmail: options.userEmail,
        advertisingId: options.advertisingId,
        vendorId: options.vendorId,
        requestTrackingAuthorization: options.requestTrackingAuthorization,
        onEvent: options.onEvent,
        onDebugEvent: options.onDebugEvent
    )
}
