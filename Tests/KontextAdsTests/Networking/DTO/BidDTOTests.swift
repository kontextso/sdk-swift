import Foundation
import Testing
@testable import KontextSwiftSDK

struct BidDTOTests {
    private let validBidJSON: [String: Any] = [
        "bidId": "550e8400-e29b-41d4-a716-446655440000",
        "code": "main",
        "adDisplayPosition": "afterAssistantMessage",
        "impressionTrigger": "immediate",
    ]

    private func bid(from json: [String: Any]) throws -> Bid {
        let dto = try BidDTO(fromJSON: json)
        return try #require(dto.model)
    }

    // MARK: - creativeType from om.creativeType

    @Test
    func creativeTypeIsVideoWhenOmCreativeTypeIsVideo() throws {
        var json = validBidJSON
        json["om"] = ["creativeType": "video"]
        let bid = try bid(from: json)
        #expect(bid.creativeType == .video)
    }

    @Test
    func creativeTypeIsDisplayWhenOmCreativeTypeIsDisplay() throws {
        var json = validBidJSON
        json["om"] = ["creativeType": "display"]
        let bid = try bid(from: json)
        #expect(bid.creativeType == .display)
    }

    @Test
    func creativeTypeIsNilWhenOmKeyIsMissing() throws {
        let bid = try bid(from: validBidJSON)
        #expect(bid.creativeType == nil)
    }

    @Test
    func creativeTypeIsNilWhenOmCreativeTypeIsInvalid() throws {
        var json = validBidJSON
        json["om"] = ["creativeType": "unknown"]
        let bid = try bid(from: json)
        #expect(bid.creativeType == nil)
    }

    @Test
    func creativeTypeIsNilWhenOmCreativeTypeKeyIsMissing() throws {
        var json = validBidJSON
        json["om"] = [String: String]()
        let bid = try bid(from: json)
        #expect(bid.creativeType == nil)
    }

    @Test
    func creativeTypeIsNilWhenOmCreativeTypeIsNull() throws {
        var json = validBidJSON
        json["om"] = ["creativeType": NSNull()]
        let bid = try bid(from: json)
        #expect(bid.creativeType == nil)
    }
}
