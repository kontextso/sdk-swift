import Foundation
import Testing
@testable import KontextSwiftSDK

/// Round-trip / encoding tests for the pile of small leaf DTOs
/// that have almost no logic but are wire-format-critical.
struct SmallEncodingDTOTests {
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return enc
    }()

    private func encodedDict(_ value: any Encodable) throws -> [String: Any] {
        let data = try encoder.encode(value)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - SDKDTO

    @Test
    func sdkDTOEncodesAllFields() throws {
        let dto = SDKDTO(name: "sdk-swift", version: "2.1.0", platform: "ios")
        let dict = try encodedDict(dto)
        #expect(dict["name"] as? String == "sdk-swift")
        #expect(dict["version"] as? String == "2.1.0")
        #expect(dict["platform"] as? String == "ios")
    }

    // MARK: - OSDTO

    @Test
    func osDTOEncodesAllFields() throws {
        let dto = OSDTO(name: "ios", version: "17.2", locale: "cs-CZ", timezone: "Europe/Prague")
        let dict = try encodedDict(dto)
        #expect(dict["name"] as? String == "ios")
        #expect(dict["version"] as? String == "17.2")
        #expect(dict["locale"] as? String == "cs-CZ")
        #expect(dict["timezone"] as? String == "Europe/Prague")
    }

    // MARK: - ScreenDTO

    @Test
    func screenDTOEncodesAllFields() throws {
        let dto = ScreenDTO(width: 390, height: 844, dpr: 3, orientation: .portrait, darkMode: true)
        let dict = try encodedDict(dto)
        #expect(dict["width"] as? Double == 390)
        #expect(dict["height"] as? Double == 844)
        #expect(dict["dpr"] as? Double == 3)
        #expect(dict["orientation"] as? String == "portrait")
        #expect(dict["darkMode"] as? Bool == true)
    }

    @Test
    func screenDTOEncodesLandscapeOrientation() throws {
        let dto = ScreenDTO(width: 844, height: 390, dpr: 3, orientation: .landscape, darkMode: false)
        let dict = try encodedDict(dto)
        #expect(dict["orientation"] as? String == "landscape")
    }

    @Test
    func screenDTOOmitsOrientationWhenNil() throws {
        let dto = ScreenDTO(width: 1, height: 1, dpr: 1, orientation: nil, darkMode: false)
        let dict = try encodedDict(dto)
        // JSONEncoder omits nil optional by default.
        #expect(dict["orientation"] == nil)
    }

    // MARK: - HardwareDTO

    @Test
    func hardwareDTOEncodesAllFields() throws {
        let dto = HardwareDTO(brand: "Apple", model: "iPhone17,3", type: .handset, sdCardAvailable: false)
        let dict = try encodedDict(dto)
        #expect(dict["brand"] as? String == "Apple")
        #expect(dict["model"] as? String == "iPhone17,3")
        #expect(dict["type"] as? String == "handset")
        #expect(dict["sdCardAvailable"] as? Bool == false)
    }

    @Test
    func hardwareDTOOmitsNilBrandAndModel() throws {
        let dto = HardwareDTO(brand: nil, model: nil, type: .other, sdCardAvailable: false)
        let dict = try encodedDict(dto)
        #expect(dict["brand"] == nil)
        #expect(dict["model"] == nil)
        #expect(dict["type"] as? String == "other")
    }

    // MARK: - PowerDTO

    @Test
    func powerDTOEncodesAllFields() throws {
        let dto = PowerDTO(batteryLevel: 83, batteryState: .charging, lowPowerMode: false)
        let dict = try encodedDict(dto)
        #expect(dict["batteryLevel"] as? Double == 83)
        #expect(dict["batteryState"] as? String == "charging")
        #expect(dict["lowPowerMode"] as? Bool == false)
    }

    @Test
    func powerDTOEncodesAllStates() throws {
        for state in [BatteryState.charging, .full, .unplugged, .unknown] {
            let dto = PowerDTO(batteryLevel: nil, batteryState: state, lowPowerMode: nil)
            let dict = try encodedDict(dto)
            #expect(dict["batteryState"] as? String == state.rawValue)
        }
    }

    @Test
    func powerDTOOmitsNilFields() throws {
        let dto = PowerDTO(batteryLevel: nil, batteryState: nil, lowPowerMode: nil)
        let dict = try encodedDict(dto)
        #expect(dict["batteryLevel"] == nil)
        #expect(dict["batteryState"] == nil)
        #expect(dict["lowPowerMode"] == nil)
    }

    // MARK: - AudioDTO

    @Test
    func audioDTOEncodesAllFields() throws {
        let dto = AudioDTO(volume: 65, muted: false, outputPluggedIn: true, outputType: [.wired, .bluetooth])
        let dict = try encodedDict(dto)
        #expect(dict["volume"] as? Int == 65)
        #expect(dict["muted"] as? Bool == false)
        #expect(dict["outputPluggedIn"] as? Bool == true)
        #expect(dict["outputType"] as? [String] == ["wired", "bluetooth"])
    }

    @Test
    func audioDTOEncodesEmptyOutputTypes() throws {
        let dto = AudioDTO(volume: 0, muted: true, outputPluggedIn: false, outputType: [])
        let dict = try encodedDict(dto)
        #expect(dict["outputType"] as? [String] == [])
    }

    // MARK: - NetworkDTO

    @Test
    func networkDTOEncodesAllFields() throws {
        let dto = NetworkDTO(userAgent: "Mozilla/5.0", type: .wifi, detail: .lte, carrier: "T-Mobile CZ")
        let dict = try encodedDict(dto)
        #expect(dict["userAgent"] as? String == "Mozilla/5.0")
        #expect(dict["type"] as? String == "wifi")
        #expect(dict["detail"] as? String == "lte")
        #expect(dict["carrier"] as? String == "T-Mobile CZ")
    }

    @Test
    func networkDTOOmitsNilFieldsExceptType() throws {
        let dto = NetworkDTO(userAgent: nil, type: .other, detail: nil, carrier: nil)
        let dict = try encodedDict(dto)
        #expect(dict["userAgent"] == nil)
        #expect(dict["type"] as? String == "other")
        #expect(dict["detail"] == nil)
        #expect(dict["carrier"] == nil)
    }

    @Test
    func networkDTOEncodesAllDetailValues() throws {
        let cases: [(NetworkDetail, String)] = [
            (.twoG, "2g"), (.threeG, "3g"), (.fourG, "4g"), (.lte, "lte"),
            (.fiveG, "5g"), (.nr, "nr"), (.hspa, "hspa"), (.edge, "edge"), (.gprs, "gprs"),
        ]
        for (detail, expected) in cases {
            let dto = NetworkDTO(userAgent: nil, type: .cellular, detail: detail, carrier: nil)
            let dict = try encodedDict(dto)
            #expect(dict["detail"] as? String == expected)
        }
    }

    // MARK: - AppDTO

    @Test
    func appDTOEncodesAllFields() throws {
        let dto = AppDTO(
            bundleId: "com.example.app",
            version: "20.9.1",
            storeUrl: "https://apps.apple.com/app/id123",
            firstInstallTime: 1_700_000_000,
            lastUpdateTime: 1_701_000_000,
            startTime: 1_702_000_000
        )
        let dict = try encodedDict(dto)
        #expect(dict["bundleId"] as? String == "com.example.app")
        #expect(dict["version"] as? String == "20.9.1")
        #expect(dict["storeUrl"] as? String == "https://apps.apple.com/app/id123")
        #expect(dict["firstInstallTime"] as? Int64 == 1_700_000_000)
        #expect(dict["lastUpdateTime"] as? Int64 == 1_701_000_000)
        #expect(dict["startTime"] as? Int64 == 1_702_000_000)
    }

    @Test
    func appDTOOmitsNilFields() throws {
        let dto = AppDTO(bundleId: nil, version: "1.0", storeUrl: nil, firstInstallTime: nil, lastUpdateTime: nil, startTime: 0)
        let dict = try encodedDict(dto)
        #expect(dict["bundleId"] == nil)
        #expect(dict["storeUrl"] == nil)
        #expect(dict["firstInstallTime"] == nil)
        #expect(dict["lastUpdateTime"] == nil)
    }
}
