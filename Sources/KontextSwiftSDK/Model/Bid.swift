import Foundation
import KontextKit

/// A winning bid returned by the ad server for a specific placement.
///
/// Internal to the SDK: produced by `BidDTO.toBid()`, held inside `Ad`
/// and `Preload`, and consumed by `Session.applyPreloadResult` to drive
/// publisher-facing `AdEvent`s. Publishers never receive a `Bid`
/// instance — they read the relevant fields (revenue, bidId, etc.) off
/// `AdEvent` payloads instead.
struct Bid: Sendable, Equatable {
    /// Unique identifier for this bid from the ad server.
    let bidId: UUID
    /// Placement code this bid targets (e.g. "inlineAd").
    let code: String
    /// Estimated revenue for this impression, if available.
    let revenue: Double?
    /// When the ad impression should be triggered. Non-optional —
    /// `BidDTO.init(from:)` collapses a missing/null wire value to
    /// `.immediate` so every call site can treat this as a definitive
    /// signal. Mirrors `InitResponseDTO`'s pattern for behavior-gating
    /// flags.
    let impressionTrigger: ImpressionTrigger
    /// Creative format for Open Measurement tracking.
    let creativeType: OMCreativeType?
    /// SKAdNetwork attribution data, passed through to Apple's SKAdNetwork
    /// APIs (via KontextKit) without interpretation by this SDK.
    let skan: Skan?

    init(
        bidId: UUID,
        code: String,
        revenue: Double? = nil,
        impressionTrigger: ImpressionTrigger = .immediate,
        creativeType: OMCreativeType? = nil,
        skan: Skan? = nil
    ) {
        self.bidId = bidId
        self.code = code
        self.revenue = revenue
        self.impressionTrigger = impressionTrigger
        self.creativeType = creativeType
        self.skan = skan
    }

    /// Equality is keyed on `bidId` alone — bidIds are server-issued and
    /// unique per bid. Other fields (revenue, skan, etc.) carry through
    /// as data, not identity. `Hashable` is intentionally not declared:
    /// nothing in the SDK uses Bid as a Set element or dictionary key.
    static func == (lhs: Bid, rhs: Bid) -> Bool {
        lhs.bidId == rhs.bidId
    }
}
