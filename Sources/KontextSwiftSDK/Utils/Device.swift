import AVFAudio
import UIKit
import Darwin

/// Device information for the SDK
struct Device {
    let os: OSInfo
    let hardware: HardwareInfo
    let screen: ScreenInfo
    let power: PowerInfo
    let audio: AudioInfo
    let network: NetworkInfo

    init(
        os: OSInfo,
        hardware: HardwareInfo,
        screen: ScreenInfo,
        power: PowerInfo,
        audio: AudioInfo,
        network: NetworkInfo
    ) {
        self.os = os
        self.hardware = hardware
        self.screen = screen
        self.power = power
        self.audio = audio
        self.network = network
    }
}

// MARK: - Device Detection

extension Device {
    /// Creates a Device instance with current device information
    static func current(appInfo: AppInfo) async -> Device {
        let os = await OSInfo.current()
        let hardware = HardwareInfo.current()
        let screen = ScreenInfo.current()
        let power = PowerInfo.current()
        let audio = AudioInfo.current()
        let network = await NetworkInfo.current(
            appInfo: appInfo,
            osInfo: os,
            hardwareInfo: hardware
        )

        return Device(
            os: os,
            hardware: hardware,
            screen: screen,
            power: power,
            audio: audio,
            network: network
        )
    }
}
