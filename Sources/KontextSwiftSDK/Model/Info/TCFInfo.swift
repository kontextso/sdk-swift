import Foundation

struct TCFInfo {
    let gdpr: Int?
    let gdprConsent: String?

    var isEmpty: Bool {
        gdpr == nil && gdprConsent == nil
    }

    static func current(userDefaults: UserDefaults = .standard) -> TCFInfo {
        let tcString = userDefaults.string(forKey: "IABTCF_TCString")
        let gdprApplies = userDefaults.object(forKey: "IABTCF_gdprApplies")

        return TCFInfo(
            gdpr: normalizedGDPRFlag(from: gdprApplies),
            gdprConsent: (tcString?.isEmpty == false) ? tcString : nil
        )
    }

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