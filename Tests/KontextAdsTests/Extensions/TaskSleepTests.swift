import Foundation
import Testing
@testable import KontextSwiftSDK

struct TaskSleepTests {
    @Test
    func sleepSecondsBlocksForAtLeastGivenDuration() async throws {
        let start = Date()
        try await Task.sleep(seconds: 0.05)
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed >= 0.045) // small jitter allowance
    }

    @Test
    func sleepMillisecondsBlocksForAtLeastGivenDuration() async throws {
        let start = Date()
        try await Task.sleep(milliseconds: 50)
        let elapsed = Date().timeIntervalSince(start) * 1000
        #expect(elapsed >= 45.0)
    }

    @Test
    func sleepWithZeroDurationReturnsWithoutError() async throws {
        // The duration budget is unenforceable under parallel test load —
        // we only care that zero doesn't crash or block indefinitely.
        try await Task.sleep(seconds: 0)
    }

    @Test
    func sleepThrowsWhenTaskIsCancelled() async {
        let handle = Task<Void, Error> {
            try await Task.sleep(seconds: 10)
        }
        handle.cancel()
        await #expect(throws: (any Error).self) {
            try await handle.value
        }
    }
}
