import Combine
import Foundation
import Testing
import UIKit
@testable import KontextSwiftSDK

// The publisher reads NotificationCenter.default, which is process-wide.
// Parallel test execution leaks notifications between cases, so serialize.
@MainActor
@Suite(.serialized)
struct PublishersConvenienceTests {
    @Test
    func keyboardHeightEmitsHeightFromWillShowNotification() async {
        let collected = await collect(from: Publishers.keyboardHeight, for: 0.05) {
            let frame = CGRect(x: 0, y: 0, width: 320, height: 291)
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillShowNotification,
                object: nil,
                userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)]
            )
        }
        #expect(collected == [291])
    }

    @Test
    func keyboardHeightEmitsZeroOnWillHideNotification() async {
        let collected = await collect(from: Publishers.keyboardHeight, for: 0.05) {
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillHideNotification,
                object: nil,
                userInfo: nil
            )
        }
        #expect(collected == [0])
    }

    @Test
    func keyboardHeightEmitsZeroWhenWillShowUserInfoIsMissing() async {
        let collected = await collect(from: Publishers.keyboardHeight, for: 0.05) {
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillShowNotification,
                object: nil,
                userInfo: nil
            )
        }
        #expect(collected == [0])
    }

    @Test
    func keyboardHeightPropagatesShowThenHideInOrder() async {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        let collected = await collect(from: Publishers.keyboardHeight, for: 0.1) {
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillShowNotification,
                object: nil,
                userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)]
            )
            NotificationCenter.default.post(
                name: UIResponder.keyboardWillHideNotification,
                object: nil,
                userInfo: nil
            )
        }
        #expect(collected == [200, 0])
    }

    // MARK: - Helpers

    /// Subscribes to `publisher`, triggers `action()`, waits `duration`, then returns all values seen.
    @MainActor
    private func collect<P: Publisher>(
        from publisher: P,
        for duration: TimeInterval,
        action: () -> Void
    ) async -> [CGFloat] where P.Output == CGFloat, P.Failure == Never {
        let box = CollectBox()
        box.cancellable = publisher.sink { box.values.append($0) }

        action()
        try? await Task.sleep(seconds: duration)
        box.cancellable = nil
        return box.values
    }
}

@MainActor
private final class CollectBox {
    var values: [CGFloat] = []
    var cancellable: AnyCancellable?
}
