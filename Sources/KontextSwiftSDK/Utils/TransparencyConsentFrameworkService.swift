import Foundation

struct TransparencyConsentFrameworkData: Sendable {
    let gdpr: Int?
    let gdprConsent: String?

    var isEmpty: Bool {
        gdpr == nil && gdprConsent == nil
    }
}

enum TransparencyConsentFrameworkService {
    static func getTCFData(userDefaults: UserDefaults = .standard) -> TransparencyConsentFrameworkData {
        let tcString = userDefaults.string(forKey: "IABTCF_TCString")
        let gdprApplies = userDefaults.object(forKey: "IABTCF_gdprApplies")

        let gdpr = normalizedGDPRFlag(from: gdprApplies)
        let gdprConsent = (tcString?.isEmpty == false) ? tcString : nil

        return TransparencyConsentFrameworkData(gdpr: gdpr, gdprConsent: gdprConsent)
    }

    static func mergedRegulatory(
        from regulatory: Regulatory?,
        userDefaults: UserDefaults = .standard
    ) -> Regulatory? {
        let tcfData = getTCFData(userDefaults: userDefaults)
        guard !tcfData.isEmpty else { return regulatory }

        if let regulatory {
            return Regulatory(
                gdpr: tcfData.gdpr ?? regulatory.gdpr,
                gdprConsent: tcfData.gdprConsent ?? regulatory.gdprConsent,
                coppa: regulatory.coppa,
                usPrivacy: regulatory.usPrivacy,
                gpp: regulatory.gpp,
                gppSid: regulatory.gppSid
            )
        }

        return Regulatory(gdpr: tcfData.gdpr, gdprConsent: tcfData.gdprConsent)
    }

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
