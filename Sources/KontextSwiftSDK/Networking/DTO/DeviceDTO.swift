import Foundation

struct DeviceDTO: Encodable {
    let os: OSDTO
    let hardware: HardwareDTO
    let screen: ScreenDTO
    let power: PowerDTO
    let audio: AudioDTO
    let network: NetworkDTO

    init(from model: DeviceInfo) {
        self.os = OSDTO(from: model.os)
        self.hardware = HardwareDTO(from: model.hardware)
        self.screen = ScreenDTO(from: model.screen)
        self.power = PowerDTO(from: model.power)
        self.audio = AudioDTO(from: model.audio)
        self.network = NetworkDTO(from: model.network)
    }
}
