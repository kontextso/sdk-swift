//
//  HardwareInfo.swift
//  KontextSwiftSDK
//

import UIKit

enum DeviceType: String, Encodable {
    case handset
    case tablet
    case other
}

final class HardwareInfo {
    /// Device brand (e.g., "Apple")
    let brand: String
    /// Device model (e.g., "iPhone17,3")
    let model: String
    /// Device type (e.g., "handset", "tablet", "desktop")
    let type: DeviceType
    /// True if an SD card is available, false otherwise (always false for iOS devices)
    let sdCardAvailable: Bool

    // Device boot time (seconds since 1970)
    // let bootTime: Double
    // Is not allowed to be sent on iOS due to privacy reasons

    init(
        brand: String,
        model: String,
        type: DeviceType,
        // bootTime: Double,
        sdCardAvailable: Bool
    ) {
        self.brand = brand
        self.model = model
        self.type = type
        // self.bootTime = bootTime
        self.sdCardAvailable = sdCardAvailable
    }

    static func current() -> HardwareInfo {
        // Always Apple on iOS
        let brand = "Apple"
        // Determine device type
        let deviceType: DeviceType = switch UIDevice.current.userInterfaceIdiom {
        case .phone: .handset
        case .pad: .tablet
        default: .other
        }
        // Get device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        // SD card is never available on iOS devices
        let sdCardAvailable = false

        return HardwareInfo(
            brand: brand,
            model: deviceModel,
            type: deviceType,
            sdCardAvailable: sdCardAvailable
        )
    }
}

