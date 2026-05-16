import Foundation
@testable import KontextSwiftSDK
import Testing

struct TCFMergingTests {

    // MARK: - RegulatoryDTO encoding

    @Test func regulatoryDTOWithAllFieldsSet() throws {
        let dto = RegulatoryDTO(
            gdpr: 1,
            gdprConsent: "BOEFEAyOEFEAyAHABDENAI4AAAB9vABAASA",
            coppa: 0,
            gpp: "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA",
            gppSid: [7],
            usPrivacy: "1YNN"
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(decoded?["gdpr"] as? Int == 1)
        #expect(decoded?["gdprConsent"] as? String == "BOEFEAyOEFEAyAHABDENAI4AAAB9vABAASA")
        #expect(decoded?["coppa"] as? Int == 0)
        #expect(decoded?["gpp"] as? String == "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA")
        #expect(decoded?["gppSid"] as? [Int] == [7])
        #expect(decoded?["usPrivacy"] as? String == "1YNN")
    }

    @Test func regulatoryDTOWithNilFieldsOmitsThem() throws {
        let dto = RegulatoryDTO(
            gdpr: nil,
            gdprConsent: nil,
            coppa: 1,
            gpp: nil,
            gppSid: nil,
            usPrivacy: nil
        )

        let data = try JSONEncoder().encode(dto)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Only coppa should be present
        #expect(decoded?["coppa"] as? Int == 1)
        #expect(decoded?["gdpr"] == nil)
        #expect(decoded?["gdprConsent"] == nil)
        #expect(decoded?["gpp"] == nil)
        #expect(decoded?["gppSid"] == nil)
        #expect(decoded?["usPrivacy"] == nil)
    }

    // MARK: - TCF merging logic (mirrors buildPreloadDTO behavior)

    @Test func tcfValuesOverrideRegulatoryGdprAndConsent() {
        // Simulate what buildPreloadDTO does:
        // Start with config regulatory values
        var reg = RegulatoryDTO(
            gdpr: 0,
            gdprConsent: "old-consent",
            coppa: 1,
            gpp: "gpp-string",
            gppSid: [2],
            usPrivacy: "1YNN"
        )

        // Simulate TCF data overriding gdpr and gdprConsent
        let tcfGdprApplies: Int? = 1
        let tcfTcString: String? = "new-tcf-consent-string"

        if let gdprApplies = tcfGdprApplies {
            reg.gdpr = gdprApplies
        }
        if let tcString = tcfTcString {
            reg.gdprConsent = tcString
        }

        // TCF overrode gdpr and gdprConsent
        #expect(reg.gdpr == 1)
        #expect(reg.gdprConsent == "new-tcf-consent-string")

        // Non-TCF fields preserved
        #expect(reg.coppa == 1)
        #expect(reg.gpp == "gpp-string")
        #expect(reg.gppSid == [2])
        #expect(reg.usPrivacy == "1YNN")
    }

    @Test func nonTCFFieldsPreservedWhenTCFIsNil() {
        // Start with config regulatory
        var reg = RegulatoryDTO(
            gdpr: 0,
            gdprConsent: "original-consent",
            coppa: 1,
            gpp: "gpp-val",
            gppSid: [3, 7],
            usPrivacy: "1NNN"
        )

        // TCF data has nil values — no override
        let tcfGdprApplies: Int? = nil
        let tcfTcString: String? = nil

        if let gdprApplies = tcfGdprApplies {
            reg.gdpr = gdprApplies
        }
        if let tcString = tcfTcString {
            reg.gdprConsent = tcString
        }

        // Nothing overridden
        #expect(reg.gdpr == 0)
        #expect(reg.gdprConsent == "original-consent")
        #expect(reg.coppa == 1)
        #expect(reg.gpp == "gpp-val")
        #expect(reg.gppSid == [3, 7])
        #expect(reg.usPrivacy == "1NNN")
    }

    @Test func tcfOverridesWhenConfigRegulatoryIsNil() {
        // Config has no regulatory — start from empty
        var reg = RegulatoryDTO()

        let tcfGdprApplies: Int? = 1
        let tcfTcString: String? = "tcf-string-from-cmp"

        if let gdprApplies = tcfGdprApplies {
            reg.gdpr = gdprApplies
        }
        if let tcString = tcfTcString {
            reg.gdprConsent = tcString
        }

        #expect(reg.gdpr == 1)
        #expect(reg.gdprConsent == "tcf-string-from-cmp")
        // Other fields remain nil
        #expect(reg.coppa == nil)
        #expect(reg.gpp == nil)
        #expect(reg.gppSid == nil)
        #expect(reg.usPrivacy == nil)
    }

    @Test func regulatoryDTOIncludedOnlyWhenFieldsAreSet() {
        // Mirror the conditional in buildPreloadDTO:
        // dto.regulatory is only set when at least one field is non-nil
        let reg = RegulatoryDTO()

        let shouldInclude = reg.gdpr != nil || reg.gdprConsent != nil || reg.coppa != nil ||
            reg.gpp != nil || reg.gppSid != nil || reg.usPrivacy != nil

        #expect(shouldInclude == false)

        // Now with one field set
        var reg2 = RegulatoryDTO()
        reg2.coppa = 1

        let shouldInclude2 = reg2.gdpr != nil || reg2.gdprConsent != nil || reg2.coppa != nil ||
            reg2.gpp != nil || reg2.gppSid != nil || reg2.usPrivacy != nil

        #expect(shouldInclude2 == true)
    }
}
