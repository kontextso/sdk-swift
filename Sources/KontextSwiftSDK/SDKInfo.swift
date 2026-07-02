/// Compile-time SDK identity (name + platform + version) sent in
/// `/init`, `/preload`, error reports, and iframe URLs.
///
/// Values are constants tied to the build, not configuration:
/// they don't depend on runtime state and aren't influenced by the
/// publisher. Wire-encoding goes through `SDKDTO` via `toDTO()`,
/// not via direct `Encodable` on this type.
///
/// Release process: bump `sdkVersion` together with the podspec's
/// `s.version` (and any release tag) — they're expected to agree.
struct SDKInfo: Sendable {
    let name: String
    let platform: String
    let version: String

    /// Current SDK version in Major.Minor.Patch format.
    /// Bump on every release; keep in sync with the podspec when one is added.
    static let sdkVersion = "4.0.2"

    /// SDK identifier sent in the `sdk` field of `/preload` and `/init`.
    static let sdkName = "sdk-swift"

    /// Platform identifier sent in the `sdk` field of `/preload` and `/init`.
    static let sdkPlatform = "ios"

    static let current = SDKInfo(
        name: sdkName,
        platform: sdkPlatform,
        version: sdkVersion
    )
}

// MARK: - Wire-format conversion

extension SDKInfo {
    /// Converts to the `SDKDTO` shipped in `/preload`, `/init`, and
    /// `/error` request bodies. Pure field-renaming passthrough.
    func toDTO() -> SDKDTO {
        SDKDTO(name: name, platform: platform, version: version)
    }
}
