import KontextKit

/// Builds the `AppDTO` snapshot embedded in `PreloadRequestDTO.app`.
/// Pure passthrough — every field comes from KontextKit's
/// `AppInfoProvider` so the cross-platform definitions can't drift
/// between sdk-swift and sdk-kotlin. Mirrors Android
/// `network/collectors/AppCollector.kt`.
struct AppCollector {

    /// Returns an `AppDTO` matching the server's appSchema.
    static func collect() -> AppDTO {
        let info = AppInfoProvider.collect()
        return AppDTO(
            bundleId: info.bundleId,
            version: info.version,
            firstInstallTime: info.firstInstallTime,
            lastUpdateTime: info.lastUpdateTime,
            startTime: AppInfoProvider.processStartMs
        )
    }
}
