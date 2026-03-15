struct HardwareDTO: Encodable {
    let brand: String?
    let model: String?
    let type: DeviceType
    let sdCardAvailable: Bool
}
