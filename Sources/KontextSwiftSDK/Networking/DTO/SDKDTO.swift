/// SDK build identity — name, platform, version. Shared across
/// `/preload`, `/init`, and `/error` request bodies; populated from
/// the compile-time constants in `SDKInfo`.
///
/// `name` and `platform` are typed as `String` (not enums) because
/// sdk-swift only ever emits `"sdk-swift"` and `"ios"` — modelling the
/// server's other 7 / 4 enum values would add noise without value.
/// The constants live in `SDKInfo`; tests pin the wire spelling.
struct SDKDTO: Encodable, Sendable {
    let name: String
    let platform: String
    let version: String
}
