//
//  AudioDTO.swift
//  KontextSwiftSDK
//

import Foundation

enum AudioOutputType: String, Codable {
    case wired
    case hdmi
    case bluetooth
    case usb
    case other
}

struct Audio: Codable {
    /// media volume 0-100
    let volume: Int?
    /// preferred over "soundOn"
    let muted: Bool?
    /// ANY output connected?
    let outputPluggedIn: Bool?
    /// array, wired/hdmi/bluetooth/...
    let outputType: [AudioOutputType]?

    init(model: Device) {
        volume = model.volume
        muted = model.muted
        outputPluggedIn = model.outputPluggedIn
        outputType = model.outputType
    }
}
