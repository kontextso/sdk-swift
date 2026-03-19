import CoreTelephony
import Testing
@testable import KontextSwiftSDK

struct NetworkInfoTests {

    // MARK: mapRadioTechnology

    @Test
    func lte() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyLTE) == .lte)
    }

    @Test
    func gprs() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyGPRS) == .gprs)
    }

    @Test
    func edge() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyEdge) == .edge)
    }

    @Test
    func hspa() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyHSDPA) == .hspa)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyHSUPA) == .hspa)
    }

    @Test
    func threeG() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyWCDMA) == .threeG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyCDMA1x) == .twoG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyCDMAEVDORev0) == .threeG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyCDMAEVDORevA) == .threeG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyCDMAEVDORevB) == .threeG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyeHRPD) == .threeG)
    }

    @Test
    func unknownReturnsNil() {
        #expect(NetworkInfo.mapRadioTechnology("unknown_tech") == nil)
        #expect(NetworkInfo.mapRadioTechnology(nil) == nil)
        #expect(NetworkInfo.mapRadioTechnology("") == nil)
    }

    @available(iOS 14.1, *)
    @Test
    func fiveG() {
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyNR) == .fiveG)
        #expect(NetworkInfo.mapRadioTechnology(CTRadioAccessTechnologyNRNSA) == .fiveG)
    }
}
