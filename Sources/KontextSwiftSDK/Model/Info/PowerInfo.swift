import UIKit

/// Battery charge state reported by UIDevice
enum BatteryState: String, Encodable {
    case charging
    case full
    case unplugged
    case unknown
}

/// Current device battery and power mode status
struct PowerInfo {
    /// Battery level (0 to 100) or nil if not available
    let batteryLevel: Double?
    /// Battery state (charging, full, unplugged, unknown) or nil if not available
    let batteryState: BatteryState?
    /// Whether Low Power Mode is currently enabled
    let lowPowerMode: Bool
}

extension PowerInfo {
    /// Creates a PowerInfo instance with current power information
    @MainActor
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

        return PowerInfo(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
