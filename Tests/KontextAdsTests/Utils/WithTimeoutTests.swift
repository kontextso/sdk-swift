import Foundation
import Testing
@testable import KontextSwiftSDK

struct WithTimeoutTests {
    @Test
    func returnsValueWhenWorkFinishesBeforeTimeout() async throws {
        let result = try await withTimeout(1.0) {
            try await Task.sleep(seconds: 0.01)
            return 42
        }
        #expect(result == 42)
    }

    @Test
    func propagatesErrorThrownByWork() async {
        struct BoomError: Error {}
        await #expect(throws: BoomError.self) {
            try await withTimeout(1.0) {
                throw BoomError()
            }
        }
    }

    @Test
    func throwsCancellationErrorWhenWorkExceedsTimeout() async {
        await #expect(throws: CancellationError.self) {
            try await withTimeout(0.05) {
                try await Task.sleep(seconds: 1.0)
                return "never"
            }
        }
    }

    @Test
    func cancelsWorkAfterTimeoutFires() async throws {
        // If work keeps running after the timeout, its Task should observe cancellation
        // once group.cancelAll() propagates. We verify by checking Task.isCancelled flips.
        let cancellationObserved = LockedBox<Bool>(false)

        _ = try? await withTimeout(0.05) {
            do {
                try await Task.sleep(seconds: 1.0)
                return "done"
            } catch {
                await cancellationObserved.set(Task.isCancelled || error is CancellationError)
                throw error
            }
        }

        // Give the structured-concurrency machinery a moment to run cancellation.
        try? await Task.sleep(seconds: 0.05)
        let observed = await cancellationObserved.value
        #expect(observed)
    }

    @Test
    func timeoutOfZeroFiresImmediately() async {
        await #expect(throws: CancellationError.self) {
            try await withTimeout(0.0) {
                try await Task.sleep(seconds: 0.5)
                return "never"
            }
        }
    }

    // MARK: - Test helpers

    private actor LockedBox<T: Sendable> {
        private(set) var value: T
        init(_ value: T) { self.value = value }
        func set(_ value: T) { self.value = value }
    }
}
