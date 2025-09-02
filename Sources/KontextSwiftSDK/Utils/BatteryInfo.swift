//
//  BatteryInfo.swift
//  KontextSwiftSDK
//

import UIKit

enum BatteryState: String, Encodable {
    case charging
    case full
    case unplugged
    case unknown
}

final class PowerInfo {
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

    static func current() -> PowerInfo {
        // Enable battery monitoring first
        UIDevice.current.isBatteryMonitoringEnabled = true
        // Calculate properties after
        let batteryLevel: Double? = Double(UIDevice.current.batteryLevel) * 100
        let batteryState: BatteryState? = switch UIDevice.current.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        case .unknown: .unknown
        }
        let lowPowerMode: Bool? = ProcessInfo.processInfo.isLowPowerModeEnabled

        return PowerInfo(
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerMode: lowPowerMode
        )
    }
}

