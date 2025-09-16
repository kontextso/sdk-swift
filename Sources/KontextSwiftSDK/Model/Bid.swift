import Foundation

public struct Bid: Sendable, Hashable {
    /// ID of the bid
    public let bidId: String
    /// Placement code
    public let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
}
