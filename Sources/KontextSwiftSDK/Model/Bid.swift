import Foundation

public struct AttributionFidelity: Sendable, Hashable {
    public let fidelity: Int
    public let signature: String
    public let nonce: String
    public let timestamp: String
}

public struct Skan: Sendable, Hashable {
    public let version: String
    public let network: String
    public let itunesItem: String
    public let sourceApp: String
    public let sourceIdentifier: String?
    public let campaign: String?
    public let fidelities: [AttributionFidelity]?
    public let nonce: String?
    public let timestamp: String?
    public let signature: String?
}

public struct Bid: Sendable, Hashable {
    /// Id of the bid
    public let bidId: String
    /// Placement code
    public let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
    /// SKAdNetwork attribution payload for iOS impression reporting
    public let skan: Skan?

    init(
        bidId: String,
        code: String,
        adDisplayPosition: AdDisplayPosition,
        skan: Skan? = nil
    ) {
        self.bidId = bidId
        self.code = code
        self.adDisplayPosition = adDisplayPosition
        self.skan = skan
    }
}
