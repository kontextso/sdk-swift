import Foundation
@testable import KontextSwiftSDK
import Testing

struct DTOEncodingTests {

    // MARK: - Helpers

    private func encodeToDict<T: Encodable>(_ value: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return dict
    }

    // MARK: - PreloadRequestDTO

    @Test func preloadRequestDTOEncodesAllRequiredFields() {
        let dto = PreloadRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            conversationId: "conv-1",
            enabledPlacementCodes: ["inlineAd"],
            messages: [MessageDTO(id: "m1", role: .user, content: "Hello", createdAt: "2024-01-01T00:00:00.000Z")],
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            device: DeviceDTO(
                hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
                os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
                screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
                power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
                audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired])
            ),
            app: AppDTO(bundleId: "com.test.app", version: "1.0.0")
        )

        let dict = encodeToDict(dto)
        #expect(dict != nil)
        #expect(dict?["publisherToken"] as? String == "pub-123")
        #expect(dict?["userId"] as? String == "user-1")
        #expect(dict?["installId"] as? String == "01890000-0000-7000-8000-000000000000")
        #expect(dict?["conversationId"] as? String == "conv-1")
        #expect((dict?["enabledPlacementCodes"] as? [String])?.first == "inlineAd")
        #expect((dict?["messages"] as? [[String: Any]])?.count == 1)
        #expect(dict?["sdk"] is [String: Any])
        #expect(dict?["device"] is [String: Any])
        #expect(dict?["app"] is [String: Any])
    }

    @Test func preloadRequestDTOEncodesAllOptionalFields() {
        let dto = PreloadRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            conversationId: "conv-1",
            enabledPlacementCodes: ["inlineAd"],
            messages: [MessageDTO(id: "m1", role: .user, content: "Hello", createdAt: "2024-01-01T00:00:00.000Z")],
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            device: DeviceDTO(
                hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
                os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
                screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
                power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
                audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired])
            ),
            app: AppDTO(bundleId: "com.test.app", version: "1.0.0"),
            sessionId: UUID(uuidString: "F8B7BE0F-4C3D-4D5A-9D5F-3E4F5A6B7C8D"),
            character: CharacterDTO(id: "char-1", name: "Luna", avatarUrl: "https://example.com/luna.png"),
            regulatory: RegulatoryDTO(gdpr: 1, gdprConsent: nil, coppa: 0, gpp: nil, gppSid: nil, usPrivacy: nil),
            userEmail: "user@example.com",
            variantId: "variant-A",
            advertisingId: "ad-id-xyz",
            vendorId: "vendor-id-xyz"
        )

        let dict = encodeToDict(dto)
        // Wire form is RFC-4122 lowercase across all SDKs (sdk-js, sdk-kotlin).
        // Swift's default UUID encoding is uppercase — `PreloadRequestDTO`
        // converts at construction time so this can't regress to uppercase.
        #expect(dict?["sessionId"] as? String == "f8b7be0f-4c3d-4d5a-9d5f-3e4f5a6b7c8d")
        #expect((dict?["character"] as? [String: Any])?["id"] as? String == "char-1")
        #expect((dict?["regulatory"] as? [String: Any])?["gdpr"] as? Int == 1)
        #expect(dict?["userEmail"] as? String == "user@example.com")
        #expect(dict?["variantId"] as? String == "variant-A")
        #expect(dict?["advertisingId"] as? String == "ad-id-xyz")
        #expect(dict?["vendorId"] as? String == "vendor-id-xyz")
    }

    @Test func preloadRequestDTOLowercasesSessionIdEvenWhenInputIsUppercase() {
        // Pins the cross-platform RFC-4122 lowercase wire form for sessionId.
        // Without this conversion, Swift's default `UUID.uuidString` (uppercase)
        // would leak through the JSONEncoder default and the server's
        // case-sensitive sessionId lookup would mismatch sdk-js / sdk-kotlin.
        // Constructing from an explicitly UPPERCASE UUID-shaped string proves
        // the conversion happens regardless of caller-side casing.
        let upperUUID = UUID(uuidString: "ABCDEF12-3456-7890-ABCD-EF1234567890")!
        let dto = PreloadRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            conversationId: "conv-1",
            enabledPlacementCodes: ["inlineAd"],
            messages: [],
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            device: DeviceDTO(
                hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
                os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
                screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
                power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
                audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired])
            ),
            app: AppDTO(bundleId: "com.test.app", version: "1.0.0"),
            sessionId: upperUUID
        )

        let dict = encodeToDict(dto)
        #expect(dict?["sessionId"] as? String == "abcdef12-3456-7890-abcd-ef1234567890")
    }

    @Test func preloadRequestDTOOmitsNilOptionalFields() {
        let dto = PreloadRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            conversationId: "conv-1",
            enabledPlacementCodes: ["inlineAd"],
            messages: [],
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            device: DeviceDTO(
                hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
                os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
                screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
                power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
                audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired])
            ),
            app: AppDTO(bundleId: "com.test.app", version: "1.0.0")
        )

        let dict = encodeToDict(dto)
        #expect(dict != nil)
        #expect(dict?["sessionId"] == nil)
        #expect(dict?["character"] == nil)
        #expect(dict?["regulatory"] == nil)
        #expect(dict?["userEmail"] == nil)
        #expect(dict?["variantId"] == nil)
        #expect(dict?["advertisingId"] == nil)
        #expect(dict?["vendorId"] == nil)
    }

    // MARK: - MessageDTO

    @Test func messageDTOEncodesAllFields() {
        let dto = MessageDTO(id: "m1", role: .user, content: "Hello world", createdAt: "2024-01-15T10:30:00.000Z")

        let dict = encodeToDict(dto)
        #expect(dict?["id"] as? String == "m1")
        #expect(dict?["role"] as? String == "user")
        #expect(dict?["content"] as? String == "Hello world")
        #expect(dict?["createdAt"] as? String == "2024-01-15T10:30:00.000Z")
    }

    @Test func messageDTOEncodesAssistantRole() {
        let dto = MessageDTO(id: "m2", role: .assistant, content: "Hi", createdAt: "2024-01-15T10:30:00.000Z")

        let dict = encodeToDict(dto)
        #expect(dict?["role"] as? String == "assistant")
    }

    @Test func messageRoleEnumRawValues() {
        // Pin the wire spelling — the server enum is
        // `'system' | 'assistant' | 'user'` but client SDKs only emit
        // user / assistant. A rename here would silently break parsing.
        #expect(Message.Role.user.rawValue == "user")
        #expect(Message.Role.assistant.rawValue == "assistant")
    }

    // MARK: - SDKDTO

    @Test func sdkDTOEncodesNamePlatformVersion() {
        let dto = SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0")

        let dict = encodeToDict(dto)
        #expect(dict?["name"] as? String == "sdk-swift")
        #expect(dict?["platform"] as? String == "ios")
        #expect(dict?["version"] as? String == "4.0.0")
    }

    // MARK: - CharacterDTO

    @Test func characterDTOEncodesRequiredAndOptionalFields() {
        let dto = CharacterDTO(
            id: "char-1",
            name: "Luna",
            avatarUrl: "https://example.com/avatar.png",
            greeting: "Hi there!",
            persona: "Friendly assistant",
            tags: ["helpful", "creative"],
            isNsfw: false
        )

        let dict = encodeToDict(dto)
        #expect(dict?["id"] as? String == "char-1")
        #expect(dict?["name"] as? String == "Luna")
        #expect(dict?["avatarUrl"] as? String == "https://example.com/avatar.png")
        #expect(dict?["greeting"] as? String == "Hi there!")
        #expect(dict?["persona"] as? String == "Friendly assistant")
        #expect((dict?["tags"] as? [String]) == ["helpful", "creative"])
        #expect(dict?["isNsfw"] as? Bool == false)
    }

    @Test func characterDTOOmitsNilOptionalFields() {
        let dto = CharacterDTO(id: "char-1", name: "Luna", avatarUrl: "https://example.com/luna.png")

        let dict = encodeToDict(dto)
        #expect(dict?["id"] as? String == "char-1")
        #expect(dict?["name"] as? String == "Luna")
        #expect(dict?["avatarUrl"] as? String == "https://example.com/luna.png")
        #expect(dict?["greeting"] == nil)
        #expect(dict?["persona"] == nil)
        #expect(dict?["tags"] == nil)
        #expect(dict?["isNsfw"] == nil)
    }

    // MARK: - RegulatoryDTO

    @Test func regulatoryDTOEncodesAllFields() {
        var dto = RegulatoryDTO()
        dto.gdpr = 1
        dto.gdprConsent = "CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA"
        dto.coppa = 0
        dto.gpp = "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA~1YNN"
        dto.gppSid = [7, 8]
        dto.usPrivacy = "1YNN"

        let dict = encodeToDict(dto)
        #expect(dict?["gdpr"] as? Int == 1)
        #expect(dict?["gdprConsent"] as? String == "CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA")
        #expect(dict?["coppa"] as? Int == 0)
        #expect(dict?["gpp"] as? String == "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA~1YNN")
        #expect((dict?["gppSid"] as? [Int]) == [7, 8])
        #expect(dict?["usPrivacy"] as? String == "1YNN")
    }

    @Test func regulatoryDTOOmitsNilFields() {
        let dto = RegulatoryDTO()

        let dict = encodeToDict(dto)
        #expect(dict != nil)
        #expect(dict?["gdpr"] == nil)
        #expect(dict?["gdprConsent"] == nil)
        #expect(dict?["coppa"] == nil)
        #expect(dict?["gpp"] == nil)
        #expect(dict?["gppSid"] == nil)
        #expect(dict?["usPrivacy"] == nil)
    }

    // MARK: - DeviceDTO

    @Test func deviceDTOEncodesNestedStructures() {
        let dto = DeviceDTO(
            hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset, bootTime: 1700000000000),
            os: OSDTO(name: "ios", version: "17.2", locale: "en-GB", timezone: "Europe/London"),
            screen: ScreenDTO(width: 393, height: 852, dpr: 3.0, orientation: .portrait, darkMode: true, brightness: 50),
            power: PowerDTO(lowPowerMode: true, batteryState: .charging, batteryLevel: 45),
            audio: AudioDTO(volume: 75, muted: false, outputPluggedIn: true, outputType: [.wired, .bluetooth])
        )

        let dict = encodeToDict(dto)
        let hw = dict?["hardware"] as? [String: Any]
        #expect(hw?["brand"] as? String == "Apple")
        #expect(hw?["model"] as? String == "iPhone15,2")
        #expect(hw?["type"] as? String == "handset")
        #expect(hw?["bootTime"] as? Int64 == 1700000000000)

        let os = dict?["os"] as? [String: Any]
        #expect(os?["name"] as? String == "ios")
        #expect(os?["version"] as? String == "17.2")
        #expect(os?["locale"] as? String == "en-GB")
        #expect(os?["timezone"] as? String == "Europe/London")

        let screen = dict?["screen"] as? [String: Any]
        #expect(screen?["width"] as? Int == 393)
        #expect(screen?["height"] as? Int == 852)
        #expect(screen?["dpr"] as? Double == 3.0)
        #expect(screen?["orientation"] as? String == "portrait")
        #expect(screen?["darkMode"] as? Bool == true)

        let power = dict?["power"] as? [String: Any]
        #expect(power?["lowPowerMode"] as? Bool == true)
        #expect(power?["batteryLevel"] as? Double == 45)
        #expect(power?["batteryState"] as? String == "charging")

        let audio = dict?["audio"] as? [String: Any]
        #expect(audio?["volume"] as? Int == 75)
        #expect(audio?["muted"] as? Bool == false)
        #expect(audio?["outputPluggedIn"] as? Bool == true)
        #expect((audio?["outputType"] as? [String]) == ["wired", "bluetooth"])
    }

    @Test func deviceDTOWithOptionalNetwork() {
        let dto = DeviceDTO(
            hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
            os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
            screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
            power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
            audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired]),
            network: NetworkDTO(type: .wifi, carrier: "Verizon", detail: "802.11ac", userAgent: "Mozilla/5.0")
        )

        let dict = encodeToDict(dto)
        let network = dict?["network"] as? [String: Any]
        #expect(network != nil)
        #expect(network?["userAgent"] as? String == "Mozilla/5.0")
        #expect(network?["type"] as? String == "wifi")
        #expect(network?["carrier"] as? String == "Verizon")
        #expect(network?["detail"] as? String == "802.11ac")
    }

    @Test func deviceDTOOmitsNilNetwork() {
        let dto = DeviceDTO(
            hardware: HardwareDTO(brand: "Apple", model: "iPhone15,2", type: .handset),
            os: OSDTO(name: "ios", version: "17.0", locale: "en-US", timezone: "America/New_York"),
            screen: ScreenDTO(width: 390, height: 844, dpr: 3.0, orientation: .portrait, darkMode: false, brightness: 50),
            power: PowerDTO(lowPowerMode: false, batteryState: .unknown),
            audio: AudioDTO(volume: 50, muted: false, outputPluggedIn: false, outputType: [.wired])
        )

        let dict = encodeToDict(dto)
        #expect(dict?["network"] == nil)
    }

    // MARK: - HardwareDTO

    @Test func hardwareDTOEncodesBrandModelType() {
        let dto = HardwareDTO(brand: "Apple", model: "iPad14,1", type: .tablet)

        let dict = encodeToDict(dto)
        #expect(dict?["brand"] as? String == "Apple")
        #expect(dict?["model"] as? String == "iPad14,1")
        #expect(dict?["type"] as? String == "tablet")
        #expect(dict?["bootTime"] == nil)
    }

    @Test func hardwareDTOEncodesBootTime() {
        let dto = HardwareDTO(brand: "Apple", model: "iPad14,1", type: .tablet, bootTime: 1700000000000)

        let dict = encodeToDict(dto)
        #expect(dict?["bootTime"] as? Int64 == 1700000000000)
    }

    // MARK: - OSDTO

    @Test func osDTOEncodesNameVersionLocaleTimezone() {
        let dto = OSDTO(name: "ios", version: "17.4", locale: "ja-JP", timezone: "Asia/Tokyo")

        let dict = encodeToDict(dto)
        #expect(dict?["name"] as? String == "ios")
        #expect(dict?["version"] as? String == "17.4")
        #expect(dict?["locale"] as? String == "ja-JP")
        #expect(dict?["timezone"] as? String == "Asia/Tokyo")
    }

    // MARK: - ScreenDTO

    @Test func screenDTOEncodesAllFields() {
        // brightness is normalised to 0–100 at the collector boundary,
        // matching audio.volume and power.batteryLevel.
        let dto = ScreenDTO(
            width: 1024, height: 1366, dpr: 2.0,
            orientation: .landscape, darkMode: true, brightness: 75
        )

        let dict = encodeToDict(dto)
        #expect(dict?["width"] as? Int == 1024)
        #expect(dict?["height"] as? Int == 1366)
        #expect(dict?["dpr"] as? Double == 2.0)
        #expect(dict?["orientation"] as? String == "landscape")
        #expect(dict?["darkMode"] as? Bool == true)
        #expect(dict?["brightness"] as? Double == 75)
    }

    // MARK: - PowerDTO

    @Test func powerDTOEncodesAllFields() {
        let dto = PowerDTO(lowPowerMode: true, batteryState: .unplugged, batteryLevel: 20)

        let dict = encodeToDict(dto)
        #expect(dict?["lowPowerMode"] as? Bool == true)
        #expect(dict?["batteryLevel"] as? Double == 20)
        #expect(dict?["batteryState"] as? String == "unplugged")
    }

    @Test func powerDTOOmitsNilBatteryLevel() {
        let dto = PowerDTO(lowPowerMode: false, batteryState: .unknown)

        let dict = encodeToDict(dto)
        #expect(dict?["lowPowerMode"] as? Bool == false)
        #expect(dict?["batteryState"] as? String == "unknown")
        #expect(dict?["batteryLevel"] == nil)
    }

    @Test func powerDTOEncodesUnknownBatteryState() {
        // KontextKit's BatteryInfoProvider falls back to "unknown" for any
        // unmapped UIDevice.batteryState — pin this round-trips.
        let dto = PowerDTO(lowPowerMode: false, batteryState: .unknown)

        let dict = encodeToDict(dto)
        #expect(dict?["batteryState"] as? String == "unknown")
    }

    // MARK: - AudioDTO

    @Test func audioDTOEncodesAllFields() {
        let dto = AudioDTO(volume: 100, muted: true, outputPluggedIn: true, outputType: [.bluetooth, .wired])

        let dict = encodeToDict(dto)
        #expect(dict?["volume"] as? Int == 100)
        #expect(dict?["muted"] as? Bool == true)
        #expect(dict?["outputPluggedIn"] as? Bool == true)
        #expect((dict?["outputType"] as? [String]) == ["bluetooth", "wired"])
    }

    @Test func audioDTOEncodesEmptyOutputType() {
        // Edge case: device with no audio outputs reported.
        let dto = AudioDTO(volume: 0, muted: true, outputPluggedIn: false, outputType: [])

        let dict = encodeToDict(dto)
        #expect((dict?["outputType"] as? [String]) == [])
        #expect(dict?["outputPluggedIn"] as? Bool == false)
    }

    // MARK: - NetworkDTO

    @Test func networkDTOEncodesAllFields() {
        let dto = NetworkDTO(type: .cellular, carrier: "T-Mobile", detail: "5g", userAgent: "TestAgent/1.0")

        let dict = encodeToDict(dto)
        #expect(dict?["type"] as? String == "cellular")
        #expect(dict?["carrier"] as? String == "T-Mobile")
        #expect(dict?["detail"] as? String == "5g")
        #expect(dict?["userAgent"] as? String == "TestAgent/1.0")
    }

    @Test func networkDTOOmitsNilOptionalFields() {
        // type is required; carrier/detail/userAgent are honestly nullable
        // (Wi-Fi has no carrier, iOS 16+ never has carrier, WKWebView eval
        // can fail, detail is cellular-only).
        let dto = NetworkDTO(type: .wifi)

        let dict = encodeToDict(dto)
        #expect(dict?["type"] as? String == "wifi")
        #expect(dict?["carrier"] == nil)
        #expect(dict?["detail"] == nil)
        #expect(dict?["userAgent"] == nil)
    }

    // MARK: - Enum rawValue spelling

    // Pin the wire spelling of every enum case the server expects.
    // KontextKit on iOS only emits a subset of these (e.g. handset /
    // tablet / wifi); these tests guard against an accidental rename
    // (`case Wired` instead of `case wired`) breaking server-side
    // parsing for the rare-but-valid cases.

    @Test func hardwareTypeEnumRawValues() {
        #expect(HardwareType.handset.rawValue == "handset")
        #expect(HardwareType.tablet.rawValue == "tablet")
        #expect(HardwareType.desktop.rawValue == "desktop")
        #expect(HardwareType.tv.rawValue == "tv")
        #expect(HardwareType.other.rawValue == "other")
    }

    @Test func screenOrientationEnumRawValues() {
        #expect(ScreenOrientation.portrait.rawValue == "portrait")
        #expect(ScreenOrientation.landscape.rawValue == "landscape")
    }

    @Test func batteryStateEnumRawValues() {
        #expect(BatteryState.charging.rawValue == "charging")
        #expect(BatteryState.full.rawValue == "full")
        #expect(BatteryState.unplugged.rawValue == "unplugged")
        #expect(BatteryState.unknown.rawValue == "unknown")
    }

    @Test func audioOutputTypeEnumRawValues() {
        #expect(AudioOutputType.wired.rawValue == "wired")
        #expect(AudioOutputType.hdmi.rawValue == "hdmi")
        #expect(AudioOutputType.bluetooth.rawValue == "bluetooth")
        #expect(AudioOutputType.usb.rawValue == "usb")
        #expect(AudioOutputType.other.rawValue == "other")
    }

    @Test func networkTypeEnumRawValues() {
        #expect(NetworkType.wifi.rawValue == "wifi")
        #expect(NetworkType.cellular.rawValue == "cellular")
        #expect(NetworkType.ethernet.rawValue == "ethernet")
        #expect(NetworkType.other.rawValue == "other")
    }

    // MARK: - AppDTO

    @Test func appDTOEncodesBundleIdAndVersion() {
        let dto = AppDTO(bundleId: "com.example.myapp", version: "2.1.0")

        let dict = encodeToDict(dto)
        #expect(dict?["bundleId"] as? String == "com.example.myapp")
        #expect(dict?["version"] as? String == "2.1.0")
        #expect(dict?["startTime"] == nil)
        #expect(dict?["firstInstallTime"] == nil)
        #expect(dict?["lastUpdateTime"] == nil)
    }

    @Test func appDTOEncodesOptionalTimes() {
        let dto = AppDTO(
            bundleId: "com.example.myapp",
            version: "2.1.0",
            firstInstallTime: 1685620800000,
            lastUpdateTime: 1700000000000,
            startTime: 1705312800000
        )

        let dict = encodeToDict(dto)
        #expect(dict?["bundleId"] as? String == "com.example.myapp")
        #expect(dict?["version"] as? String == "2.1.0")
        #expect(dict?["firstInstallTime"] as? Int64 == 1685620800000)
        #expect(dict?["lastUpdateTime"] as? Int64 == 1700000000000)
        #expect(dict?["startTime"] as? Int64 == 1705312800000)
    }

    // MARK: - InitRequestDTO

    @Test func initRequestDTOEncodesAllFields() {
        let dto = InitRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            app: InitRequestDTO.AppMetadata(bundleId: "com.example.myapp", version: "1.2.3"),
            skan: InitRequestDTO.SKANItems(items: ["abc123.skadnetwork", "def456.skadnetwork"])
        )

        let dict = encodeToDict(dto)
        #expect(dict?["publisherToken"] as? String == "pub-123")
        #expect(dict?["userId"] as? String == "user-1")

        let sdk = dict?["sdk"] as? [String: Any]
        #expect(sdk?["name"] as? String == "sdk-swift")
        #expect(sdk?["platform"] as? String == "ios")
        #expect(sdk?["version"] as? String == "4.0.0")

        let app = dict?["app"] as? [String: Any]
        #expect(app?["bundleId"] as? String == "com.example.myapp")
        #expect(app?["version"] as? String == "1.2.3")

        let skan = dict?["skan"] as? [String: Any]
        #expect((skan?["items"] as? [String]) == ["abc123.skadnetwork", "def456.skadnetwork"])
    }

    @Test func initRequestDTOAlwaysSendsSkanEvenWhenItemsEmpty() {
        // Empty items array is a positive "no SKAN configured" signal —
        // the `skan` key must still be present on the wire.
        let dto = InitRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            app: InitRequestDTO.AppMetadata(bundleId: "com.example.myapp", version: "1.2.3"),
            skan: InitRequestDTO.SKANItems(items: [])
        )

        let dict = encodeToDict(dto)
        let skan = dict?["skan"] as? [String: Any]
        #expect(skan != nil)
        #expect((skan?["items"] as? [String]) == [])
    }

    @Test func initRequestDTOAlwaysSendsAppEvenWithEmptyValues() {
        // App with empty Bundle.main fallbacks is still a valid positive
        // signal; the `app` key must remain present.
        let dto = InitRequestDTO(
            publisherToken: "pub-123",
            userId: "user-1",
            installId: "01890000-0000-7000-8000-000000000000",
            sdk: SDKDTO(name: "sdk-swift", platform: "ios", version: "4.0.0"),
            app: InitRequestDTO.AppMetadata(bundleId: "", version: ""),
            skan: InitRequestDTO.SKANItems(items: [])
        )

        let dict = encodeToDict(dto)
        let app = dict?["app"] as? [String: Any]
        #expect(app != nil)
        #expect((app?["bundleId"] as? String)?.isEmpty == true)
        #expect((app?["version"] as? String)?.isEmpty == true)
    }

    @Test func initRequestDTOAppMetadataEncodesBundleAndVersion() {
        let dto = InitRequestDTO.AppMetadata(bundleId: "com.example.myapp", version: "2.1.0")

        let dict = encodeToDict(dto)
        #expect(dict?["bundleId"] as? String == "com.example.myapp")
        #expect(dict?["version"] as? String == "2.1.0")
    }

    @Test func initRequestDTOSKANItemsEncodesItemsArray() {
        let dto = InitRequestDTO.SKANItems(items: ["abc.skadnetwork", "def.skadnetwork"])

        let dict = encodeToDict(dto)
        #expect((dict?["items"] as? [String]) == ["abc.skadnetwork", "def.skadnetwork"])
    }

    @Test func initRequestDTOSKANItemsEncodesEmptyArray() {
        let dto = InitRequestDTO.SKANItems(items: [])

        let dict = encodeToDict(dto)
        // Items key is always present, even with an empty array.
        #expect((dict?["items"] as? [String]) == [])
    }
}
