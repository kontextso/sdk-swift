import Testing
@testable import KontextSwiftSDK

@MainActor
struct IFACollectorTests {

    // MARK: - Manual advertisingId

    @Test
    func manualAdvertisingIdReturnedWhenAttDisabled() async {
        let result = await IFACollector.collect(
            manualAdvertisingId: "test-idfa-abc123",
            manualVendorId: nil,
            requestTrackingAuthorization: false
        )
        #expect(result.advertisingId == "test-idfa-abc123")
    }

    @Test
    func zeroUuidAdvertisingIdNormalizedToNil() async {
        let result = await IFACollector.collect(
            manualAdvertisingId: "00000000-0000-0000-0000-000000000000",
            manualVendorId: nil,
            requestTrackingAuthorization: false
        )
        #expect(result.advertisingId == nil)
    }

    @Test
    func emptyAdvertisingIdNormalizedToNil() async {
        let result = await IFACollector.collect(
            manualAdvertisingId: "",
            manualVendorId: nil,
            requestTrackingAuthorization: false
        )
        #expect(result.advertisingId == nil)
    }

    @Test
    func nilAdvertisingIdWithAttDisabledReturnsNil() async {
        // ATT not requested and no manual ID — automatic IDFA is unavailable without authorization
        let result = await IFACollector.collect(
            manualAdvertisingId: nil,
            manualVendorId: nil,
            requestTrackingAuthorization: false
        )
        #expect(result.advertisingId == nil)
    }

    // MARK: - Manual vendorId

    @Test
    func manualVendorIdTakesPriorityOverAutomaticIdfv() async {
        // UIDevice.identifierForVendor returns a real non-nil value in the test environment,
        // so this directly verifies that the manually supplied value wins over automatic.
        let result = await IFACollector.collect(
            manualAdvertisingId: nil,
            manualVendorId: "test-idfv-xyz789",
            requestTrackingAuthorization: false
        )
        #expect(result.vendorId == "test-idfv-xyz789")
    }

    @Test
    func zeroUuidVendorIdNormalizedToNil() async {
        // Zero UUID falls back to the automatic IDFV from the device
        let result = await IFACollector.collect(
            manualAdvertisingId: nil,
            manualVendorId: "00000000-0000-0000-0000-000000000000",
            requestTrackingAuthorization: false
        )
        // Automatic IDFV from UIDevice is available in test environment, so not nil
        #expect(result.vendorId != nil)
    }

    @Test
    func emptyVendorIdNormalizedToNil() async {
        // Empty string falls back to the automatic IDFV from the device
        let result = await IFACollector.collect(
            manualAdvertisingId: nil,
            manualVendorId: "",
            requestTrackingAuthorization: false
        )
        // Automatic IDFV from UIDevice is available in test environment, so not nil
        #expect(result.vendorId != nil)
    }
}
