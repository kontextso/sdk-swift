struct RegulatoryDTO: Encodable {
    let gdpr: Int?
    let gdprConsent: String?
    let coppa: Int?
    let usPrivacy: String?
    let gpp: String?
    let gppSid: [Int]?

    init?(from model: Regulatory?) {
        guard let model else { return nil }
        gdpr = model.gdpr
        gdprConsent = model.gdprConsent
        coppa = model.coppa
        usPrivacy = model.usPrivacy
        gpp = model.gpp
        gppSid = model.gppSid
    }
}
