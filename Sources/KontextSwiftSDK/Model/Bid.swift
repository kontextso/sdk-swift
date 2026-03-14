import Foundation

public struct Bid: Sendable, Hashable {
    /// Id of the bid
    public let bidId: UUID
    /// Placement code
    public let code: String
    /// Indicates when the ad should be rendered
    let adDisplayPosition: AdDisplayPosition
    /// SKAdNetwork attribution payload for iOS impression reporting
    public let skan: Skan?
    /// Determines when impression attribution should be started
    let impressionTrigger: ImpressionTrigger
    /// Open Measurement configuration
    public let om: OmInfo?

    init(
        bidId: UUID,
        code: String,
        adDisplayPosition: AdDisplayPosition,
        skan: Skan? = nil,
        impressionTrigger: ImpressionTrigger = .immediate,
        om: OmInfo? = nil
    ) {
        self.bidId = bidId
        self.code = code
        self.adDisplayPosition = adDisplayPosition
        self.skan = skan
        self.impressionTrigger = impressionTrigger
        self.om = om
    }
}
