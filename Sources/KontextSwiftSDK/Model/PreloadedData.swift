/// Response data from the preload endpoint containing bids and session configuration
struct PreloadedData: Sendable {
    /// Unique identifier for the session.
    let sessionId: String?
    /// List of bids
    let bids: [Bid]?
    /// Not documented on React side
    let remoteLogLevel: String?
    /// Ads should stop being shown and prevent future preloading
    let permanentError: Bool?
    /// Skip
    let skip: Bool?
    /// Skip code
    let skipCode: String?
}
