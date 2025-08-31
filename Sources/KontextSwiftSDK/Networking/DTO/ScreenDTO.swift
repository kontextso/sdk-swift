//
//  ScreenDTO.swift
//  KontextSwiftSDK
//

struct ScreenDTO: Encodable {
    let width: Double           // px
    let height: Double          // px
    let dpr: Double             // DPR, e.g. 3.0
    let orientation?: String
    let darkMode: Bool

    init(from device: Device) {
        width = device.screenWidth
        height = device.screenHeight
        dpr = device.scale
        orientation = device.orientation
        darkMode = device.isDarkMode
    }
}
