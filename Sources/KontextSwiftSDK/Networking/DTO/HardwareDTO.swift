/// Hardware characteristics of the end-user device.
///
/// `bootTime` is epoch ms at which the OS booted (`DeviceCollector`
/// is responsible for sourcing it). `sdCardAvailable` is intentionally
/// omitted — it's Android-only per the server schema.
struct HardwareDTO: Encodable, Sendable {
    let brand: String
    let model: String
    let type: HardwareType
    let bootTime: Int64?

    init(brand: String, model: String, type: HardwareType, bootTime: Int64? = nil) {
        self.brand = brand
        self.model = model
        self.type = type
        self.bootTime = bootTime
    }
}
