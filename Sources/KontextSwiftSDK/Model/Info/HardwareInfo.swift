import UIKit

/// Device form factor category
enum DeviceType: String, Encodable {
    case handset
    case tablet
    case other
}

/// Current device hardware properties
struct HardwareInfo {
    /// Device brand (e.g., "Apple")
    let brand: String
    /// Device model identifier (e.g., "iPhone17,3")
    let model: String
    /// Device type (handset, tablet, or other)
    let type: DeviceType
    /// True if an SD card is available (always false on iOS)
    let sdCardAvailable: Bool
}

extension HardwareInfo {
    /// Creates a HardwareInfo instance with current hardware information
    @MainActor
    static func current() -> HardwareInfo {
        HardwareInfo(
            brand: "Apple",
            model: deviceModelIdentifier(),
            type: switch UIDevice.current.userInterfaceIdiom {
            case .phone: .handset
            case .pad: .tablet
            default: .other
            },
            sdCardAvailable: false
        )
    }

    /// Returns the device model identifier string using utsname (e.g., "iPhone17,3")
    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
