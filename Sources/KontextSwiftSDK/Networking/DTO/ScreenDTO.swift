/// Screen and display information.
///
/// `width` and `height` are reported in **physical pixels**
/// (CSS pixels × `dpr`) so the ad server receives
/// resolution-independent dimensions.
///
/// `brightness` is **0–100** — the SDK normalises iOS's native
/// `UIScreen.main.brightness` (0–1) by multiplying at the collector
/// boundary, matching the convention used by `audio.volume` and
/// `power.batteryLevel`.
struct ScreenDTO: Encodable, Sendable {
    let width: Int
    let height: Int
    let dpr: Double
    let orientation: ScreenOrientation
    let darkMode: Bool
    let brightness: Double
}
