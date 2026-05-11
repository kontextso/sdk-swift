import Foundation
import KontextKit

/// Wire-format bid as decoded from the `/preload` response.
/// Convert to the SDK-internal `Bid` domain type via `toBid()`.
///
/// Strict on identity (`bidId: UUID`, `code: String`) — a malformed
/// required field is treated as a server bug and fails the whole
/// response decode rather than silently producing a half-broken bid.
/// Tolerant on optional metadata (`revenue`, `impressionTrigger`,
/// `creativeType`, `skan`) — unknown enum values or type mismatches
/// fall back to nil so server-side additions don't break old SDKs.
struct BidDTO: Sendable, Decodable {
    let bidId: UUID
    let code: String
    let revenue: Double?
    let impressionTrigger: ImpressionTrigger?
    let creativeType: OMCreativeType?
    let skan: Skan?

    enum CodingKeys: String, CodingKey {
        case bidId, code, revenue, impressionTrigger, creativeType, skan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bidId             = try c.decode(UUID.self, forKey: .bidId)
        self.code              = try c.decode(String.self, forKey: .code)
        self.revenue           = try? c.decode(Double.self, forKey: .revenue)
        self.impressionTrigger = try? c.decode(ImpressionTrigger.self, forKey: .impressionTrigger)
        self.creativeType      = try? c.decode(OMCreativeType.self, forKey: .creativeType)
        self.skan              = try? c.decode(Skan.self, forKey: .skan)
    }

    /// Maps the wire-format bid into the SDK-internal `Bid` domain type.
    func toBid() -> Bid {
        Bid(
            bidId: bidId,
            code: code,
            revenue: revenue,
            impressionTrigger: impressionTrigger,
            creativeType: creativeType,
            skan: skan
        )
    }
}
