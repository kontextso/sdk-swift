import Foundation
import Testing
@testable import KontextSwiftSDK

struct PreloadDTOTests {
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    // MARK: - PreloadRequestDTO

    @Test
    func preloadRequestEncodesAllRequiredFields() throws {
        let config = AdsProviderConfiguration(
            publisherToken: "pub-tok",
            userId: "u-1",
            conversationId: "c-1",
            enabledPlacementCodes: ["inlineAd"],
            variantId: "v-1",
            userEmail: "x@y.z"
        )
        let sdk = SDKInfo(name: "sdk-swift", version: "2.1.0", platform: "ios")
        let app = AppInfo(
            bundleId: "com.example.app", version: "1.0",
            storeUrl: nil, installTime: nil, updateTime: nil, startTime: 1
        )
        let device = makeDeviceInfo()
        let request = PreloadRequestDTO(
            sessionId: "sess-1",
            configuration: config,
            advertisingId: "idfa-1",
            vendorId: "idfv-1",
            sdkInfo: sdk,
            appinfo: app,
            device: device,
            messages: [AdsMessage(id: "m-1", role: .user, content: "Hi", createdAt: Date(timeIntervalSince1970: 1))]
        )

        let data = try encoder.encode(request)
        let dict = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["publisherToken"] as? String == "pub-tok")
        #expect(dict["conversationId"] as? String == "c-1")
        #expect(dict["userId"] as? String == "u-1")
        #expect(dict["userEmail"] as? String == "x@y.z")
        #expect(dict["sessionId"] as? String == "sess-1")
        #expect(dict["advertisingId"] as? String == "idfa-1")
        #expect(dict["vendorId"] as? String == "idfv-1")
        #expect(dict["variantId"] as? String == "v-1")
        #expect(dict["enabledPlacementCodes"] as? [String] == ["inlineAd"])
        let messages = try #require(dict["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages.first?["id"] as? String == "m-1")
        #expect(dict["sdk"] is [String: Any])
        #expect(dict["app"] is [String: Any])
        #expect(dict["device"] is [String: Any])
    }

    @Test
    func preloadRequestOmitsOptionalFieldsWhenNil() throws {
        let config = AdsProviderConfiguration(
            publisherToken: "tok",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: []
        )
        let request = PreloadRequestDTO(
            sessionId: nil,
            configuration: config,
            advertisingId: nil,
            vendorId: nil,
            sdkInfo: SDKInfo(name: "sdk-swift", version: "1", platform: "ios"),
            appinfo: AppInfo(bundleId: nil, version: "1.0", storeUrl: nil, installTime: nil, updateTime: nil, startTime: 0),
            device: makeDeviceInfo(),
            messages: []
        )

        let data = try encoder.encode(request)
        let dict = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(dict["sessionId"] == nil)
        #expect(dict["advertisingId"] == nil)
        #expect(dict["vendorId"] == nil)
        #expect(dict["variantId"] == nil)
        #expect(dict["userEmail"] == nil)
        #expect(dict["character"] == nil)
        #expect(dict["regulatory"] == nil)
    }

    @Test
    func preloadRequestPrefersRegulatoryOverride() throws {
        let config = AdsProviderConfiguration(
            publisherToken: "tok",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: [],
            regulatory: Regulatory(gdpr: 0)
        )
        let override = Regulatory(gdpr: 1, gdprConsent: "OVERRIDE")
        let request = PreloadRequestDTO(
            sessionId: nil,
            configuration: config,
            advertisingId: nil,
            vendorId: nil,
            sdkInfo: SDKInfo(name: "sdk-swift", version: "1", platform: "ios"),
            appinfo: AppInfo(bundleId: nil, version: "1.0", storeUrl: nil, installTime: nil, updateTime: nil, startTime: 0),
            device: makeDeviceInfo(),
            messages: [],
            regulatoryOverride: override
        )

        let data = try encoder.encode(request)
        let dict = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let regulatory = try #require(dict["regulatory"] as? [String: Any])
        #expect(regulatory["gdpr"] as? Int == 1)
        #expect(regulatory["gdprConsent"] as? String == "OVERRIDE")
    }

    // MARK: - PreloadResponseDTO

    @Test
    func preloadResponseDecodesAllFields() throws {
        let json = """
        {
          "sessionId": "s-1",
          "bids": [
            {
              "bidId": "550e8400-e29b-41d4-a716-446655440000",
              "code": "main",
              "adDisplayPosition": "afterAssistantMessage",
              "impressionTrigger": "immediate"
            }
          ],
          "remoteLogLevel": "debug",
          "permanentError": false,
          "skip": false,
          "skipCode": "none"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(PreloadResponseDTO.self, from: json)
        #expect(dto.sessionId == "s-1")
        #expect(dto.bids?.count == 1)
        #expect(dto.remoteLogLevel == "debug")
        #expect(dto.permanentError == false)
        #expect(dto.skip == false)
        #expect(dto.skipCode == "none")
    }

    @Test
    func preloadResponseAllFieldsOptional() throws {
        let json = "{}".data(using: .utf8)!
        let dto = try JSONDecoder().decode(PreloadResponseDTO.self, from: json)
        #expect(dto.sessionId == nil)
        #expect(dto.bids == nil)
        #expect(dto.permanentError == nil)
        #expect(dto.skip == nil)
    }

    @Test
    func preloadResponseToModelDropsBidsWithInvalidUUID() throws {
        let json = """
        {
          "sessionId": "s-1",
          "bids": [
            { "bidId": "not-a-uuid", "code": "main", "adDisplayPosition": "afterAssistantMessage", "impressionTrigger": "immediate" },
            { "bidId": "550e8400-e29b-41d4-a716-446655440000", "code": "main", "adDisplayPosition": "afterAssistantMessage", "impressionTrigger": "immediate" }
          ]
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(PreloadResponseDTO.self, from: json)
        let model = dto.toModel()
        #expect(model.sessionId == "s-1")
        // compactMap drops the invalid UUID
        #expect(model.bids?.count == 1)
    }

    @Test
    func preloadResponseToModelPropagatesFlags() throws {
        let json = """
        {
          "skip": true,
          "skipCode": "no_fill",
          "permanentError": true,
          "remoteLogLevel": "warn"
        }
        """.data(using: .utf8)!
        let model = try JSONDecoder().decode(PreloadResponseDTO.self, from: json).toModel()
        #expect(model.skip == true)
        #expect(model.skipCode == "no_fill")
        #expect(model.permanentError == true)
        #expect(model.remoteLogLevel == "warn")
    }

    // MARK: - BidDTO decoding edge cases

    @Test
    func bidDTODefaultsImpressionTriggerToImmediateWhenMissing() throws {
        let json = """
        {
          "bidId": "550e8400-e29b-41d4-a716-446655440000",
          "code": "main",
          "adDisplayPosition": "afterAssistantMessage"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.impressionTrigger == .immediate)
    }

    @Test
    func bidDTODefaultsImpressionTriggerToImmediateForUnknownValue() throws {
        let json = """
        {
          "bidId": "550e8400-e29b-41d4-a716-446655440000",
          "code": "main",
          "adDisplayPosition": "afterAssistantMessage",
          "impressionTrigger": "bogus-value"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.impressionTrigger == .immediate)
    }

    @Test
    func bidDTODefaultsAdDisplayPositionToAfterAssistantWhenMissing() throws {
        let json = """
        {
          "bidId": "550e8400-e29b-41d4-a716-446655440000",
          "code": "main",
          "impressionTrigger": "immediate"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.adDisplayPosition == .afterAssistantMessage)
    }

    @Test
    func bidDTOModelReturnsNilForInvalidBidId() throws {
        let json = """
        {
          "bidId": "not-a-uuid",
          "code": "main",
          "adDisplayPosition": "afterAssistantMessage",
          "impressionTrigger": "immediate"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.model == nil)
    }

    @Test
    func bidDTOToleratesMalformedOmAndSkanAsNil() throws {
        let json = """
        {
          "bidId": "550e8400-e29b-41d4-a716-446655440000",
          "code": "main",
          "adDisplayPosition": "afterAssistantMessage",
          "impressionTrigger": "immediate",
          "skan": "not-an-object",
          "om": "also-not-an-object"
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.skan == nil)
        #expect(dto.om == nil)
    }

    @Test
    func bidDTODecodesSkanWithFidelities() throws {
        let json = """
        {
          "bidId": "550e8400-e29b-41d4-a716-446655440000",
          "code": "main",
          "adDisplayPosition": "afterAssistantMessage",
          "impressionTrigger": "immediate",
          "skan": {
            "version": "4.0",
            "network": "example.com",
            "itunesItem": "123",
            "sourceApp": "456",
            "fidelities": [
              { "fidelity": 1, "nonce": "n", "timestamp": "1000", "signature": "s" }
            ]
          }
        }
        """.data(using: .utf8)!
        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        #expect(dto.skan?.fidelities?.count == 1)
        #expect(dto.skan?.fidelities?.first?.fidelity == 1)
    }

    // MARK: - Helpers

    private func makeDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            os: OSInfo(name: "ios", version: "17", locale: "en-US", timezone: "UTC"),
            hardware: HardwareInfo(brand: "Apple", model: "iPhone", type: .handset, sdCardAvailable: false),
            screen: ScreenInfo(screenWidth: 390, screenHeight: 844, scale: 3, orientation: .portrait, isDarkMode: false),
            power: PowerInfo(batteryLevel: 90, batteryState: .unplugged, lowPowerMode: false),
            audio: AudioInfo(volume: 80, muted: false, outputPluggedIn: false, outputType: []),
            network: NetworkInfo(userAgent: "ua", carrierName: nil, networkType: .wifi, networkDetail: nil)
        )
    }
}
