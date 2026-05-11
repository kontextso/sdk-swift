import Foundation

/// JSON response from the `/preload` endpoint.
///
/// One DTO, three response shapes, distinguished by field presence:
/// * **Success** — `sessionId` set, `errCode == nil`, `bids` populated.
/// * **Skip** — `skip == true`, `skipCode` set (one of the server's
///   `SkipCode` enum values), no `bids`.
/// * **Error** — `errCode` set; `permanent == true` means the server has
///   permanently disabled the session and the SDK should stop preloading.
///
/// `Preload.handleResponse` performs this discrimination at the consumer
/// side (success path → `recordBids`, skip path → `skipFailure`,
/// error path → `errorFailure`). Note: the success path *also* requires
/// the HTTP status code to be 2xx — that signal lives on the
/// `URLResponse`, not in this DTO. The DTO itself stays a tolerant
/// container that accepts any of the three shapes.
struct PreloadResponseDTO: Sendable, Decodable {
    let bids: [BidDTO]?
    let sessionId: UUID?
    let skipCode: String?
    let skip: Bool?
    let errCode: String?
    let permanent: Bool?

    /// Empty DTO used by `Preload.handleResponse` when the HTTP status is
    /// non-2xx — we don't parse the body in that path, but `errorFailure`
    /// still expects a DTO to read `errCode`/`permanent` off (both nil).
    static let empty = PreloadResponseDTO(
        bids: nil,
        sessionId: nil,
        skipCode: nil,
        skip: nil,
        errCode: nil,
        permanent: nil
    )
}
