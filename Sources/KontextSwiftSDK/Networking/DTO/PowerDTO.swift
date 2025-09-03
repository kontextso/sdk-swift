struct PowerDTO: Encodable {
    /// Battery level (0 to 100) or nil if not available
    let batteryLevel: Double?
    let batteryState: BatteryState?
    let lowPowerMode: Bool?
}
