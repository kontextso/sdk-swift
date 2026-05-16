/// JSON body sent to `POST /error` for SDK diagnostics.
///
/// Mirrors the shape sent by sdk-js / sdk-react-native / sdk-flutter so
/// the server's ingestion path is identical across SDKs.
struct ErrorRequestDTO: Encodable, Sendable {
    let error: String
    let stack: String?
    let additionalData: AdditionalData

    /// Session-/bid-scoped attribution metadata. All fields optional so
    /// callers without full context (e.g. `/init` failures, where the
    /// session isn't established yet) can still emit a useful report.
    struct AdditionalData: Encodable, Sendable {
        let publisherToken: String?
        let conversationId: String?
        let userId: String?
        /// Per-install identifier (UUID v7).
        let installId: String?
        let bidId: String?
        let sdk: SDKDTO
    }
}
