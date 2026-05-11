/// Subset of `SessionOptions` that can be live-updated on an active session
/// via `Session.updateOptions(_:)`.
///
/// These are read from `session.config` at /preload request time, so an
/// update propagates automatically on the next preload — no session
/// recreation needed.
///
/// **Excluded from live-update:**
/// - Auth/server-identity fields (`publisherToken`, `userId`,
///   `conversationId`, `adServerUrl`, `enabledPlacementCodes`) — changing
///   them mid-session would desync the existing /init registration from
///   subsequent requests.
/// - `character` — the conversation history accumulated in the session
///   belongs to the original character; swapping mid-session leaves
///   messages targeted at the wrong persona. **Recreate the session to
///   switch character.**
///
/// Semantics: every non-nil field overwrites the corresponding value on
/// `session.config`. Fields left as `nil` are **not changed** — to
/// distinguish "not provided" from "clear to nil", recreate the session.
///
/// Mirrors `MutablePublisherOptions` in `@kontextso/sdk-js`.
public struct MutablePublisherOptions: Sendable, Equatable {
    public var variantId: String?
    public var regulatory: Regulatory?
    public var userEmail: String?
    public var advertisingId: String?
    public var vendorId: String?

    public init(
        variantId: String? = nil,
        regulatory: Regulatory? = nil,
        userEmail: String? = nil,
        advertisingId: String? = nil,
        vendorId: String? = nil
    ) {
        self.variantId = variantId
        self.regulatory = regulatory
        self.userEmail = userEmail
        self.advertisingId = advertisingId
        self.vendorId = vendorId
    }
}
