import CoreFoundation
import Foundation
@testable import KontextSwiftSDK
import Testing

/// Regression tests for `InlineAdUIView.startDimensionTimer`.
///
/// The dimension-reporting timer must keep firing while UIKit is in
/// `.tracking` run-loop mode (during scroll/pan), because that's exactly
/// when the ad is moving on screen and the iframe needs fresh viewport
/// geometry for visibility tracking. If the timer pauses during scroll,
/// the iframe sees stale geometry at the worst possible moment.
///
/// `Timer.scheduledTimer(_:repeats:)` adds the timer to `RunLoop.current`
/// in `.default` mode only — `.default` is suspended whenever UIKit
/// enters `.tracking`. The fix is to construct an unscheduled `Timer`
/// and add it manually via `RunLoop.main.add(_:forMode: .common)`.
/// `.common` is a virtual mode that includes whatever modes UIKit
/// registers under it (notably `.tracking`).
@MainActor
struct DimensionTimerSchedulingTests {

    /// `UITrackingRunLoopMode` — UIKit switches the main run loop to this
    /// while a `UIScrollView` (or any other tracking interaction) is
    /// active. Constructed from the raw string so the test doesn't have
    /// to import UIKit at module scope.
    private let trackingMode = RunLoop.Mode("UITrackingRunLoopMode")

    init() {
        // UIKit normally registers `UITrackingRunLoopMode` as a common
        // mode during app startup, which is what makes `Timer +
        // .common` keep firing during scroll in production. The
        // headless test host doesn't go through that path, so register
        // tracking explicitly. `CFRunLoopAddCommonMode` is idempotent.
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), CFRunLoopMode(rawValue: "UITrackingRunLoopMode" as CFString))
    }

    @Test func timerAddedToCommonModeFiresDuringTracking() async {
        // This is the pattern `InlineAdUIView.startDimensionTimer` uses.
        // The runloop will be driven in `.tracking` mode only — if the
        // timer was registered with `.common` (which encompasses
        // tracking), it must fire. The 0.05s interval inside a 0.25s
        // window gives ~5 expected fires; `>= 2` keeps the assert robust
        // against scheduler jitter.
        var fireCount = 0
        let timer = Timer(timeInterval: 0.05, repeats: true) { _ in
            fireCount += 1
        }
        RunLoop.main.add(timer, forMode: .common)
        defer { timer.invalidate() }

        _ = RunLoop.main.run(mode: trackingMode, before: Date(timeIntervalSinceNow: 0.25))

        #expect(fireCount >= 2, "Timer added to .common must fire while runloop is in .tracking")
    }

    @Test func scheduledTimerDoesNotFireDuringTracking() async {
        // Pin the broken behavior. If someone "simplifies"
        // `startDimensionTimer` back to `Timer.scheduledTimer(...)`, this
        // test still passes (Apple's behavior hasn't changed) — but its
        // companion above will keep proving the fix's pattern works, and
        // anyone reading these tests sees both halves of the contract.
        var fireCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            fireCount += 1
        }
        defer { timer.invalidate() }

        _ = RunLoop.main.run(mode: trackingMode, before: Date(timeIntervalSinceNow: 0.25))

        #expect(fireCount == 0, "Timer.scheduledTimer uses .default mode, suspended during .tracking")
    }
}
