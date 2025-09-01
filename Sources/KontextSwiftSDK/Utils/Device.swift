import AVFAudio
import UIKit
import Darwin

/// Device information for the SDK
struct Device {
    /// Operating system (e.g., "ios", "android")
    let os: String
    /// System version (e.g., "16.5")
    let systemVersion: String
    /// Device model (e.g., "iPhone17,3")
    let model: String
    /// Device brand (e.g., "Apple")
    let brand: String
    /// Device type (e.g., "handset", "tablet", "desktop")
    let deviceType: DeviceType
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
    /// Device screen scale (e.g., 2.0 for Retina displays)
    let scale: CGFloat
    /// Device orientation: "portrait" or "landscape"
    let orientation: ScreenOrientation?
    /// Device dark mode status (true if dark mode is on, false if light mode is on)
    let isDarkMode: Bool
    /// Device boot time (seconds since 1970)
    let bootTime: Double
    /// Additional device information
    let additionalInfo: [String: String]
    /// True if an SD card is available, false otherwise (always false for iOS devices)
    let sdCardAvailable: Bool = false
    /// Battery level (0 to 100) or nil if not available
    let batteryLevel: Double?
    /// Battery state (charging, full, unplugged, unknown) or nil if not available
    let batteryState: BatteryState?
    /// Low power mode status (true if low power mode is on, false if off) or nil if not available
    let lowPowerMode: Bool?
    /// media volume 0-100
    let volume: Int?
    /// preferred over "soundOn"
    let muted: Bool?
    /// ANY output connected?
    let outputPluggedIn: Bool?
    /// array, wired/hdmi/bluetooth/...
    let outputType: [AudioOutputType]?

    init(
        os: String,
        systemVersion: String,
        model: String,
        brand: String,
        deviceType: DeviceType,
        soundOn: Bool = true,
        locale: String,
        timezone: String,
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        scale: CGFloat,
        orientation: ScreenOrientation?,
        isDarkMode: Bool,
        additionalInfo: [String: String] = [:],
        bootTime: Double,
        batteryLevel: Double?,
        batteryState: BatteryState?,
        lowPowerMode: Bool?,
        volume: Int?,
        muted: Bool?,
        outputPluggedIn: Bool?,
        outputType: [AudioOutputType]?

    ) {
        self.os = os
        self.systemVersion = systemVersion
        self.model = model
        self.brand = brand
        self.deviceType = deviceType
        self.soundOn = soundOn
        self.locale = locale
        self.timezone = timezone
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.scale = scale
        self.orientation = orientation
        self.isDarkMode = isDarkMode
        self.additionalInfo = additionalInfo
        self.bootTime = bootTime
        self.batteryLevel = batteryLevel
        self.batteryState = batteryState
        self.lowPowerMode = lowPowerMode
        self.volume = volume
        self.muted = muted
        self.outputPluggedIn = outputPluggedIn
        self.outputType = outputType
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

        let deviceType: DeviceType = switch UIDevice.current.userInterfaceIdiom {
        case .phone: .handset
        case .pad: .tablet
        default: .other
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

        let orientation: ScreenOrientation? = switch UIDevice.current.orientation {
        case .portrait, .portraitUpsideDown: .portrait
        case .landscapeLeft, .landscapeRight: .landscape
        default: nil
        }

        let locale = Locale.current.identifier
        let timezone = TimeZone.current.identifier
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let scale = UIScreen.main.scale
        let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        let uptime = ProcessInfo.processInfo.systemUptime
        let now = Date()
        let bootTime = now.addingTimeInterval(-uptime).timeIntervalSince1970

        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel: Double? = Double(UIDevice.current.batteryLevel) * 100
        let batteryState: BatteryState? = switch UIDevice.current.batteryState {
        case .charging: .charging
        case .full: .full
        case .unplugged: .unplugged
        case .unknown: .unknown
        }
        let lowPowerMode: Bool? = ProcessInfo.processInfo.isLowPowerModeEnabled

        let volume = Int(AVAudioSession.sharedInstance().outputVolume * 100)
        let muted = AVAudioSession.sharedInstance().outputVolume == 0 ? true : false
        let outputPluggedIn = AVAudioSession.sharedInstance().currentRoute.outputs.isEmpty == false
        let outputTypes: [AudioOutputType] = AVAudioSession.sharedInstance().currentRoute.outputs.map { output in
            return switch output.portType {
            case .headphones, .lineOut, .builtInSpeaker, .PCI, .fireWire, .displayPort, .AVB, .thunderbolt: .wired
            case .HDMI: .hdmi
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio, .airPlay: .bluetooth
            case .usbAudio: .usb
            default: .other
            }
        }

        return Device(
            os: os,
            systemVersion: systemVersion,
            model: deviceModel,
            brand: brand,
            deviceType: deviceType,
            soundOn: soundOn,
            locale: locale,
            timezone: timezone,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            scale: scale,
            orientation: orientation,
            isDarkMode: isDarkMode,
            additionalInfo: additionalInfo,
            bootTime: bootTime,
            batteryLevel: batteryLevel,
            batteryState: batteryState,
            lowPowerMode: lowPowerMode,
            volume: volume,
            muted: muted,
            outputPluggedIn: outputPluggedIn,
            outputType: outputTypes
        )
    }
}
