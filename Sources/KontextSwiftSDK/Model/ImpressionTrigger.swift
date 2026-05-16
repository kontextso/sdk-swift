/// Determines when an ad impression event fires for a given bid.
///
/// Decoded from `BidDTO.impressionTrigger` on the wire and consumed by
/// `Ad` to decide when to start the SKAdNetwork tracking window. Internal
/// to the SDK — not part of the publisher-facing API.
///
/// Mirrors sdk-js's `BidImpressionTrigger` (Swift convention prefers the
/// shorter name; "Bid" qualification is implicit from the field site).
enum ImpressionTrigger: String, Sendable, Hashable, Decodable {
    /// Impression fires immediately when the ad renders.
    case immediate
    /// Impression fires when a component (e.g. modal) opens.
    case component
}
