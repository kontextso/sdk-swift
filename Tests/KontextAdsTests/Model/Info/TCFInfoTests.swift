import Foundation
import Testing
@testable import KontextSwiftSDK

struct TCFInfoTests {

    // MARK: current()

    @Test
    func currentReadsTCStringAndGdprApplies() {
        let defaults = makeUserDefaults()
        defaults.set("CPzHq4APzHq4A", forKey: "IABTCF_TCString")
        defaults.set(1, forKey: "IABTCF_gdprApplies")

        let info = TCFInfo.current(userDefaults: defaults)

        #expect(info.gdprConsent == "CPzHq4APzHq4A")
        #expect(info.gdpr == 1)
    }

    @Test
    func currentReturnsEmptyWhenNoTCFDataPresent() {
        let info = TCFInfo.current(userDefaults: makeUserDefaults())

        #expect(info.isEmpty)
        #expect(info.gdpr == nil)
        #expect(info.gdprConsent == nil)
    }

    @Test
    func currentIgnoresEmptyTCString() {
        let defaults = makeUserDefaults()
        defaults.set("", forKey: "IABTCF_TCString")

        let info = TCFInfo.current(userDefaults: defaults)

        #expect(info.gdprConsent == nil)
    }

    // MARK: normalizedGDPRFlag (tested via current())

    @Test
    func gdprFlagFromNSNumber() {
        let defaults0 = makeUserDefaults()
        defaults0.set(NSNumber(value: 0), forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaults0).gdpr == 0)

        let defaults1 = makeUserDefaults()
        defaults1.set(NSNumber(value: 1), forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaults1).gdpr == 1)

        let defaultsInvalid = makeUserDefaults()
        defaultsInvalid.set(NSNumber(value: 2), forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaultsInvalid).gdpr == nil)
    }

    @Test
    func gdprFlagFromBool() {
        let defaultsTrue = makeUserDefaults()
        defaultsTrue.set(true, forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaultsTrue).gdpr == 1)

        let defaultsFalse = makeUserDefaults()
        defaultsFalse.set(false, forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaultsFalse).gdpr == 0)
    }

    @Test
    func gdprFlagFromString() {
        let defaults1 = makeUserDefaults()
        defaults1.set("1", forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaults1).gdpr == 1)

        let defaults0 = makeUserDefaults()
        defaults0.set("0", forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaults0).gdpr == 0)

        let defaultsInvalid = makeUserDefaults()
        defaultsInvalid.set("yes", forKey: "IABTCF_gdprApplies")
        #expect(TCFInfo.current(userDefaults: defaultsInvalid).gdpr == nil)
    }

    // MARK: mergedRegulatory()

    @Test
    func mergedRegulatoryReturnsNilWhenEmptyAndNoRegulatory() {
        let info = TCFInfo(gdpr: nil, gdprConsent: nil)
        #expect(info.mergedRegulatory(from: nil) == nil)
    }

    @Test
    func mergedRegulatoryPassThroughWhenEmpty() {
        let info = TCFInfo(gdpr: nil, gdprConsent: nil)
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "consent")

        let result = info.mergedRegulatory(from: regulatory)

        #expect(result?.gdpr == 1)
        #expect(result?.gdprConsent == "consent")
    }

    @Test
    func mergedRegulatoryTCFTakesPrecedenceOverRegulatory() {
        let info = TCFInfo(gdpr: 1, gdprConsent: "tcf-consent")
        let regulatory = Regulatory(gdpr: 0, gdprConsent: "manual-consent")

        let result = info.mergedRegulatory(from: regulatory)

        #expect(result?.gdpr == 1)
        #expect(result?.gdprConsent == "tcf-consent")
    }

    @Test
    func mergedRegulatoryFallsBackToRegulatoryWhenTCFFieldsNil() {
        let info = TCFInfo(gdpr: nil, gdprConsent: "tcf-consent")
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "manual-consent")

        let result = info.mergedRegulatory(from: regulatory)

        #expect(result?.gdpr == 1)
        #expect(result?.gdprConsent == "tcf-consent")
    }

    @Test
    func mergedRegulatoryPreservesNonTCFFields() {
        let info = TCFInfo(gdpr: 1, gdprConsent: "tcf-consent")
        let regulatory = Regulatory(coppa: 1, gpp: "gpp-string", gppSid: [1, 2])

        let result = info.mergedRegulatory(from: regulatory)

        #expect(result?.coppa == 1)
        #expect(result?.gpp == "gpp-string")
        #expect(result?.gppSid == [1, 2])
    }

    @Test
    func mergedRegulatoryWithNoRegulatoryCreateFromTCFOnly() {
        let info = TCFInfo(gdpr: 1, gdprConsent: "tcf-consent")

        let result = info.mergedRegulatory(from: nil)

        #expect(result?.gdpr == 1)
        #expect(result?.gdprConsent == "tcf-consent")
        #expect(result?.coppa == nil)
    }
}

private func makeUserDefaults() -> UserDefaults {
    let suiteName = UUID().uuidString
    let defaults = UserDefaults(suiteName: suiteName)!
    return defaults
}
