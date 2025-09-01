
enum BatteryState: String, Encodable {
    case charging
    case full
    case unplugged
    case unknown
}

struct PowerDTO {
    /// Battery level (0 to 100) or nil if not available
    let batteryLevel: Double?
    let batteryState: BatteryState?
    let lowPowerMode: Bool?

    init(model: Device) {
        batteryLevel = model.batteryLevel
        batteryState = model.batteryState
        lowPowerMode = model.lowPowerMode
    }
}
