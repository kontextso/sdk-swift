import Foundation
import Testing
@testable import KontextSwiftSDK

/// Verifies the Info struct → DTO toModel() conversions preserve every field.
struct InfoMappingTests {
    @Test
    func appInfoToDTOCopiesAllFields() {
        let info = AppInfo(
            bundleId: "com.example.app",
            version: "1.2.3",
            storeUrl: "https://apps.apple.com/app/id123",
            installTime: 1_700_000_000,
            updateTime: 1_701_000_000,
            startTime: 1_702_000_000
        )
        let dto = info.toModel()
        #expect(dto.bundleId == "com.example.app")
        #expect(dto.version == "1.2.3")
        #expect(dto.storeUrl == "https://apps.apple.com/app/id123")
        #expect(dto.firstInstallTime == 1_700_000_000)
        #expect(dto.lastUpdateTime == 1_701_000_000)
        #expect(dto.startTime == 1_702_000_000)
    }

    @Test
    func audioInfoToDTOCopiesAllFields() {
        let info = AudioInfo(volume: 55, muted: false, outputPluggedIn: true, outputType: [.wired, .bluetooth])
        let dto = info.toModel()
        #expect(dto.volume == 55)
        #expect(dto.muted == false)
        #expect(dto.outputPluggedIn == true)
        #expect(dto.outputType == [.wired, .bluetooth])
    }

    @Test
    func osInfoToDTOCopiesAllFields() {
        let info = OSInfo(name: "ios", version: "17.2", locale: "cs-CZ", timezone: "Europe/Prague")
        let dto = info.toModel()
        #expect(dto.name == "ios")
        #expect(dto.version == "17.2")
        #expect(dto.locale == "cs-CZ")
        #expect(dto.timezone == "Europe/Prague")
    }

    @Test
    func hardwareInfoToDTOCopiesAllFields() {
        let info = HardwareInfo(brand: "Apple", model: "iPhone17,3", type: .handset, sdCardAvailable: false)
        let dto = info.toModel()
        #expect(dto.brand == "Apple")
        #expect(dto.model == "iPhone17,3")
        #expect(dto.type == .handset)
        #expect(dto.sdCardAvailable == false)
    }

    @Test
    func screenInfoToDTORenamesScreenDimensionsToWidthHeight() {
        // ScreenInfo has screenWidth / screenHeight / scale; ScreenDTO flattens those to width/height/dpr.
        let info = ScreenInfo(screenWidth: 390, screenHeight: 844, scale: 3, orientation: .portrait, isDarkMode: true)
        let dto = info.toModel()
        #expect(dto.width == 390)
        #expect(dto.height == 844)
        #expect(dto.dpr == 3)
        #expect(dto.orientation == .portrait)
        #expect(dto.darkMode == true)
    }

    @Test
    func powerInfoToDTOCopiesAllFields() {
        let info = PowerInfo(batteryLevel: 42, batteryState: .charging, lowPowerMode: true)
        let dto = info.toModel()
        #expect(dto.batteryLevel == 42)
        #expect(dto.batteryState == .charging)
        #expect(dto.lowPowerMode == true)
    }

    @Test
    func networkInfoToDTORenamesCarrierAndNetworkFields() {
        // NetworkInfo has networkType/networkDetail/carrierName; DTO uses type/detail/carrier.
        let info = NetworkInfo(userAgent: "ua", carrierName: "T-Mobile", networkType: .cellular, networkDetail: .fiveG)
        let dto = info.toModel()
        #expect(dto.userAgent == "ua")
        #expect(dto.type == .cellular)
        #expect(dto.detail == .fiveG)
        #expect(dto.carrier == "T-Mobile")
    }

    @Test
    func deviceInfoToDTOWiresAllSubObjects() {
        let info = DeviceInfo(
            os: OSInfo(name: "ios", version: "17", locale: "en-US", timezone: "UTC"),
            hardware: HardwareInfo(brand: "Apple", model: "iPhone", type: .handset, sdCardAvailable: false),
            screen: ScreenInfo(screenWidth: 10, height: 20, scale: 1, orientation: .portrait, isDarkMode: false),
            power: PowerInfo(batteryLevel: 100, batteryState: .full, lowPowerMode: false),
            audio: AudioInfo(volume: 10, muted: true, outputPluggedIn: false, outputType: []),
            network: NetworkInfo(userAgent: "ua", carrierName: nil, networkType: .wifi, networkDetail: nil)
        )
        let dto = info.toModel()
        #expect(dto.os.name == "ios")
        #expect(dto.hardware.brand == "Apple")
        #expect(dto.screen.width == 10)
        #expect(dto.power.batteryLevel == 100)
        #expect(dto.audio.volume == 10)
        #expect(dto.network.userAgent == "ua")
    }

    @Test
    func sdkInfoToDTOCopiesAllFields() {
        let info = SDKInfo(name: "sdk-swift", version: "2.1.0", platform: "ios")
        let dto = info.toModel()
        #expect(dto.name == "sdk-swift")
        #expect(dto.version == "2.1.0")
        #expect(dto.platform == "ios")
    }
}

// Convenience init so tests can construct ScreenInfo without collisions.
private extension ScreenInfo {
    init(screenWidth: CGFloat, height: CGFloat, scale: CGFloat, orientation: ScreenOrientation?, isDarkMode: Bool) {
        self.init(screenWidth: screenWidth, screenHeight: height, scale: scale, orientation: orientation, isDarkMode: isDarkMode)
    }
}
