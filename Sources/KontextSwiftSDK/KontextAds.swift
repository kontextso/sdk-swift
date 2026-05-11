/// Public factory for creating Kontext ad sessions.
///
/// Usage:
/// ```swift
/// let session = KontextAds.createSession(SessionOptions(
///     publisherToken: "xxx",
///     userId: "user-1",
///     conversationId: "conv-1",
///     onEvent: { event in print(event) }
/// ))
/// ```
///
/// Declared as a case-less `enum` (rather than `struct` or `final class`) so
/// the type cannot be instantiated — it's a pure namespace. The empty enum
/// has zero possible values, so the compiler enforces "no instances" without
/// needing a defensive `private init`. Standard Swift idiom for type-level
/// namespaces (see also `Constants`).
public enum KontextAds {

    /// Creates a new ad session with the given options.
    @MainActor
    public static func createSession(_ options: SessionOptions) -> Session {
        let config = resolveConfig(options)
        return Session(config: config)
    }
}
