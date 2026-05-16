import Foundation
import KontextKit
@testable import KontextSwiftSDK
import Testing

/// Wire-format decoding + domain mapping for `BidDTO`. The v4 server emits
/// the OMID creative type on a nested `om` block; before this PR `BidDTO`
/// only read the top-level `creativeType` field, which was always `nil`
/// in production — silently disabling OMID sessions because
/// `Ad.handleAdDoneIframe` guards `startOMSession` on `bid.creativeType`.
struct BidDTOTests {

    private func decode(_ json: String) throws -> BidDTO {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(BidDTO.self, from: data)
    }

    // MARK: - Decoding

    @Test func decodesAllTopLevelFields() throws {
        let json = """
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "revenue": 1.5,
            "impressionTrigger": "component",
            "creativeType": "display"
        }
        """
        let bid = try decode(json)
        #expect(bid.bidId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(bid.code == "inlineAd")
        #expect(bid.revenue == 1.5)
        #expect(bid.impressionTrigger == .component)
        #expect(bid.creativeType == .display)
        #expect(bid.om == nil)
    }

    @Test func decodesMinimalRequiredFields() throws {
        let json = """
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd"
        }
        """
        let bid = try decode(json)
        #expect(bid.revenue == nil)
        // Missing wire value collapses to `.immediate` at decode — see
        // `BidDTO.init(from:)`. Every consumer treats nil as immediate
        // anyway, so we normalise once at the boundary.
        #expect(bid.impressionTrigger == .immediate)
        #expect(bid.creativeType == nil)
        #expect(bid.om == nil)
    }

    @Test func decodesNestedOmCreativeType() throws {
        // v4 server wire shape: bids[i].om.creativeType. The nested
        // OMDTO block is the production source of truth — top-level
        // `creativeType` is always null on real responses. Without this
        // decode the SDK silently fails to open OMID sessions because
        // `Ad.handleAdDoneIframe`'s `bid.creativeType` guard short-circuits.
        let json = """
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": "video" }
        }
        """
        let bid = try decode(json)
        #expect(bid.om?.creativeType == .video)
        // Top-level slot stays nil when only the nested form is present —
        // the mapper prefers the nested location anyway.
        #expect(bid.creativeType == nil)
    }

    @Test func nestedOmCreativeTypeIgnoresUnknownValues() throws {
        // Mirror the existing top-level tolerance: unknown enum values
        // decode to nil rather than throwing, so future server-side
        // additions (e.g. "interactive") don't break old SDKs.
        let json = """
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": "interactive" }
        }
        """
        let bid = try decode(json)
        #expect(bid.om?.creativeType == nil)
    }

    @Test func decodesBothNestedOmAndTopLevelCreativeType() throws {
        // Forward-compat: if a future server emits both fields the
        // decode populates both slots and the mapper's preference rule
        // decides which one is exposed on the domain Bid.
        let json = """
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": "video" },
            "creativeType": "display"
        }
        """
        let bid = try decode(json)
        #expect(bid.om?.creativeType == .video)
        #expect(bid.creativeType == .display)
    }

    // MARK: - toBid() preference

    @Test func toBidPrefersNestedOmCreativeTypeOverTopLevel() throws {
        // The v4 fix lands here. Without this preference rule the
        // SDK reads the always-nil top-level slot and `Ad.startOMSession`
        // is never invoked.
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": "video" },
            "creativeType": "display"
        }
        """).toBid()
        #expect(bid.creativeType == .video)
    }

    @Test func toBidFallsBackToTopLevelCreativeTypeWhenOmIsAbsent() throws {
        // Forward-compat: if the server stops sending the nested form
        // the top-level field is still picked up.
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "creativeType": "display"
        }
        """).toBid()
        #expect(bid.creativeType == .display)
    }

    @Test func toBidUsesNestedOmCreativeTypeWhenTopLevelIsAbsent() throws {
        // The production case as of v4: server sends only the nested form.
        // This is the case the existing test suite did NOT cover — the SDK
        // was silently failing to open OMID sessions in production because
        // toBid() returned nil creativeType.
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": "video" }
        }
        """).toBid()
        #expect(bid.creativeType == .video)
    }

    @Test func toBidReturnsNilCreativeTypeWhenBothAreAbsent() throws {
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd"
        }
        """).toBid()
        #expect(bid.creativeType == nil)
    }

    @Test func toBidFallsBackToTopLevelWhenNestedOmCreativeTypeIsNull() throws {
        // Server sends the om block but with a null creativeType inside —
        // the mapper still falls back to the top-level slot rather than
        // emitting nil.
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "om": { "creativeType": null },
            "creativeType": "display"
        }
        """).toBid()
        #expect(bid.creativeType == .display)
    }

    @Test func toBidPassesNonCreativeTypeFieldsThrough() throws {
        let bid = try decode("""
        {
            "bidId": "11111111-1111-1111-1111-111111111111",
            "code": "inlineAd",
            "revenue": 2.5,
            "impressionTrigger": "component",
            "creativeType": "display"
        }
        """).toBid()
        #expect(bid.bidId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(bid.code == "inlineAd")
        #expect(bid.revenue == 2.5)
        #expect(bid.impressionTrigger == .component)
        #expect(bid.creativeType == .display)
        #expect(bid.skan == nil)
    }
}
