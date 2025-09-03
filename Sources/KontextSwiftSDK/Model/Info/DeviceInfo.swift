import AVFAudio
import UIKit
import Darwin

/// Device information for the SDK
struct DeviceInfo {
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

extension DeviceInfo {
    /// Creates a DeviceInfo instance with current device information
    static func current(appInfo: AppInfo) async -> DeviceInfo {
        let os = await OSInfo.current()
        let hardware = await HardwareInfo.current()
        let screen = await ScreenInfo.current()
        let power = await PowerInfo.current()
        let audio = AudioInfo.current()
        let network = await NetworkInfo.current(
            appInfo: appInfo,
            osInfo: os,
            hardwareInfo: hardware
        )

        return DeviceInfo(
            os: os,
            hardware: hardware,
            screen: screen,
            power: power,
            audio: audio,
            network: network
        )
    }
}
