//
//  HardwareDTO.swift
//  KontextSwiftSDK
//

import Foundation

struct HardwareDTO: Encodable {
    /// "Apple"
    let brand: String?
    /// "iPhone13,3"
    let model: String?
    /// handset/tablet/desktop/...
    let type: DeviceType
    /// OS boot time  or time since boot
    let bootTime: Double
    /// If SD card is available, always false on iOS devices
    let sdCardAvailable: Bool?

    init(from model: HardwareInfo) {
        brand = model.brand
        self.model = model.model
        type = model.type
        sdCardAvailable = model.sdCardAvailable
    }
}
