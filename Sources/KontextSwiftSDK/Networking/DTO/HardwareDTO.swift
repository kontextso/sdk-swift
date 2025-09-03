struct HardwareDTO: Encodable {
    /// "Apple"
    let brand: String?
    /// "iPhone13,3"
    let model: String?
    /// handset/tablet/desktop/...
    let type: DeviceType
    /// If SD card is available, always false on iOS devices
    let sdCardAvailable: Bool?
}
