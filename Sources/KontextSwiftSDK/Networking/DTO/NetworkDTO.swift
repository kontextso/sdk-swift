/// Network connectivity information. Server treats every field as
/// optional. On-device `type` detection was removed in KontextKit 0.1.0
/// (it relied on an `NWPathMonitor` read that could double-resume its
/// continuation and crash the app), and the ad server does not use `type`
/// for ad selection — so `type` is optional and currently always nil.
/// `carrier` is likewise always nil on iOS 16+ (CTCarrier removed),
/// `userAgent` requires a `WKWebView` eval that can fail, and `detail`
/// is no longer collected.
struct NetworkDTO: Encodable, Sendable {
    let type: NetworkType?
    let carrier: String?
    let detail: String?
    let userAgent: String?

    init(
        type: NetworkType? = nil,
        carrier: String? = nil,
        detail: String? = nil,
        userAgent: String? = nil
    ) {
        self.type = type
        self.carrier = carrier
        self.detail = detail
        self.userAgent = userAgent
    }
}
