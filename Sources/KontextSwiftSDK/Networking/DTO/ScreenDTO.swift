enum ScreenOrientation: String, Encodable {
    case portrait
    case landscape
}

struct ScreenDTO: Encodable {
    /// Width in pixels
    let width: Double
    /// Height in pixels
    let height: Double
    /// Device pixel ratio, DPR, e.g. 3.0
    let dpr: Double
    /// Orientation of the device, e.g. "portrait" or "landscape", can be nil
    let orientation: ScreenOrientation?
    /// Whether the device is in dark mode
    let darkMode: Bool
}
