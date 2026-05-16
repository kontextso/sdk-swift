/// Privacy / regulatory consent signals passed to the ad server.
///
/// Conformances are deliberately minimal:
/// - `Sendable` — required: `Session.addMessage` is `async`, so options cross
///   actor boundaries.
/// - `Equatable` — convenience for publishers doing change-detection
///   (e.g. `if newRegulatory != oldRegulatory { update() }`); auto-synthesized.
///
/// Not conformed to `Hashable` (no set/dict-key usage) or `Encodable`
/// (encoding goes through `RegulatoryDTO`, not this type directly).
public struct Regulatory: Sendable, Equatable {
    /// GDPR applies flag: 1 = yes, 0 = no, omitted = unknown.
    public let gdpr: Int?
    /// IAB TCF v2 consent string.
    public let gdprConsent: String?
    /// COPPA flag: 1 = child-directed, 0 = not, omitted = unknown.
    public let coppa: Int?
    /// IAB Global Privacy Platform string.
    public let gpp: String?
    /// GPP section IDs that apply to this transaction.
    public let gppSid: [Int]?
    /// IAB US Privacy string (CCPA / LSPA).
    public let usPrivacy: String?

    public init(
        gdpr: Int? = nil,
        gdprConsent: String? = nil,
        coppa: Int? = nil,
        gpp: String? = nil,
        gppSid: [Int]? = nil,
        usPrivacy: String? = nil
    ) {
        self.gdpr = gdpr
        self.gdprConsent = gdprConsent
        self.coppa = coppa
        self.gpp = gpp
        self.gppSid = gppSid
        self.usPrivacy = usPrivacy
    }
}

// MARK: - Wire-format conversion

extension Regulatory {
    /// Converts to the `/preload`-bound `RegulatoryDTO`. Pure passthrough —
    /// `Regulatory` and `RegulatoryDTO` have identical field names and
    /// types; the two types exist only to separate domain from wire.
    func toDTO() -> RegulatoryDTO {
        RegulatoryDTO(
            gdpr: gdpr,
            gdprConsent: gdprConsent,
            coppa: coppa,
            gpp: gpp,
            gppSid: gppSid,
            usPrivacy: usPrivacy
        )
    }
}
