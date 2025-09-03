import AVFAudio

enum AudioOutputType: String, Codable {
    case wired
    case hdmi
    case bluetooth
    case usb
    case other
}

struct AudioInfo {
    /// media volume 0-100
    let volume: Int?
    /// preferred over "soundOn"
    let muted: Bool?
    /// ANY output connected?
    let outputPluggedIn: Bool?
    /// array, wired/hdmi/bluetooth/...
    let outputType: [AudioOutputType]?

    init(
        volume: Int?,
        muted: Bool?,
        outputPluggedIn: Bool?,
        outputType: [AudioOutputType]?
    ) {
        self.volume = volume
        self.muted = muted
        self.outputPluggedIn = outputPluggedIn
        self.outputType = outputType
    }
}

extension AudioInfo {
    /// Creates an AudioInfo instance with current audio information
    static func current() -> AudioInfo {
        let volume = Int(AVAudioSession.sharedInstance().outputVolume * 100)
        let muted = AVAudioSession.sharedInstance().outputVolume == 0 ? true : false
        let outputPluggedIn = AVAudioSession.sharedInstance().currentRoute.outputs.isEmpty == false
        let outputTypes: [AudioOutputType] = AVAudioSession.sharedInstance().currentRoute.outputs.map { output in
            return switch output.portType {
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
            outputPluggedIn: outputPluggedIn,
            outputType: outputTypes
        )
    }
}
