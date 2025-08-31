//
//  HardwareDTO.swift
//  KontextSwiftSDK
//

import Foundation

struct HardwareDTO: Encodable {
    let brand: String?     // "Apple"
    let model: String?     // "iPhone13,3"
    let type: String   // handset/tablet/desktop/...
    let bootTime: Double  // OS boot time  or time since boot
    let sdCardAvailable: Bool?

    init(from model: Device) {
        brand = model.brand
        self.model = model.model
        type = model.deviceType
        bootTime = model.bootTime
        sdCardAvailable = model.sdCardAvailable
    }
}
