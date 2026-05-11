import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct PreloadResponseDecodingTests {

    // MARK: - Helpers

    private func decode(_ json: String) throws -> PreloadResponseDTO {
        let data = json.data(using: .utf8)!
        return try JSONDecoder().decode(PreloadResponseDTO.self, from: data)
    }

    // MARK: - Success responses

    @Test func decodeSuccessResponseWithBids() throws {
        let bidUuid = "11111111-2222-3333-4444-555555555555"
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "\(bidUuid)",
                    "code": "inlineAd"
                }
            ]
        }
        """
        let response = try decode(json)

        #expect(response.sessionId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(response.bids?.count == 1)
        #expect(response.bids?[0].bidId == UUID(uuidString: bidUuid))
        #expect(response.bids?[0].code == "inlineAd")
        #expect(response.skip == nil)
        #expect(response.errCode == nil)
    }

    @Test func decodeResponseWithMultipleBidsForDifferentCodes() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                { "bidId": "11111111-1111-1111-1111-111111111111", "code": "inlineAd" },
                { "bidId": "22222222-2222-2222-2222-222222222222", "code": "banner" },
                { "bidId": "33333333-3333-3333-3333-333333333333", "code": "interstitial" }
            ]
        }
        """
        let response = try decode(json)

        #expect(response.bids?.count == 3)
        #expect(response.bids?[0].code == "inlineAd")
        #expect(response.bids?[1].code == "banner")
        #expect(response.bids?[2].code == "interstitial")
    }

    @Test func decodeResponseWithRevenueField() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd",
                    "revenue": 0.0042
                }
            ]
        }
        """
        let response = try decode(json)

        let revenue = try #require(response.bids?[0].revenue)
        #expect(abs(revenue - 0.0042) < 0.0001)
    }

    @Test func decodeResponseWithImpressionTrigger() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd",
                    "impressionTrigger": "immediate"
                }
            ]
        }
        """
        let response = try decode(json)

        #expect(response.bids?[0].impressionTrigger == .immediate)
    }

    // MARK: - Skip responses

    @Test func decodeSkipResponse() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "skip": true,
            "skipCode": "frequency_cap"
        }
        """
        let response = try decode(json)

        #expect(response.skip == true)
        #expect(response.skipCode == "frequency_cap")
        #expect(response.bids == nil)
    }

    // MARK: - Error responses

    @Test func decodeErrorResponse() throws {
        let json = """
        {
            "errCode": "invalid_token",
            "error": "Publisher token is invalid",
            "permanent": true
        }
        """
        let response = try decode(json)

        #expect(response.errCode == "invalid_token")
        #expect(response.permanent == true)
        #expect(response.sessionId == nil)
    }

    @Test func decodePermanentDisableResponse() throws {
        // permanent: true is the load-bearing signal that tells Session
        // to stop preloading; pin its decode independently of errCode.
        let json = """
        {
            "errCode": "session_disabled",
            "permanent": true
        }
        """
        let response = try decode(json)

        #expect(response.permanent == true)
        #expect(response.errCode == "session_disabled")
    }

    @Test func decodeAmbiguousErrorWithBidsTreatedAsError() throws {
        // Pin the wire-shape ambiguity: if the server emits errCode
        // alongside bids, both fields decode successfully — discriminating
        // the response is the consumer's job (Preload.fetch treats
        // errCode != nil as error and ignores bids).
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "errCode": "some_error",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd"
                }
            ]
        }
        """
        let response = try decode(json)

        #expect(response.errCode == "some_error")
        #expect(response.bids?.count == 1)
    }

    // MARK: - Optional fields

    @Test func decodeResponseWithMissingOptionalFields() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111"
        }
        """
        let response = try decode(json)

        #expect(response.sessionId == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        #expect(response.bids == nil)
        #expect(response.skip == nil)
        #expect(response.skipCode == nil)
        #expect(response.errCode == nil)
        #expect(response.permanent == nil)
    }

    // MARK: - BidDTO.toBid()

    @Test func bidDTOToBidConversion() throws {
        let uuid = "12345678-1234-1234-1234-123456789012"
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "\(uuid)",
                    "code": "inlineAd",
                    "revenue": 1.23,
                    "impressionTrigger": "component"
                }
            ]
        }
        """
        let response = try decode(json)
        let bid = response.bids![0].toBid()

        #expect(bid.bidId == UUID(uuidString: uuid))
        #expect(bid.code == "inlineAd")
        #expect(bid.revenue == 1.23)
        #expect(bid.impressionTrigger == .component)
    }

    @Test func decodeThrowsOnNonUUIDSessionId() throws {
        // sessionId is strictly typed as UUID — a server-emitted non-UUID
        // is a server bug and fails the response decode (caught by
        // Preload.fetch's outer catch and reported via ErrorCapture).
        let json = """
        {
            "sessionId": "not-a-uuid"
        }
        """
        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    @Test func decodeThrowsOnNonUUIDBidId() throws {
        // bidId is strictly typed as UUID — a server-emitted non-UUID is
        // a server bug and fails the response decode (rather than the
        // bid silently being dropped, which masked server issues).
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                { "bidId": "not-a-uuid", "code": "inlineAd" }
            ]
        }
        """
        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    @Test func decodeAcceptsUnknownImpressionTriggerAsNil() throws {
        // Unknown enum value falls back to nil at the DTO boundary so
        // server-side additions don't break old SDKs.
        let uuid = "12345678-1234-1234-1234-123456789012"
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "\(uuid)",
                    "code": "inlineAd",
                    "impressionTrigger": "future-trigger-mode"
                }
            ]
        }
        """
        let response = try decode(json)
        let bid = response.bids![0].toBid()
        #expect(bid.impressionTrigger == nil)
    }

    @Test func decodeAcceptsUnknownCreativeTypeAsNil() throws {
        let uuid = "12345678-1234-1234-1234-123456789012"
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "\(uuid)",
                    "code": "inlineAd",
                    "creativeType": "future-format"
                }
            ]
        }
        """
        let response = try decode(json)
        let bid = response.bids![0].toBid()
        #expect(bid.creativeType == nil)
    }

    // MARK: - Empty / null bids

    @Test func decodeResponseWithEmptyBidsArray() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": []
        }
        """
        let response = try decode(json)

        #expect(response.bids != nil)
        #expect(response.bids?.isEmpty == true)
    }

    @Test func decodeResponseWithNullBids() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": null
        }
        """
        let response = try decode(json)

        #expect(response.bids == nil)
    }

    // MARK: - BidDTO skan decoding

    @Test func bidDTODecodesSkanFieldAsTypedStruct() throws {
        // Wire format from the ad server: camelCase keys, all numeric IDs
        // sent as strings (matches `SkanPayload` in ads/packages/ad-formats).
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
                    "code": "inlineAd",
                    "skan": {
                        "version": "2.2",
                        "network": "example.skadnetwork",
                        "campaign": "42",
                        "itunesItem": "123456789",
                        "sourceApp": "987654321",
                        "sourceIdentifier": "1234"
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        let skan = try #require(response.bids?[0].skan)

        #expect(skan.version == "2.2")
        #expect(skan.network == "example.skadnetwork")
        #expect(skan.campaign == "42")
        #expect(skan.itunesItem == "123456789")
        #expect(skan.sourceApp == "987654321")
        #expect(skan.sourceIdentifier == "1234")
    }

    @Test func bidDTODecodesSkanWithFidelitiesArray() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "aaaaaaaa-bbbb-cccc-dddd-ffffffffffff",
                    "code": "inlineAd",
                    "skan": {
                        "version": "4.0",
                        "network": "example.skadnetwork",
                        "itunesItem": "111",
                        "sourceApp": "222",
                        "fidelities": [
                            {
                                "fidelity": 1,
                                "nonce": "abc-123",
                                "signature": "sig-data",
                                "timestamp": "1234567890"
                            },
                            {
                                "fidelity": 0,
                                "nonce": "def-456",
                                "signature": "sig-data-2",
                                "timestamp": "1234567891"
                            }
                        ]
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        let skan = try #require(response.bids?[0].skan)

        #expect(skan.version == "4.0")
        #expect(skan.network == "example.skadnetwork")

        let fidelities = try #require(skan.fidelities)
        #expect(fidelities.count == 2)
        #expect(fidelities[0].fidelity == 1)
        #expect(fidelities[0].nonce == "abc-123")
        #expect(fidelities[0].timestamp == "1234567890")
        #expect(fidelities[1].fidelity == 0)
        #expect(fidelities[1].nonce == "def-456")
    }

    @Test func bidDTOWithNilSkanField() throws {
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "99999999-8888-7777-6666-555555555555",
                    "code": "inlineAd",
                    "revenue": 0.5
                }
            ]
        }
        """
        let response = try decode(json)

        #expect(response.bids?[0].skan == nil)
    }

    @Test func bidDTOToBidPassesSkanToBid() throws {
        let uuid = "abcdef00-1234-1234-1234-123456789abc"
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "\(uuid)",
                    "code": "inlineAd",
                    "revenue": 2.5,
                    "impressionTrigger": "immediate",
                    "skan": {
                        "version": "3.0",
                        "network": "pass.skadnetwork",
                        "itunesItem": "9",
                        "sourceApp": "8",
                        "campaign": "7"
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        let bid = response.bids![0].toBid()

        #expect(bid.bidId == UUID(uuidString: uuid))
        #expect(bid.code == "inlineAd")
        #expect(bid.revenue == 2.5)
        #expect(bid.impressionTrigger == .immediate)

        let skan = try #require(bid.skan)
        #expect(skan.version == "3.0")
        #expect(skan.network == "pass.skadnetwork")
        #expect(skan.campaign == "7")
    }

    // MARK: - Tolerance: malformed fields silently become nil

    @Test func skanWithWrongShapeBecomesNil() throws {
        // Server sends `skan` as a string instead of an object — bid should
        // still decode, with skan = nil (no SKAN attribution).
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                { "bidId": "11111111-1111-1111-1111-111111111111", "code": "inlineAd", "skan": "wrong-shape-string" }
            ]
        }
        """
        let response = try decode(json)
        #expect(response.bids?.count == 1)
        #expect(response.bids?[0].skan == nil)
    }

    @Test func skanCoercesIntegerScalarsToString() throws {
        // Server bug: every numeric ID emitted as a JSON number instead
        // of the contract-specified string. Decoder coerces, bid + skan
        // both decode cleanly.
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd",
                    "skan": {
                        "version": "2.2",
                        "network": "test.skadnetwork",
                        "itunesItem": 123456,
                        "sourceApp": 654321,
                        "campaign": 42
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        let skan = try #require(response.bids?[0].skan)
        #expect(skan.itunesItem == "123456")
        #expect(skan.sourceApp == "654321")
        #expect(skan.campaign == "42")
    }

    @Test func skanMissingRequiredFieldDropsWholeSkan() throws {
        // All-or-nothing contract: if a server-required field is missing,
        // the bid still decodes but `skan` becomes nil (no partial
        // attribution data leaks through).
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd",
                    "skan": {
                        "version": "2.2",
                        "network": "test.skadnetwork"
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        #expect(response.bids?.count == 1)
        #expect(response.bids?[0].skan == nil)
    }

    @Test func skanWithUnparseableRequiredFieldDropsWholeSkan() throws {
        // Same all-or-nothing contract when a required field is genuinely
        // unparseable (an object, not a coercible scalar): bid stays,
        // skan goes nil.
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                {
                    "bidId": "11111111-1111-1111-1111-111111111111",
                    "code": "inlineAd",
                    "skan": {
                        "version": "2.2",
                        "network": "test.skadnetwork",
                        "itunesItem": { "wrong": "shape" },
                        "sourceApp": "456"
                    }
                }
            ]
        }
        """
        let response = try decode(json)
        #expect(response.bids?.count == 1)
        #expect(response.bids?[0].skan == nil)
    }

    @Test func bidRevenueWithWrongTypeBecomesNil() throws {
        // Optional bid fields tolerate type mismatch — wrong-typed revenue
        // becomes nil instead of failing the whole bid.
        let json = """
        {
            "sessionId": "11111111-1111-1111-1111-111111111111",
            "bids": [
                { "bidId": "11111111-1111-1111-1111-111111111111", "code": "inlineAd", "revenue": "not-a-number" }
            ]
        }
        """
        let response = try decode(json)
        #expect(response.bids?.count == 1)
        #expect(response.bids?[0].revenue == nil)
    }

    // MARK: - Malformed JSON

    @Test func handleMalformedJSONGracefully() {
        let json = "{ this is not valid json }"
        let data = json.data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(PreloadResponseDTO.self, from: data)
        }
    }
}
