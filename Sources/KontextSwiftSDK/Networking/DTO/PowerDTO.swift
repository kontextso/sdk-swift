//
//  PowerDTO.swift
//  KontextSwiftSDK
//

enum BatteryState: String, Encodable {
    case charging
    case full
    case unplugged
    case unknown
}


struct PowerDTO {
  let batteryLevel: Double       // 0-100
  let batteryState: BatteryState?
  let lowPowerMode: Bool
}

