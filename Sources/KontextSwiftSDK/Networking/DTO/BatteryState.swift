/// Battery charging state. Mirrors the server's `power.batteryState` enum.
enum BatteryState: String, Encodable, Sendable {
    case charging
    case full
    case unplugged
    case unknown
}
