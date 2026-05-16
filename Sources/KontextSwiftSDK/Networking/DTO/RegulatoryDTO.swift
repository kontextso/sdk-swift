/// Privacy / regulatory signals merged into the `/preload` body when
/// at least one field is set.
///
/// Mutable (`var`) on purpose: `Preload.buildPreloadDTO` constructs an
/// empty `RegulatoryDTO` then overlays live TCF data on top of the
/// publisher's static config, requiring post-construction mutation.
struct RegulatoryDTO: Encodable, Sendable {
    var gdpr: Int?
    var gdprConsent: String?
    var coppa: Int?
    var gpp: String?
    var gppSid: [Int]?
    var usPrivacy: String?
}
