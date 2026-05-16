/// JSON body sent to `POST /debug` for opt-in remote debug forwarding.
///
/// Parallel to `ErrorRequestDTO` — same `additionalData` shape so the
/// server can ingest both with shared attribution code. Distinct
/// payload (`name` + `data`) because debug events are arbitrary
/// structured logs, not error reports.
///
/// `data` is a pre-stringified JSON / `String(describing:)` blob
/// rather than a typed payload because `Session.debug(...)` accepts
/// `Any?` from across the SDK (dictionaries, primitives, error values)
/// and `Encodable` can't represent that without erasing every call
/// site. The capture path serialises once at the boundary and treats
/// the wire as opaque text.
struct DebugRequestDTO: Encodable, Sendable {
    let name: String
    let data: String?
    let additionalData: AdditionalData

    /// Session-scoped attribution metadata. `sessionId` is included
    /// (unlike `ErrorRequestDTO.AdditionalData`) because debug forwarding
    /// is a diagnostic on a live session — the field is meaningful and
    /// helps server-side filtering. `bidId` is omitted because debug
    /// events fire across the whole session, not bid-by-bid.
    struct AdditionalData: Encodable, Sendable {
        let publisherToken: String?
        let conversationId: String?
        let userId: String?
        /// Per-install identifier (UUID v7).
        let installId: String?
        let sessionId: String?
        let sdk: SDKDTO
    }
}
