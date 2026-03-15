import Foundation

/// Winning bid returned by the server for a specific placement
public struct Bid: Sendable, Hashable {
    /// Id of the bid
    public let bidId: UUID
    /// Placement code
    public let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
    /// SKAdNetwork attribution payload for iOS impression reporting
    let skan: Skan?
    /// Determines when impression attribution should be started
    let impressionTrigger: ImpressionTrigger
    /// Open Measurement creative type — nil means OMID is disabled for this bid
    let om: OmCreativeType?
}
