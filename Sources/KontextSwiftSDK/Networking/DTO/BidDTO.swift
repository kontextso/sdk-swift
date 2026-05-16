import Foundation
import KontextKit

/// Wire-format bid as decoded from the `/preload` response.
/// Convert to the SDK-internal `Bid` domain type via `toBid()`.
///
/// Strict on identity (`bidId: UUID`, `code: String`) — a malformed
/// required field is treated as a server bug and fails the whole
/// response decode rather than silently producing a half-broken bid.
/// Tolerant on optional metadata (`revenue`, `creativeType`, `skan`)
/// — unknown enum values or type mismatches fall back to nil so
/// server-side additions don't break old SDKs.
///
/// `impressionTrigger` is normalised to `.immediate` when missing or
/// unparseable — every consumer treats nil as `.immediate` anyway, so
/// collapsing it at the decode boundary keeps that semantics in one
/// place (same pattern as `InitResponseDTO.enabled/reportErrors/reportDebug`).
///
/// The v4 ad server emits the OMID creative type on a nested `om` block
/// (`bids[i].om.creativeType`), not as a top-level field. Decode both
/// shapes; `toBid()` prefers the nested location and falls back to the
/// top-level slot for forward-compat. Without the nested-block decode
/// the SDK silently fails to open OMID sessions in production
/// (`bid.creativeType` is always nil, which guards the `startOMSession`
/// call in `Ad.handleAdDoneIframe` / `Ad.handleAdDoneComponentIframe`).
struct BidDTO: Sendable, Decodable {
    let bidId: UUID
    let code: String
    let revenue: Double?
    let impressionTrigger: ImpressionTrigger
    let creativeType: OMCreativeType?
    let om: OMDTO?
    let skan: Skan?

    enum CodingKeys: String, CodingKey {
        case bidId, code, revenue, impressionTrigger, creativeType, om, skan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bidId             = try c.decode(UUID.self, forKey: .bidId)
        self.code              = try c.decode(String.self, forKey: .code)
        self.revenue           = try? c.decode(Double.self, forKey: .revenue)
        self.impressionTrigger = (try? c.decode(ImpressionTrigger.self, forKey: .impressionTrigger)) ?? .immediate
        self.creativeType      = try? c.decode(OMCreativeType.self, forKey: .creativeType)
        self.om                = try? c.decode(OMDTO.self, forKey: .om)
        self.skan              = try? c.decode(Skan.self, forKey: .skan)
    }

    /// Maps the wire-format bid into the SDK-internal `Bid` domain type.
    ///
    /// Prefers the nested `om.creativeType` over the top-level
    /// `creativeType` because the v4 server actually emits the nested
    /// form on the wire; the top-level slot is forward-compat only.
    func toBid() -> Bid {
        Bid(
            bidId: bidId,
            code: code,
            revenue: revenue,
            impressionTrigger: impressionTrigger,
            creativeType: om?.creativeType ?? creativeType,
            skan: skan
        )
    }
}

/// Nested OM metadata block on a bid. Mirrors the server's
/// `bids[i].om` object shape. The only field that currently matters
/// is `creativeType`; the block is kept as a nested object on the wire
/// so future OM fields can land here without breaking decode.
struct OMDTO: Sendable, Decodable {
    let creativeType: OMCreativeType?

    enum CodingKeys: String, CodingKey {
        case creativeType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.creativeType = try? c.decode(OMCreativeType.self, forKey: .creativeType)
    }
}
