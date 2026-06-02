import Foundation
@testable import KontextSwiftSDK
import Testing

struct SDKInfoTests {

    @Test func sdkInfoCurrent() {
        let sdk = SDKInfo.current
        #expect(sdk.name == "sdk-swift")
        #expect(sdk.platform == "ios")
        #expect(sdk.version == "4.0.1")
    }

    // MARK: - toDTO()

    @Test func toDTOConvertsNamePlatformVersion() {
        let info = SDKInfo(name: "sdk-swift", platform: "ios", version: "4.0.0")

        let dto = info.toDTO()

        #expect(dto.name == "sdk-swift")
        #expect(dto.platform == "ios")
        #expect(dto.version == "4.0.0")
    }

    @Test func currentToDTOHasExpectedValues() {
        let dto = SDKInfo.current.toDTO()

        #expect(dto.name == "sdk-swift")
        #expect(dto.platform == "ios")
        #expect(dto.version == "4.0.1")
    }
}
