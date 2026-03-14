import Testing
@testable import KontextSwiftSDK

struct RegulatoryTests {
    @Test
    func defaultsAllNil() {
        let regulatory = Regulatory()
        #expect(regulatory.gdpr == nil)
        #expect(regulatory.gdprConsent == nil)
        #expect(regulatory.coppa == nil)
        #expect(regulatory.usPrivacy == nil)
        #expect(regulatory.gpp == nil)
        #expect(regulatory.gppSid == nil)
    }

    @Test
    func storesProvidedValues() {
        let regulatory = Regulatory(
            gdpr: 1,
            gdprConsent: "consent-string",
            coppa: 0,
            usPrivacy: "1YNN",
            gpp: "gpp-string",
            gppSid: [1, 2]
        )
        #expect(regulatory.gdpr == 1)
        #expect(regulatory.gdprConsent == "consent-string")
        #expect(regulatory.coppa == 0)
        #expect(regulatory.usPrivacy == "1YNN")
        #expect(regulatory.gpp == "gpp-string")
        #expect(regulatory.gppSid == [1, 2])
    }
}
