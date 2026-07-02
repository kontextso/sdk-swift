import KontextKit

/// Adapts KontextKit's String-typed device providers into the typed
/// `DeviceDTO` wire shape, applying enum-with-fallback conversions
/// at the boundary (`hardware.type → HardwareType`,
/// `screen.orientation → ScreenOrientation`, etc.).
///
/// KontextKit lives as a vendored library in three SDKs (sdk-swift,
/// sdk-react-native iOS, sdk-flutter iOS) — the providers themselves
/// are identical across consumers; this collector is sdk-swift's
/// glue between that surface and the strict DTO encoder.
///
/// Uninhabited namespace (`enum`) — purely static API, never instantiated.
@MainActor
enum DeviceCollector {

    /// Returns a `DeviceDTO` with all device info (sync — excludes network).
    static func collect() -> DeviceDTO {
        let hw = HardwareInfoProvider.collect()
        let os = OSInfoProvider.collect()
        let screen = ScreenInfoProvider.collect()
        let power = BatteryInfoProvider.collect()
        let audio = AudioInfoProvider.collect()

        return DeviceDTO(
            hardware: HardwareDTO(
                brand: hw.brand,
                model: hw.model,
                type: HardwareType(rawValue: hw.type) ?? .other,
                bootTime: hw.bootTime
            ),
            os: OSDTO(
                name: os.name,
                version: os.version,
                locale: os.locale,
                timezone: os.timezone
            ),
            screen: ScreenDTO(
                width: screen.width,
                height: screen.height,
                dpr: screen.dpr,
                orientation: ScreenOrientation(rawValue: screen.orientation) ?? .portrait,
                darkMode: screen.darkMode,
                brightness: screen.brightness
            ),
            power: PowerDTO(
                lowPowerMode: power.lowPowerMode,
                batteryState: BatteryState(rawValue: power.batteryState) ?? .unknown,
                batteryLevel: power.batteryLevel
            ),
            audio: AudioDTO(
                volume: audio.volume,
                muted: audio.muted,
                outputPluggedIn: audio.outputPluggedIn,
                outputType: audio.outputType.compactMap { AudioOutputType(rawValue: $0) }
            )
        )
    }

    /// Returns a `DeviceDTO` including async network info.
    ///
    /// Constructs the DTO in one shot rather than mutating a partial
    /// instance, so every field on `DeviceDTO` can stay `let`. Sequential
    /// rather than parallel because `NetworkInfoProvider` caches the
    /// user-agent eval (the only slow leg) — the first call pays the
    /// WKWebView warmup, every subsequent call is near-instant.
    static func collectAsync() async -> DeviceDTO {
        let net = await NetworkInfoProvider.collect()
        // KontextKit 0.1.0 removed on-device network-type detection (an
        // `NWPathMonitor` read that could double-resume and crash the app);
        // `net.type` is now nil, so we forward no `network.type` — the ad
        // server doesn't use it for ad selection. `detail` went with it.
        let networkDTO = NetworkDTO(
            type: net.type.flatMap(NetworkType.init(rawValue:)),
            carrier: net.carrier,
            userAgent: net.userAgent
        )

        let base = collect()
        return DeviceDTO(
            hardware: base.hardware,
            os: base.os,
            screen: base.screen,
            power: base.power,
            audio: base.audio,
            network: networkDTO
        )
    }
}
