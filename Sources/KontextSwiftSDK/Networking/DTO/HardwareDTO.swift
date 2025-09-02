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
    /// If SD card is available, always false on iOS devices
    let sdCardAvailable: Bool?

    // Device boot time (seconds since 1970)
    // let bootTime: Double
    // Is not allowed to be sent on iOS due to privacy reasons

    init(from model: HardwareInfo) {
        brand = model.brand
        self.model = model.model
        type = model.type
        sdCardAvailable = model.sdCardAvailable
    }
}
