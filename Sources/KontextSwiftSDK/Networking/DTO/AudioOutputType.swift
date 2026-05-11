/// Audio output type. Mirrors the server's `audio.outputType` enum
/// — items not in the enum are dropped at the `DeviceCollector` boundary.
enum AudioOutputType: String, Encodable, Sendable {
    case wired
    case hdmi
    case bluetooth
    case usb
    case other
}
