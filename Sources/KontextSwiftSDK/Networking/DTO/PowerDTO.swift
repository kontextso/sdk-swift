/// Power / battery state.
///
/// Server treats every field as optional, but KontextKit's
/// `BatteryInfoProvider` always emits `lowPowerMode` and `batteryState`
/// — `batteryState` falls back to `.unknown` when the underlying
/// `UIDevice.batteryState` is indeterminate, never to nothing. Only
/// `batteryLevel` is honestly nullable: the simulator and edge configs
/// (`UIDevice.batteryLevel == -1`) legitimately have no battery to
/// report.
///
/// `batteryLevel` is a percentage (0–100), matching the server's
/// `batteryLevel` describe and `BatteryInfoProvider`'s emit.
struct PowerDTO: Encodable, Sendable {
    let lowPowerMode: Bool
    let batteryState: BatteryState
    let batteryLevel: Double?

    init(lowPowerMode: Bool, batteryState: BatteryState, batteryLevel: Double? = nil) {
        self.lowPowerMode = lowPowerMode
        self.batteryState = batteryState
        self.batteryLevel = batteryLevel
    }
}
