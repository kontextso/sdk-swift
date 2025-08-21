import Foundation

struct Bid: Decodable, Sendable {
    /// ID of the bid
    let bidId: String
    /// Placement code
    let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
}
