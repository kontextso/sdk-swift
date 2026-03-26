import Foundation

/// IAB Transparency and Consent Framework data read from UserDefaults.
/// Consent SDKs store TCF values under standardized keys after user interacts with a consent banner.
struct TCFCollector {
    /// Whether GDPR applies (0 = No, 1 = Yes, nil = Unknown)
    let gdpr: Int?
    /// IAB TCF consent string encoding the user's consent choices
    let gdprConsent: String?

    /// True if no TCF data was found in UserDefaults
    var isEmpty: Bool {
        gdpr == nil && gdprConsent == nil
    }

    /// Reads TCF consent data from UserDefaults
    static func current(userDefaults: UserDefaults = .standard) -> TCFCollector {
        let tcString = userDefaults.string(forKey: "IABTCF_TCString")
        let gdprApplies = userDefaults.object(forKey: "IABTCF_gdprApplies")

        return TCFCollector(
            gdpr: normalizedGDPRFlag(from: gdprApplies),
            gdprConsent: (tcString?.isEmpty == false) ? tcString : nil
        )
    }

    /// Merges TCF data with developer-supplied Regulatory.
    /// TCF values take precedence; fields not in TCF (coppa, gpp, usPrivacy) come from regulatory.
    func mergedRegulatory(from regulatory: Regulatory?) -> Regulatory? {
        guard !isEmpty else { return regulatory }

        if let regulatory {
            return Regulatory(
                gdpr: gdpr ?? regulatory.gdpr,
                gdprConsent: gdprConsent ?? regulatory.gdprConsent,
                coppa: regulatory.coppa,
                usPrivacy: regulatory.usPrivacy,
                gpp: regulatory.gpp,
                gppSid: regulatory.gppSid
            )
        }

        return Regulatory(gdpr: gdpr, gdprConsent: gdprConsent)
    }

    /// Normalizes the raw GDPR flag value to 0 or 1.
    /// Handles NSNumber, Bool, and String since different consent SDKs store different types.
    private static func normalizedGDPRFlag(from rawValue: Any?) -> Int? {
        if let number = rawValue as? NSNumber {
            let value = number.intValue
            return (value == 0 || value == 1) ? value : nil
        }

        if let boolValue = rawValue as? Bool {
            return boolValue ? 1 : 0
        }

        if let stringValue = rawValue as? String, let value = Int(stringValue) {
            return (value == 0 || value == 1) ? value : nil
        }

        return nil
    }
}