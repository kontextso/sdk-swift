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
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        defer { device.isBatteryMonitoringEnabled = false }

        let batteryState: BatteryState? = switch device.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        case .unknown: .unknown
        @unknown default: .unknown
        }

        return PowerInfo(
            batteryLevel: batteryLevel(from: device.batteryLevel),
            batteryState: batteryState,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    /// Converts raw UIDevice battery level to a 0–100 scale.
    /// UIDevice reports -1.0 when battery monitoring is unavailable.
    static func batteryLevel(from rawLevel: Float) -> Double? {
        rawLevel >= 0 ? Double(rawLevel) * 100 : nil
    }
}
