import Foundation
@testable import KontextSwiftSDK

@MainActor
final class MockSKOverlayPresenter: SKOverlayPresenting, @unchecked Sendable {
    private(set) var presentCalled = false
    private(set) var dismissCalled = false

    func present(
        skan: Skan,
        position: SKOverlayDisplayPosition,
        dismissible: Bool
    ) async -> Bool {
        presentCalled = true
        return true
    }

    func dismiss() async -> Bool {
        dismissCalled = true
        return true
    }
}

@MainActor
final class MockSKStoreProductPresenter: SKStoreProductPresenting, @unchecked Sendable {
    private(set) var presentCalled = false
    private(set) var dismissCalled = false

    func present(skan: Skan) async -> Bool {
        presentCalled = true
        return true
    }

    func dismiss() async -> Bool {
        dismissCalled = true
        return true
    }
}
