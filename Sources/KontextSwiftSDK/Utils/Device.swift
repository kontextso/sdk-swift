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
    /// Device locale identifier (e.g., "en_US")
    let locale: String
    /// Device timezone identifierIANA, e.g. "Europe/Prague"
    let timezone: String
    /// Device screen width size
    let screenWidth: CGFloat
    /// Device screen height size
    let screenHeight: CGFloat
    /// Device orientation: "portrait" or "landscape"
    let orientation: String?
    /// Device dark mode status (true if dark mode is on, false if light mode is on)
    let isDarkMode: Bool
    /// Device boot time (seconds since 1970)
    let bootTime: Double
    /// Additional device information
    let additionalInfo: [String: String]
    /// True if an SD card is available, false otherwise (always false for iOS devices)
    let sdCardAvailable: Bool = false

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
        locale: String,
        timezone: String,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        orientation: String?,
        isDarkMode: Bool,
        additionalInfo: [String: String] = [:],
        bootTime: Double
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
        self.locale = locale
        self.timezone = timezone
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.orientation = orientation
        self.isDarkMode = isDarkMode
        self.additionalInfo = additionalInfo
        self.bootTime = bootTime
        self.orientation = orientation
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
        let soundOn = AVAudioSession.sharedInstance().outputVolume != 0

        // Additional device info
        var additionalInfo: [String: String] = [:]
        additionalInfo["deviceModel"] = deviceModel
        additionalInfo["screenWidth"] = "\(UIScreen.main.bounds.width)"
        additionalInfo["screenHeight"] = "\(UIScreen.main.bounds.height)"
        additionalInfo["scale"] = "\(UIScreen.main.scale)"

        let orientation: String?
        switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown:
            orientation = "portrait"
        case .landscapeLeft, .landscapeRight:
            orientation = "landscape"
        default:
            orientation = nil
        }

        let locale = Locale.current.identifier
        let timezone = TimeZone.current.identifier
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        let bootTime = now.addingTimeInterval(-uptime).timeIntervalSince1970

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
            locale: locale,
            timezone: timezone,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            orientation: orientation,
            isDarkMode: isDarkMode,
            additionalInfo: additionalInfo,
            bootTime: bootTime
        )
    }
}
