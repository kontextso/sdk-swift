import Testing
@testable import KontextSwiftSDK

struct PowerInfoTests {

    // MARK: batteryLevel(from:)

    @Test
    func batteryLevelUnavailableReturnsNil() {
        #expect(PowerInfo.batteryLevel(from: -1.0) == nil)
    }

    @Test
    func batteryLevelZero() {
        #expect(PowerInfo.batteryLevel(from: 0.0) == 0.0)
    }

    @Test
    func batteryLevelFull() {
        #expect(PowerInfo.batteryLevel(from: 1.0) == 100.0)
    }

    @Test
    func batteryLevelHalf() {
        #expect(PowerInfo.batteryLevel(from: 0.5) == 50.0)
    }
}
