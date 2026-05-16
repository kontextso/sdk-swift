/// Device-level metadata sent in the `/preload` request body.
///
/// Write-only: encoded by `JSONEncoder`, never deserialized. Field
/// names, types, and enum values mirror the server's `deviceSchema`
/// (`apps/ad-server/app/preload/utils.ts`).
///
/// The server marks `audio` / `power` / `screen.orientation` /
/// `hardware.brand` / `hardware.model` as optional, but iOS always
/// provides these values — keeping them required in Swift documents
/// the platform contract without changing the wire output (nil
/// optionals would be omitted by `JSONEncoder` anyway).
struct DeviceDTO: Encodable, Sendable {
    let hardware: HardwareDTO
    let os: OSDTO
    let screen: ScreenDTO
    let power: PowerDTO
    let audio: AudioDTO
    let network: NetworkDTO?

    init(
        hardware: HardwareDTO,
        os: OSDTO,
        screen: ScreenDTO,
        power: PowerDTO,
        audio: AudioDTO,
        network: NetworkDTO? = nil
    ) {
        self.hardware = hardware
        self.os = os
        self.screen = screen
        self.power = power
        self.audio = audio
        self.network = network
    }
}
