import AVFAudio
import UIKit
import Darwin

/// Device information for the SDK
struct Device: Codable, Sendable {
    /// Operating system (e.g., "ios", "android")
    let os: String
    /// System version (e.g., "16.5")
    let systemVersion: String
    /// Device model (e.g., "iPhone17,3")
    let model: String
    /// Device brand (e.g., "Apple")
    let brand: String
    /// Device type (e.g., "handset", "tablet", "desktop")
    let deviceType: String
    /// App bundle identifier (e.g., "com.example.app")
    let appBundleId: String
    /// App version (e.g., "20.9.1")
    let appVersion: String
    /// App store URL (optional)
    let appStoreUrl: String?
    /// Device sound status (true if sound is on, false if muted)
    let soundOn: Bool
    /// Additional device information
    let additionalInfo: [String: String]
    
    init(
        os: String,
        systemVersion: String,
        model: String,
        brand: String,
        deviceType: String,
        appBundleId: String,
        appVersion: String,
        appStoreUrl: String? = nil,
        soundOn: Bool = true,
        additionalInfo: [String: String] = [:]
    ) {
        self.os = os
        self.systemVersion = systemVersion
        self.model = model
        self.brand = brand
        self.deviceType = deviceType
        self.appBundleId = appBundleId
        self.appVersion = appVersion
        self.appStoreUrl = appStoreUrl
        self.soundOn = soundOn
        self.additionalInfo = additionalInfo
    }
}

// MARK: - Device Detection

extension Device {
    /// Creates a Device instance with current device information
    @MainActor
    static func current() -> Device {
        let os = "ios"
        let systemVersion = UIDevice.current.systemVersion
        let brand = "Apple"
        
        // Determine device type
        let deviceType: String
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            deviceType = "handset"
        case .pad:
            deviceType = "tablet"
        default:
            deviceType = "other"
        }
        
        // Get app information
        let appBundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        
        // Get device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceModel = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        // Detect sound status
        let soundOn = !isVolumeMuted()
        
        // Additional device info
        var additionalInfo: [String: String] = [:]
        additionalInfo["deviceModel"] = deviceModel
        additionalInfo["screenWidth"] = "\(UIScreen.main.bounds.width)"
        additionalInfo["screenHeight"] = "\(UIScreen.main.bounds.height)"
        additionalInfo["scale"] = "\(UIScreen.main.scale)"
        
        return Device(
            os: os,
            systemVersion: systemVersion,
            model: deviceModel,
            brand: brand,
            deviceType: deviceType,
            appBundleId: appBundleId,
            appVersion: appVersion,
            appStoreUrl: nil,
            soundOn: soundOn,
            additionalInfo: additionalInfo
        )
    }
}

func isVolumeMuted() -> Bool {
    let volume = AVAudioSession.sharedInstance().outputVolume
    return volume == 0
}
