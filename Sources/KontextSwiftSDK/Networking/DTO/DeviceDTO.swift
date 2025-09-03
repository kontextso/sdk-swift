struct DeviceDTO: Encodable {
    let os: OSDTO
    let hardware: HardwareDTO
    let screen: ScreenDTO
    let power: PowerDTO
    let audio: AudioDTO
    let network: NetworkDTO    
}
