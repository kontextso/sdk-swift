import Foundation
@testable import KontextSwiftSDK
import Testing

struct AppCollectorTests {

    @Test func collectReturnsBundleIdAndVersion() {
        let app = AppCollector.collect()
        #expect(!app.bundleId.isEmpty)
        #expect(!app.version.isEmpty)
    }

    @Test func collectReturnsStartTime() {
        let app = AppCollector.collect()
        #expect(app.startTime != nil)
    }

    @Test func collectReturnsStartTimeWithinReasonableBounds() {
        // startTime is captured at static-init time (lazy on first access)
        // — must be a positive epoch ms not in the future. Pins the
        // contract so a refactor (e.g. with the wrong unit) doesn't
        // quietly produce nonsense values.
        // Sample `nowMs` AFTER `collect()` so the static init has fired.
        let app = AppCollector.collect()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        if let startTime = app.startTime {
            #expect(startTime > 0)
            #expect(startTime <= nowMs)
        }
    }

    @Test func collectReturnsFirstInstallTimeWithinReasonableBounds() {
        // KontextKit's AppInfoProvider derives this from the Documents
        // directory creation date — should be > 0 and not in the future.
        // Test environments may have a nil install time (no Documents dir
        // creation observable), so the bounds are conditional.
        let app = AppCollector.collect()
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        if let firstInstall = app.firstInstallTime {
            #expect(firstInstall > 0)
            #expect(firstInstall <= nowMs)
        }
    }

    @Test func collectLeavesLastUpdateTimeNil() {
        // iOS doesn't expose a "last app update time" — only Android does
        // (sdk-kotlin populates it from PackageInfo). Pin the platform
        // contract so a future change can't quietly start populating it.
        let app = AppCollector.collect()
        #expect(app.lastUpdateTime == nil)
    }
}
