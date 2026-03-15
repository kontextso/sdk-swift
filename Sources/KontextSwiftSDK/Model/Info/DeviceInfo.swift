/// Aggregated snapshot of all device subsystem properties
struct DeviceInfo {
    let os: OSInfo
    let hardware: HardwareInfo
    let screen: ScreenInfo
    let power: PowerInfo
    let audio: AudioInfo
    let network: NetworkInfo
}

extension DeviceInfo {
    /// Creates a DeviceInfo instance with current device information
    @MainActor
    static func current() async -> DeviceInfo {
        let os = OSInfo.current()
        let hardware = HardwareInfo.current()
        let screen = ScreenInfo.current()
        let power = PowerInfo.current()
        let audio = AudioInfo.current()
        let network = await NetworkInfo.current()

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
