/// DTO for app metadata in the `/preload` request body.
///
/// Used only by `/preload`; `/init` carries a narrower shape via
/// `InitRequestDTO.AppMetadata` (no install/update/start timestamps).
///
/// Field names and types match the server's appSchema (epoch ms).
/// `lastUpdateTime` is always nil on iOS — there's no public API for
/// "last app update time"; the field exists for cross-platform parity
/// (sdk-kotlin populates it from `PackageInfo.lastUpdateTime`).
struct AppDTO: Encodable, Sendable {
    let bundleId: String
    let version: String
    let firstInstallTime: Int64?
    let lastUpdateTime: Int64?
    let startTime: Int64?

    init(
        bundleId: String,
        version: String,
        firstInstallTime: Int64? = nil,
        lastUpdateTime: Int64? = nil,
        startTime: Int64? = nil
    ) {
        self.bundleId = bundleId
        self.version = version
        self.firstInstallTime = firstInstallTime
        self.lastUpdateTime = lastUpdateTime
        self.startTime = startTime
    }
}
