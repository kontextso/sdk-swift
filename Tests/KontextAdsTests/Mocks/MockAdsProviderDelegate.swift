@testable import KontextSwiftSDK

final class MockAdsProviderActingDelegate: AdsProviderActingDelegate, @unchecked Sendable {
    private(set) var receivedEvents: [AdsEvent] = []

    /// Convenience helper to check the most recent event
    var lastEvent: AdsEvent? {
        receivedEvents.last
    }

    func adsProviderActing(
        _ adsProviderActing: AdsProviderActing,
        didReceiveEvent event: AdsEvent
    ) {
        receivedEvents.append(event)
    }

    /// Reset recorded events (useful between test cases)
    func reset() {
        receivedEvents.removeAll()
    }
}
