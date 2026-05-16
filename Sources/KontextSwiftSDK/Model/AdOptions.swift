/// Options for creating an ad instance via `Session.createAd()`.
///
/// Mirrors `createAd(messageId, { code, theme })` in `@kontextso/sdk-js`.
public struct AdOptions: Sendable, Equatable {
    /// Placement code for this ad (default: `Constants.defaultPlacementCode`).
    public let code: String
    /// Visual theme passed to the ad iframe (e.g. `"light"`, `"dark"`).
    public let theme: String?

    public init(code: String = Constants.defaultPlacementCode, theme: String? = nil) {
        self.code = code
        self.theme = theme
    }
}
