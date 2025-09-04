import Combine
import Foundation

// MARK: - AdsProviderActing

protocol AdsProviderActing: Sendable {
    func setDelegate(delegate: AdsProviderActingDelegate?) async

    func setDisabled(_ isDisabled: Bool) async

    func setMessages(messages: [AdsMessage]) async

    func reset() async
}

// MARK: - AdsProviderActingDelegate

protocol AdsProviderActingDelegate: AnyObject, Sendable {
    func adsProviderActing(
        _ adsProviderActing: AdsProviderActing,
        didReceiveEvent event: AdsEvent
    )
}
