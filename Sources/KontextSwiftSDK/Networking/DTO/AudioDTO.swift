//
//  AudioDTO.swift
//  KontextSwiftSDK
//

import Foundation

struct AudioDTO: Encodable {
    /// media volume 0-100
    let volume: Int?
    /// preferred over "soundOn"
    let muted: Bool?
    /// ANY output connected?
    let outputPluggedIn: Bool?
    /// array, wired/hdmi/bluetooth/...
    let outputType: [AudioOutputType]?

    init(from model: AudioInfo) {
        volume = model.volume
        muted = model.muted
        outputPluggedIn = model.outputPluggedIn
        outputType = model.outputType
    }
}
