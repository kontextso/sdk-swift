/// Network connectivity information. Server treats every field as
/// optional, but KontextKit's `NetworkInfoProvider` always classifies
/// `type` (falling back to `.other` when the connection is unknown,
/// or after a 100ms `NWPathMonitor` timeout). The other three are
/// honestly optional: iOS 16+ never has a `carrier` (CTCarrier removed),
/// `userAgent` requires a `WKWebView` eval that can fail, and `detail`
/// is only present on cellular.
struct NetworkDTO: Encodable, Sendable {
    let type: NetworkType
    let carrier: String?
    let detail: String?
    let userAgent: String?

    init(
        type: NetworkType,
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
