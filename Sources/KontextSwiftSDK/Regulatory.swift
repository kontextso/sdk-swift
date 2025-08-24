//
//  Regulatory.swift
//  KontextSwiftSDK
//

/// Information about regulatory requirements that apply to the request.
public struct Regulatory: Sendable {
    /// Flag that indicates whether or not the request is subject to GDPR regulations (0 = No, 1 = Yes, null = Unknown).
    public let gdpr: Int?
    /// When GDPR regulations are in effect this attribute contains the Transparency and Consent Framework's Consent String data structure
    ///
    /// https://github.com/InteractiveAdvertisingBureau/GDPR-Transparency-and-Consent-Framework/blob/master/TCFv2/IAB%20Tech%20Lab%20-%20Consent%20string%20and%20vendor%20list%20formats%20v2.md#about-the-transparency--consent-string-tc-string
    public let gdprConsent: String?
    /// Flag whether the request is subject to COPPA (0 = No, 1 = Yes, null = Unknown).
    ///
    /// https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa
    public let coppa: Int?
    /// Global Privacy Platform (GPP) consent string.
     ///
     /// https://github.com/InteractiveAdvertisingBureau/Global-Privacy-Platform
    public let gpp: String?
    /// List of the section(s) of the GPP string which should be applied for this transaction
    public let gppSid: [Int]?
    /// Communicates signals regarding consumer privacy under US privacy regulation under CCPA and LSPA.
    ///
    /// https://github.com/InteractiveAdvertisingBureau/USPrivacy/blob/master/CCPA/US%20Privacy%20String.md
    public let usPrivacy: String?

    /**
     Initializes a new Regulatory object.
     - Parameters:
        - gdpr: Flag that indicates whether or not the request is subject to GDPR regulations (0 = No, 1 = Yes, null = Unknown).
        - gdprConsent: When GDPR regulations are in effect this attribute contains the Transparency and Consent Framework's Consent String data structure.
        - coppa: Flag whether the request is subject to COPPA (0 = No, 1 = Yes, null = Unknown).
        - usPrivacy: Communicates signals regarding consumer privacy under US privacy regulation under CCPA and LSPA.
        - gpp: Global Privacy Platform (GPP) consent string.
        - gppSid: List of the section(s) of the GPP string which should be applied for this transaction.
     */
    init(
        gdpr: Int? = nil,
        gdprConsent: String? = nil,
        coppa: Int? = nil,
        usPrivacy: String? = nil,
        gpp: String? = nil,
        gppSid: [Int]? = nil
    ) {
        self.gdpr = gdpr
        self.gdprConsent = gdprConsent
        self.coppa = coppa
        self.usPrivacy = usPrivacy
        self.gpp = gpp
        self.gppSid = gppSid
    }
}
