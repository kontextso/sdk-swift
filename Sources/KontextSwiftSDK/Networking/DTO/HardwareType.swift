/// Device form-factor classification.
/// Mirrors the server's `hardware.type` enum.
enum HardwareType: String, Encodable, Sendable {
    case handset
    case tablet
    case desktop
    case tv
    case other
}
