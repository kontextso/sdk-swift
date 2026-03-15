import AVFAudio

/// Audio output port category
enum AudioOutputType: String, Encodable {
    case wired
    case hdmi
    case bluetooth
    case usb
    case other
}

/// Current device audio session state
struct AudioInfo {
    /// Media volume 0–100
    let volume: Int
    /// True when volume is below audible threshold
    let muted: Bool
    /// True when any audio output is connected
    let outputPluggedIn: Bool
    /// List of connected output port types
    let outputType: [AudioOutputType]
}

extension AudioInfo {
    /// Creates an AudioInfo instance with current audio information
    static func current() -> AudioInfo {
        let session = AVAudioSession.sharedInstance()
        let volume = Int(session.outputVolume * 100)
        let muted = session.outputVolume < 0.01
        let outputs = session.currentRoute.outputs
        let outputTypes: [AudioOutputType] = outputs.map { output in
            switch output.portType {
            case .headphones, .lineOut, .builtInSpeaker, .PCI, .fireWire, .displayPort, .AVB, .thunderbolt: .wired
            case .HDMI: .hdmi
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio, .airPlay: .bluetooth
            case .usbAudio: .usb
            default: .other
            }
        }

        return AudioInfo(
            volume: volume,
            muted: muted,
            outputPluggedIn: outputs.isEmpty == false,
            outputType: outputTypes
        )
    }
}
