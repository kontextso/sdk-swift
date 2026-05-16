/// High-level network connection type. Mirrors the server's
/// `network.type` enum.
enum NetworkType: String, Encodable, Sendable {
    case wifi
    case cellular
    case ethernet
    case other
}
