import Combine
import Foundation
import OSLog
import SwiftUI

/// Main component of Kontext Swift SDK that loads ads based on the messages provided through setMessages.
///
/// For every chat conversation, a separate instance of `AdsProvider` should be created.
/// This class is fully thread-safe and can be used in SwiftUI views.
public final class AdsProvider: @unchecked Sendable {
    /// Basic configuration of AdsProvider that cannot be changed after initialization.
    ///
    /// - If the configuration needs to be changed, creating a new AdsProvider instance is required
    /// - Configuration always represents one chat conversation.
    /// - Multiple instance do not interfere with each other and have completely separate ads.
    public let configuration: AdsProviderConfiguration

    /// Dependency container that holds all dependencies used by AdsProvider.
    private let dependencies: DependencyContainer

    /// Delegate to receive ads related events
    ///
    /// - Receives events on the main thread
    /// - Information about newly available ads
    /// - Information about height changes of ads
    public var delegate: AdsProviderDelegate?

    /// Combine publisher that publishes ads related events
    ///
    /// - Publishes events on the main thread
    /// - Information about newly available ads
    /// - Information about height changes of ads
    public var eventPublisher: AnyPublisher<AdsProviderEvent, Never> {
        self.eventSubject.eraseToAnyPublisher()
    }

    /// Passthrough subject that is used to implement eventPublisher
    private let eventSubject: PassthroughSubject<AdsProviderEvent, Never>

    /// Initializes a new instance of `AdsProvider`.
    ///
    /// - Parameters:
    ///     - configuration: The configuration of immutable setup of the AdsProvider. Can be later accessed through `configuration` property.
    ///     - sessionId: Session ID representing the current user session. If not provided, a new session ID will be generated.
    ///     - isDisabled: If true, the ads generation will be disabled initially. Can be later enabled by calling `enable()`.
    ///     - delegate: Delegate to receive ads related updates. Called on a main thread.
    public init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool = false,
        delegate: AdsProviderDelegate? = nil
    ) {
        self.configuration = configuration
        self.dependencies = DependencyContainer.defaultContainer(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled
        )
        self.delegate = delegate
        self.eventSubject = PassthroughSubject<AdsProviderEvent, Never>()

        Task {
            await dependencies.adsProviderActing.setDelegate(delegate: self)
        }
    }

    /// Sets messages to be used as context for ad generation.
    ///
    /// - Starts ads generation when new user message is entered.
    /// - Always pass in all the messages from the conversation, not just the latest ones.
    public func setMessages(_ messages: [MessageRepresentable]) {
        Task {
            do {
                try await dependencies.adsProviderActing
                    .setMessages(messages: messages.map { $0.toModel() })
            } catch {
                os_log(.error, "[AdsProvider] setMessages error: \(error)")
            }
        }
    }

    /// Sets messages to be used as context for ad generation.
    ///
    /// - Starts ads generation when new user message is entered.
    /// - Always pass in all the messages from the conversation, not just the latest ones.
    public func setMessages(_ messages: [MessageRepresentableProviding]) {
        setMessages(messages.map { $0.message })
    }

    /// Enables generation of ads
    ///
    /// Does not **start**  ads generation for messages from previous calls to `setMessages`
    public func enable() {
        Task {
            await dependencies.adsProviderActing.setDisabled(false)
        }
    }

    /// Disables generation of ads
    ///
    /// Does not **stop**  ads generation for messages from previous calls to `setMessages`
    public func disable() {
        Task {
            await dependencies.adsProviderActing.setDisabled(true)
        }
    }
}

// MARK: - Internal methods

extension AdsProvider: AdsProviderActingDelegate {
    func adsProviderActing(
        _ adsProviderActing: AdsProviderActing,
        didChangeAvailableAdsTo ads: [Advertisement]
    ) {
        Task { @MainActor in
            delegate?.adsProvider(self, didChangeAvailableAdsTo: ads)
            eventSubject.send(.didChangeAvailableAdsTo(ads))
        }
    }

    func adsProviderActing(
        _ adsProviderActing: AdsProviderActing,
        didUpdateHeightForAd ad: Advertisement
    ) {
        Task { @MainActor in
            delegate?.adsProvider(self, didUpdateHeightForAd: ad)
            eventSubject.send(.didUpdateHeightForAd(ad))
        }
    }

    func adsProviderActing(
        _ adsProviderActing: any AdsProviderActing,
        didReceiveEvent event: AdsEvent
    ) {
        Task { @MainActor in
            delegate?.adsProvider(self, didReceiveEvent: event)
            eventSubject.send(.didReceiveEvent(event))
        }
    }
}
