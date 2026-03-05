import Foundation

public enum ImpressionTrigger: String, Decodable, Sendable {
    case immediate
    case component

    public init(from decoder: Decoder) throws {
        let rawValue = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ImpressionTrigger(rawValue: rawValue) ?? .immediate
    }
}

public struct AttributionFidelity: Decodable, Sendable, Hashable {
    public let fidelity: Int
    public let signature: String
    public let nonce: String
    public let timestamp: String
}

public struct Skan: Decodable, Sendable, Hashable {
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

public struct OmInfo: Sendable, Hashable {
    public let creativeType: OmCreativeType
}

public enum OmCreativeType: String, Sendable {
    case display
    case video
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
    /// Determines when impression attribution should be started
    public let impressionTrigger: ImpressionTrigger
    /// Open Measurement configuration
    public let om: OmInfo?

    init(
        bidId: String,
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
