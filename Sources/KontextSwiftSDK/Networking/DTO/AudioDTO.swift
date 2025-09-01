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

    init(volume: Int? = nil,
         muted: Bool? = nil,
         outputPluggedIn: Bool? = nil,
         outputType: [AudioOutputType]? = nil) {
        self.volume = volume
        self.muted = muted
        self.outputPluggedIn = outputPluggedIn
        self.outputType = outputType
    }
}
