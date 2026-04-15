import Combine
import Foundation

// MARK: - AdsProviderActing

protocol AdsProviderActing: Sendable {
    func setDelegate(delegate: AdsProviderActingDelegate?) async

    func setDisabled(_ isDisabled: Bool) async

    func setMessages(messages: [AdsMessage]) async

    func sendUserEvent(name: UserEventName) async

    func reset() async

    func setIFA(advertisingId: String?, vendorId: String?) async
}

// MARK: - AdsProviderActingDelegate

protocol AdsProviderActingDelegate: AnyObject, Sendable {
    func adsProviderActing(
        _ adsProviderActing: AdsProviderActing,
        didReceiveEvent event: AdsEvent
    )
}
