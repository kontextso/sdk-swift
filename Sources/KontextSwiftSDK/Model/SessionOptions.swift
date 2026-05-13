import Foundation

/// Publisher-facing configuration passed to `KontextAds.createSession()`.
///
/// `enabledPlacementCodes` and `adServerUrl` are optional (publisher
/// input) — defaults are applied at the resolution boundary inside
/// `resolveConfig`, mirroring sdk-js's pattern of defaulting at
/// session creation rather than at field capture.
public struct SessionOptions: Sendable {
    /// Publisher authentication token issued by Kontext.
    public let publisherToken: String
    /// Stable end-user identifier (publisher's user ID).
    public let userId: String
    /// Unique identifier for the current conversation / chat thread.
    public let conversationId: String
    /// Placement codes to request ads for. Pass nil (or omit) to use
    /// the default `["inlineAd"]`. Empty array also resolves to the
    /// default — kept as a defensive guard so an accidental `[]`
    /// doesn't silently disable all placements.
    public let enabledPlacementCodes: [String]?
    /// AI character metadata for contextual targeting.
    public let character: Character?
    /// A/B test variant identifier.
    public let variantId: String?
    /// Privacy / consent signals.
    public let regulatory: Regulatory?
    /// End-user email for frequency-cap deduplication.
    public let userEmail: String?
    /// Ad server base URL. Pass nil (or omit) to use the production
    /// endpoint (`Constants.defaultAdServerUrl`).
    public let adServerUrl: URL?
    /// Platform advertising identifier (IDFA).
    public let advertisingId: String?
    /// Platform vendor identifier (IDFV).
    public let vendorId: String?
    /// Whether the SDK should auto-request ATT authorization. Default `true`.
    public let requestTrackingAuthorization: Bool
    /// Callback invoked for every ad lifecycle event.
    public let onEvent: AdEventHandler?
    /// Callback invoked for SDK-internal diagnostic events.
    public let onDebugEvent: DebugEventHandler?

    public init(
        publisherToken: String,
        userId: String,
        conversationId: String,
        enabledPlacementCodes: [String]? = nil,
        character: Character? = nil,
        variantId: String? = nil,
        regulatory: Regulatory? = nil,
        userEmail: String? = nil,
        adServerUrl: URL? = nil,
        advertisingId: String? = nil,
        vendorId: String? = nil,
        requestTrackingAuthorization: Bool = true,
        onEvent: AdEventHandler? = nil,
        onDebugEvent: DebugEventHandler? = nil
    ) {
        self.publisherToken = publisherToken
        self.userId = userId
        self.conversationId = conversationId
        self.enabledPlacementCodes = enabledPlacementCodes
        self.character = character
        self.variantId = variantId
        self.regulatory = regulatory
        self.userEmail = userEmail
        self.adServerUrl = adServerUrl
        self.advertisingId = advertisingId
        self.vendorId = vendorId
        self.requestTrackingAuthorization = requestTrackingAuthorization
        self.onEvent = onEvent
        self.onDebugEvent = onDebugEvent
    }
}
