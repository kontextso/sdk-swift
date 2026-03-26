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
    public var eventPublisher: AnyPublisher<AdsEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    /// Passthrough subject that is used to implement eventPublisher
    private let eventSubject: PassthroughSubject<AdsEvent, Never>

    @MainActor
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
        self.eventSubject = PassthroughSubject<AdsEvent, Never>()

        dependencies.omService.activate()

        Task {
            await dependencies.adsProviderActing.setDelegate(delegate: self)
        }

        Task {
            let result = await IFACollector.collect(
                manualAdvertisingId: configuration.advertisingId,
                manualVendorId: configuration.vendorId,
                requestTrackingAuthorization: configuration.requestTrackingAuthorization
            )
            await dependencies.adsProviderActing.setIFA(
                advertisingId: result.advertisingId,
                vendorId: result.vendorId
            )
        }
    }

    /// Internal init used for unit testing.
    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool = false,
        dependencies: DependencyContainer,
        delegate: AdsProviderDelegate? = nil
    ) {
        self.configuration = configuration
        self.dependencies = dependencies
        self.delegate = delegate
        self.eventSubject = PassthroughSubject<AdsEvent, Never>()

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
            await dependencies.adsProviderActing
                .setMessages(messages: messages.map { $0.toModel() })
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

// MARK: - TODO: OMID session cleanup on dealloc
//
// When the publisher navigates away from the chat (e.g. opens a different conversation or closes
// the chat screen), AdsProvider is deallocated without any explicit cleanup call. Any active OMID
// sessions at that point are never properly retired or finished — OMIDAdSession.finish() is never
// called, leaving the session incomplete from the measurement system's perspective.
//
// Currently, sessions are finished in three cases:
//   1. A new user message arrives (setMessages) — retires all active sessions before preloading
//   2. The inline WebView is removed from the view hierarchy (handleInlineWebViewDispose)
//   3. The interstitial closes (handleComponentIframe / closeInterstitialAndNativeComponents)
//
// The gap: if the user navigates away while an ad is visible but no new message has been sent,
// case 1 never fires. Case 2 may or may not fire depending on how the publisher tears down its UI.
//
// Recommended fix: add a deinit to AdsProvider that finishes all active OMID sessions:
//
//   deinit {
//       let actor = dependencies.adsProviderActing
//       Task { await actor.reset() }
//   }
//
// AdsProviderActing.reset() would need to be extended to also retire+finish all omSessions
// (currently it clears states/bids but does not touch omSessions).
// The Task in deinit keeps the actor alive until cleanup completes, then releases it.

// MARK: - Internal methods

extension AdsProvider: AdsProviderActingDelegate {
    func adsProviderActing(
        _ adsProviderActing: any AdsProviderActing,
        didReceiveEvent event: AdsEvent
    ) {
        Task { @MainActor in            
            delegate?.adsProvider(self, didReceiveEvent: event)
            eventSubject.send(event)
        }
    }
}
