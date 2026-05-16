/// Operating-system metadata. All four fields are always known on iOS.
///
/// `OSInfoProvider` populates these as:
/// - `name` is the lowercase platform identifier (`"ios"`), matching
///   the server's `osSchema` example and the SDK's own `sdk.platform`.
/// - `locale` is a BCP-47 tag (e.g. `"en-US"`), not POSIX (`"en_US"`).
/// - `timezone` is an IANA identifier.
struct OSDTO: Encodable, Sendable {
    let name: String
    let version: String
    let locale: String
    let timezone: String
}
