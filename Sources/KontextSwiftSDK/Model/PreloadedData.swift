//
//  PreloadedData.swift
//  KontextSwiftSDK
//

struct PreloadedData {
    /// Unique identifier for the session.
    let sessionId: String?
    /// List of bids
    let bids: [Bid]?
    /// Not documented on React side
    let remoteLogLevel: String?
    /// Ads should stop being shown and prevent future preloading
    let permanentError: Bool?
}
