/// Callback for SDK-internal debug/diagnostic events.
///
/// Receives a namespaced event name (e.g. `Session: message-added`,
/// `Ad: mount`, `Preload: error-preloading-ads`) and an optional
/// structured payload. Used by `Session`, `Ad`, `Preload`, and `Init`
/// to surface internal state transitions and errors to publishers who
/// opt in via `SessionOptions.onDebugEvent`.
///
/// Distinct from `AdEventHandler`, which delivers the publisher-facing
/// ad lifecycle events.
///
/// The payload is `Any?` rather than a typed value because debug
/// payloads are heterogeneous `[String: Any]` dictionaries
/// (including non-Sendable values like raw response objects). The
/// closure is `@Sendable` so it can be stored on the actor-isolated
/// `Session`; the `Any?` parameter is a conscious trade-off between
/// type safety and the diagnostic flexibility this callback needs.
public typealias DebugEventHandler = @Sendable (String, Any?) -> Void
