import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests for DTOs that compose other DTOs (DeviceDTO, CharacterDTO, MessageDTO, RegulatoryDTO)
/// plus tests for the DTO ↔ model init(from:) bridges they expose.
struct CompositeDTOTests {
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    private func encodedDict(_ value: any Encodable) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - DeviceDTO composition

    @Test
    func deviceDTOEncodesAllSubObjects() throws {
        let dto = DeviceDTO(
            os: OSDTO(name: "ios", version: "17", locale: "en-US", timezone: "UTC"),
            hardware: HardwareDTO(brand: "Apple", model: "iPhone", type: .handset, sdCardAvailable: false),
            screen: ScreenDTO(width: 10, height: 20, dpr: 1, orientation: .portrait, darkMode: false),
            power: PowerDTO(batteryLevel: 50, batteryState: .unplugged, lowPowerMode: false),
            audio: AudioDTO(volume: 80, muted: false, outputPluggedIn: true, outputType: [.wired]),
            network: NetworkDTO(userAgent: "UA", type: .wifi, detail: nil, carrier: nil)
        )
        let dict = try encodedDict(dto)
        #expect(dict["os"] is [String: Any])
        #expect(dict["hardware"] is [String: Any])
        #expect(dict["screen"] is [String: Any])
        #expect(dict["power"] is [String: Any])
        #expect(dict["audio"] is [String: Any])
        #expect(dict["network"] is [String: Any])
    }

    // MARK: - RegulatoryDTO init(from:) bridge

    @Test
    func regulatoryDTOInitReturnsNilForNilModel() {
        let dto = RegulatoryDTO(from: nil)
        #expect(dto == nil)
    }

    @Test
    func regulatoryDTOInitCopiesAllFieldsFromModel() throws {
        let reg = Regulatory(
            gdpr: 1, gdprConsent: "CONSENT", coppa: 0,
            usPrivacy: "1YNN", gpp: "GPP_STRING", gppSid: [2, 6]
        )
        let dto = try #require(RegulatoryDTO(from: reg))
        let dict = try encodedDict(dto)
        #expect(dict["gdpr"] as? Int == 1)
        #expect(dict["gdprConsent"] as? String == "CONSENT")
        #expect(dict["coppa"] as? Int == 0)
        #expect(dict["usPrivacy"] as? String == "1YNN")
        #expect(dict["gpp"] as? String == "GPP_STRING")
        #expect(dict["gppSid"] as? [Int] == [2, 6])
    }

    @Test
    func regulatoryDTOOmitsNilFields() throws {
        let dto = try #require(RegulatoryDTO(from: Regulatory()))
        let dict = try encodedDict(dto)
        #expect(dict["gdpr"] == nil)
        #expect(dict["gdprConsent"] == nil)
        #expect(dict["coppa"] == nil)
        #expect(dict["usPrivacy"] == nil)
        #expect(dict["gpp"] == nil)
        #expect(dict["gppSid"] == nil)
    }

    // MARK: - CharacterDTO init(from:) bridge

    @Test
    func characterDTOInitReturnsNilForNilModel() {
        let dto = CharacterDTO(from: nil)
        #expect(dto == nil)
    }

    @Test
    func characterDTOInitCopiesAllFieldsFromModel() throws {
        let character = Character(
            id: "char-1", name: "Max",
            avatarUrl: URL(string: "https://cdn.example.com/a.png"),
            isNsfw: false, greeting: "Hi", persona: "friendly", tags: ["fantasy", "adventure"]
        )
        let dto = try #require(CharacterDTO(from: character))
        let dict = try encodedDict(dto)
        #expect(dict["id"] as? String == "char-1")
        #expect(dict["name"] as? String == "Max")
        #expect(dict["avatarUrl"] as? String == "https://cdn.example.com/a.png")
        #expect(dict["isNsfw"] as? Bool == false)
        #expect(dict["greeting"] as? String == "Hi")
        #expect(dict["persona"] as? String == "friendly")
        #expect(dict["tags"] as? [String] == ["fantasy", "adventure"])
    }

    @Test
    func characterDTOOmitsNilFields() throws {
        let character = Character(id: nil, name: nil, avatarUrl: nil, isNsfw: nil, greeting: nil, persona: nil, tags: nil)
        let dto = try #require(CharacterDTO(from: character))
        let dict = try encodedDict(dto)
        #expect(dict.isEmpty)
    }

    // MARK: - MessageDTO round-trip

    @Test
    func messageDTOEncodesAllFields() throws {
        let message = AdsMessage(
            id: "m-1", role: .user, content: "Hello",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let dto = MessageDTO(from: message)
        #expect(dto.id == "m-1")
        #expect(dto.role == .user)
        #expect(dto.content == "Hello")
        #expect(dto.createdAt.timeIntervalSince1970 == 1_700_000_000)
    }

    @Test
    func messageDTOMapsAssistantRole() {
        let message = AdsMessage(id: "m-2", role: .assistant, content: "Hi there", createdAt: Date())
        let dto = MessageDTO(from: message)
        #expect(dto.role == .assistant)
    }

    @Test
    func messageDTOIsHashable() throws {
        let message = AdsMessage(id: "m-1", role: .user, content: "Hello", createdAt: Date(timeIntervalSince1970: 0))
        let a = MessageDTO(from: message)
        let b = MessageDTO(from: message)
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b]).count == 1)
    }

    // MARK: - RoleDTO

    @Test
    func roleDTOInitMapsModelUser() {
        #expect(RoleDTO(from: .user) == .user)
    }

    @Test
    func roleDTOInitMapsModelAssistant() {
        #expect(RoleDTO(from: .assistant) == .assistant)
    }

    @Test
    func roleDTOEncodesAsLowercaseString() throws {
        let encoded = try encoder.encode(RoleDTO.user)
        #expect(String(data: encoded, encoding: .utf8) == "\"user\"")
    }

    @Test
    func roleDTODecodesBothCases() throws {
        let user = try JSONDecoder().decode(RoleDTO.self, from: "\"user\"".data(using: .utf8)!)
        #expect(user == .user)
        let assistant = try JSONDecoder().decode(RoleDTO.self, from: "\"assistant\"".data(using: .utf8)!)
        #expect(assistant == .assistant)
    }

    // MARK: - AdDisplayPositionDTO

    @Test
    func adDisplayPositionDTOInitMapsAllCases() {
        #expect(AdDisplayPositionDTO(from: .afterAssistantMessage) == .afterAssistantMessage)
        #expect(AdDisplayPositionDTO(from: .afterUserMessage) == .afterUserMessage)
    }

    @Test
    func adDisplayPositionDTOModelMapsAllCases() {
        #expect(AdDisplayPositionDTO.afterAssistantMessage.model == .afterAssistantMessage)
        #expect(AdDisplayPositionDTO.afterUserMessage.model == .afterUserMessage)
    }

    @Test
    func adDisplayPositionDTODecodes() throws {
        let afterAssistant = try JSONDecoder().decode(
            AdDisplayPositionDTO.self,
            from: "\"afterAssistantMessage\"".data(using: .utf8)!
        )
        #expect(afterAssistant == .afterAssistantMessage)

        let afterUser = try JSONDecoder().decode(
            AdDisplayPositionDTO.self,
            from: "\"afterUserMessage\"".data(using: .utf8)!
        )
        #expect(afterUser == .afterUserMessage)
    }

    // MARK: - UpdateIFrameDTO + UpdateDimensionsIFrameDataDTO type strings

    @Test
    func updateIFrameDTOHasFixedTypeString() throws {
        let dto = UpdateIFrameDTO(
            data: IframeEvent.UpdateIFrameDataDTO(
                sdk: "sdk-swift", code: "code", messageId: "m",
                messages: [], otherParams: nil
            )
        )
        let dict = try encodedDict(dto)
        #expect(dict["type"] as? String == "update-iframe")
    }

    @Test
    func updateDimensionsIFrameDataDTOHasFixedTypeString() throws {
        let dto = UpdateDimensionsIFrameDataDTO(
            data: UpdateDimensionsIFrameDataDTO.Data(
                screenWidth: 390, screenHeight: 844,
                containerWidth: 350, containerHeight: 100,
                containerX: 10, containerY: 50, keyboardHeight: 0
            )
        )
        let dict = try encodedDict(dto)
        #expect(dict["type"] as? String == "update-dimensions-iframe")
        let data = try #require(dict["data"] as? [String: Any])
        #expect(data["screenWidth"] as? Double == 390)
        #expect(data["keyboardHeight"] as? Double == 0)
    }
}
