import UIKit

enum BatteryState: String, Encodable {
    case charging
    case full
    case unplugged
    case unknown
}

struct PowerInfo {
    /// Battery level (0 to 100) or nil if not available
    let batteryLevel: Double?
    /// Battery state (charging, full, unplugged, unknown) or nil if not available
    let batteryState: BatteryState?
    /// Low power mode status (true if low power mode is on, false if off) or nil if not available
    let lowPowerMode: Bool?

    init(
        batteryLevel: Double?,
        batteryState: BatteryState?,
        lowPowerMode: Bool?
    ) {
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.lowPowerMode = lowPowerMode
    }
}

extension PowerInfo {
    @MainActor
    /// Creates a PowerInfo instance with current power information
    static func current() -> PowerInfo {
        // Enable battery monitoring first
        UIDevice.current.isBatteryMonitoringEnabled = true
        defer { UIDevice.current.isBatteryMonitoringEnabled = false }
        // Calculate properties after
        let rawLevel = UIDevice.current.batteryLevel
        let batteryLevel: Double? = rawLevel >= 0 ? Double(rawLevel) * 100 : nil
        let batteryState: BatteryState? = switch UIDevice.current.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        case .unknown: .unknown
        @unknown default: .unknown
        }
        let lowPowerMode: Bool? = ProcessInfo.processInfo.isLowPowerModeEnabled

        return PowerInfo(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerMode: lowPowerMode
        )
    }
}
