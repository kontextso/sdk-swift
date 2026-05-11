/// JSON response from the `/init` endpoint.
///
/// Returned at session creation time. The server uses this to override
/// client-side defaults (e.g. preload timeout), permanently disable
/// the session if the publisher is misconfigured, and toggle the two
/// server-leg telemetry paths (`/error`, `/debug`) per user.
///
/// `enabled` / `reportErrors` / `reportDebug` are non-optional with
/// stable defaults — only an explicit `false` (or, for `reportDebug`,
/// an explicit `true`) flips them. This collapses the third "missing"
/// state out of every call site.
struct InitResponseDTO: Sendable, Decodable {
    /// Custom preload timeout in milliseconds. If present, overrides the
    /// SDK default.
    let preloadTimeout: Int?
    /// If `false`, the SDK should treat the session as permanently disabled
    /// and stop sending preload requests. Defaults to `true` when missing.
    let enabled: Bool
    /// Server-controlled kill switch for `/error` POSTs. `true` (default)
    /// means errors are forwarded to the server; `false` suppresses the
    /// POST. Local error logging (`os_log` / `print`) always runs
    /// regardless — this flag only gates the network leg.
    let reportErrors: Bool
    /// Server-controlled opt-in for `/debug` forwarding. `false` (default)
    /// means debug events stay local (publisher's `onDebugEvent` only).
    /// `true` additionally POSTs each debug event to `/debug` for
    /// per-user diagnostics. Off by default for privacy.
    let reportDebug: Bool

    enum CodingKeys: String, CodingKey {
        case preloadTimeout
        case enabled
        case reportErrors
        case reportDebug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.preloadTimeout = try c.decodeIfPresent(Int.self, forKey: .preloadTimeout)
        // Tolerant decode: missing key, JSON null, or wrong type all
        // collapse to the documented default. Each toggle requires an
        // explicit boolean from the server to flip.
        self.enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? true
        self.reportErrors = (try? c.decodeIfPresent(Bool.self, forKey: .reportErrors)) ?? true
        self.reportDebug = (try? c.decodeIfPresent(Bool.self, forKey: .reportDebug)) ?? false
    }
}
