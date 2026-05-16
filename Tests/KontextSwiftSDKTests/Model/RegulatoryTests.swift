import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct RegulatoryTests {

    // MARK: - Field coverage

    @Test func regulatoryWithAllFields() {
        let reg = Regulatory(
            gdpr: 1,
            gdprConsent: "consent-string",
            coppa: 0,
            gpp: "gpp-string",
            gppSid: [2, 6],
            usPrivacy: "1YNN"
        )

        #expect(reg.gdpr == 1)
        #expect(reg.gdprConsent == "consent-string")
        #expect(reg.coppa == 0)
        #expect(reg.gpp == "gpp-string")
        #expect(reg.gppSid == [2, 6])
        #expect(reg.usPrivacy == "1YNN")
    }

    @Test func regulatoryWithNilFields() {
        let reg = Regulatory()

        #expect(reg.gdpr == nil)
        #expect(reg.gdprConsent == nil)
        #expect(reg.coppa == nil)
        #expect(reg.gpp == nil)
        #expect(reg.gppSid == nil)
        #expect(reg.usPrivacy == nil)
    }

    // MARK: - GDPR values

    @Test func regulatoryGdprValues() {
        let gdpr0 = Regulatory(gdpr: 0)
        #expect(gdpr0.gdpr == 0)

        let gdpr1 = Regulatory(gdpr: 1)
        #expect(gdpr1.gdpr == 1)
    }

    // MARK: - COPPA values

    @Test func regulatoryCoppaValues() {
        let coppa0 = Regulatory(coppa: 0)
        #expect(coppa0.coppa == 0)

        let coppa1 = Regulatory(coppa: 1)
        #expect(coppa1.coppa == 1)
    }

    // MARK: - Equality

    @Test func regulatoryEquality() {
        let reg1 = Regulatory(gdpr: 1, gdprConsent: "abc", coppa: 0)
        let reg2 = Regulatory(gdpr: 1, gdprConsent: "abc", coppa: 0)
        let reg3 = Regulatory(gdpr: 0, gdprConsent: "abc", coppa: 0)

        #expect(reg1 == reg2)
        #expect(reg1 != reg3)
    }

    // MARK: - toDTO()

    @Test func toDTOConvertsAllFields() {
        let regulatory = Regulatory(
            gdpr: 1,
            gdprConsent: "CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA",
            coppa: 0,
            gpp: "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA~1YNN",
            gppSid: [7, 8],
            usPrivacy: "1YNN"
        )

        let dto = regulatory.toDTO()

        #expect(dto.gdpr == 1)
        #expect(dto.gdprConsent == "CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA")
        #expect(dto.coppa == 0)
        #expect(dto.gpp == "DBACNYA~CPXxRfAPXxRfAAfKABENB-CgAAAAAAAAAAYgAAAAAAAA~1YNN")
        #expect(dto.gppSid == [7, 8])
        #expect(dto.usPrivacy == "1YNN")
    }

    @Test func toDTOPreservesNilFields() {
        let regulatory = Regulatory()

        let dto = regulatory.toDTO()

        #expect(dto.gdpr == nil)
        #expect(dto.gdprConsent == nil)
        #expect(dto.coppa == nil)
        #expect(dto.gpp == nil)
        #expect(dto.gppSid == nil)
        #expect(dto.usPrivacy == nil)
    }

    @Test func toDTOPreservesPartialFields() {
        let regulatory = Regulatory(gdpr: 1, gdprConsent: "consent-string")

        let dto = regulatory.toDTO()

        #expect(dto.gdpr == 1)
        #expect(dto.gdprConsent == "consent-string")
        #expect(dto.coppa == nil)
        #expect(dto.gpp == nil)
        #expect(dto.gppSid == nil)
        #expect(dto.usPrivacy == nil)
    }

    @Test func toDTOPreservesEmptyGppSidArray() {
        // Empty array distinct from nil — server treats them differently.
        let regulatory = Regulatory(gppSid: [])

        let dto = regulatory.toDTO()

        #expect(dto.gppSid == [])
    }
}
