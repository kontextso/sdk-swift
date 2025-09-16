import Foundation

public struct Bid: Decodable, Sendable, Hashable {
    /// ID of the bid
    public let bidId: String
    /// Placement code
    let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
}
