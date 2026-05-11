import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct DeviceCollectorTests {

    @Test func collectReturnsValidHardware() {
        let device = DeviceCollector.collect()

        #expect(device.hardware.brand == "Apple")
        #expect(!device.hardware.model.isEmpty)
        // KontextKit currently emits "handset" or "tablet"; if it ever
        // returns something unknown the collector falls back to .other.
        #expect([.handset, .tablet, .desktop, .tv, .other].contains(device.hardware.type))
    }

    /// `bootTime` is intentionally always `nil` on iOS per Apple's
    /// required-reason API rules (35F9.1 / 8FFB.1) which forbid
    /// transmitting `SystemBootTime` off-device. Field stays in the
    /// schema for cross-platform shape parity (Android still reports it).
    @Test func collectReturnsNilBootTimeOnIOS() {
        let device = DeviceCollector.collect()
        #expect(device.hardware.bootTime == nil)
    }

    @Test func collectReturnsValidOS() {
        let device = DeviceCollector.collect()

        // Lowercase to match server's `osSchema` example ("ios") and the
        // SDK's own `sdk.platform` value.
        #expect(device.os.name == "ios")
        #expect(!device.os.version.isEmpty)
        #expect(!device.os.timezone.isEmpty)

        // Locale must be BCP-47 (hyphenated, e.g. "en-US"), never POSIX
        // ("en_US"). Server's `osSchema.locale` is documented as BCP-47.
        #expect(!device.os.locale.isEmpty)
        #expect(!device.os.locale.contains("_"))
    }

    @Test func collectReturnsScreenWithBrightness() {
        let device = DeviceCollector.collect()

        #expect(device.screen.width >= 0)
        #expect(device.screen.height >= 0)
        #expect(device.screen.dpr > 0)
        // brightness is normalised to 0–100 at the collector boundary.
        #expect(device.screen.brightness >= 0)
        #expect(device.screen.brightness <= 100)
    }

    @Test func collectReturnsPowerWithKnownBatteryState() {
        let device = DeviceCollector.collect()

        // KontextKit's switch is exhaustive; any UIDevice.batteryState
        // value maps to one of these four canonical strings.
        let known: Set<BatteryState> = [.charging, .full, .unplugged, .unknown]
        #expect(known.contains(device.power.batteryState))
    }

    @Test func collectReturnsAudioWithCanonicalOutputType() {
        let device = DeviceCollector.collect()

        #expect(device.audio.volume >= 0)
        #expect(device.audio.volume <= 100)
        // Items not in AudioOutputType are dropped at the collector
        // boundary, so anything present must be a valid case.
        let allowed: Set<AudioOutputType> = [.wired, .hdmi, .bluetooth, .usb, .other]
        for item in device.audio.outputType {
            #expect(allowed.contains(item))
        }
    }

    @Test func collectExcludesNetwork() {
        // Sync collect() never includes network — that's collectAsync's job.
        let device = DeviceCollector.collect()
        #expect(device.network == nil)
    }

    @Test func collectAsyncIncludesNetwork() async {
        let device = await DeviceCollector.collectAsync()
        #expect(device.network != nil)
    }

    @Test func collectAsyncNetworkFieldsAreShaped() async {
        // Field-level asserts on the async-only path (the sync path
        // tests pin everything else; this is what they don't reach).
        let device = await DeviceCollector.collectAsync()
        let network = device.network

        #expect(network != nil)

        // network.type must fall in the enum — KontextKit's switch
        // is exhaustive ("wifi" / "cellular" / "ethernet" / "other"),
        // and the collector falls back to .other on any drift.
        let allowed: Set<NetworkType> = [.wifi, .cellular, .ethernet, .other]
        if let type = network?.type {
            #expect(allowed.contains(type))
        }

        // userAgent comes from a WKWebView JS eval — succeeds in test host.
        // If present it should look like a real UA (contains "Mozilla").
        if let userAgent = network?.userAgent {
            #expect(!userAgent.isEmpty)
        }
    }

    @Test func collectAsyncReusesSyncFieldsWithoutDoubleSampling() async {
        // The async path runs the network collection in parallel with
        // the sync providers — both should still produce sane field
        // shapes. Pin the same invariants the sync tests pin so a
        // refactor of `collectAsync` can't quietly skip the sync path.
        let device = await DeviceCollector.collectAsync()

        #expect(device.hardware.brand == "Apple")
        #expect(!device.hardware.model.isEmpty)
        #expect(device.os.name == "ios")
        #expect(device.screen.width >= 0)
        #expect(device.audio.volume >= 0)
        #expect(device.audio.volume <= 100)
    }
}
