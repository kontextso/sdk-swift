/// JSON body sent to `POST /init` for per-publisher configuration.
///
/// Narrower than `PreloadRequestDTO` — `/init` only needs publisher identity,
/// SDK build, app bundle, and SKAdNetwork IDs (no character, regulatory,
/// IFA, etc.).
///
/// Both `app` and `skan` are sent on every request — empty values
/// (e.g. `skan.items: []`, or `app` with `Bundle.main` defaults) are a
/// valid positive signal, distinct from "no `/init` observed yet".
struct InitRequestDTO: Encodable, Sendable {
    let publisherToken: String
    let userId: String
    /// Per-install identifier (UUID v7), persistent across launches and conversations.
    let installId: String
    let sdk: SDKDTO
    let app: AppMetadata
    let skan: SKANItems

    /// Minimal app metadata for `/init` — strictly narrower than `AppDTO`
    /// (which carries install/update/start times for `/preload` targeting).
    struct AppMetadata: Encodable, Sendable {
        let bundleId: String
        let version: String
    }

    /// SKAdNetwork IDs collected from `Info.plist`.
    ///
    /// Wrapper struct (rather than a bare `[String]`) because the server
    /// expects the JSON shape `{ "items": [...] }`, not a top-level array.
    /// Sent on every `/init`; an empty `items` array is a valid signal.
    struct SKANItems: Encodable, Sendable {
        let items: [String]
    }
}
