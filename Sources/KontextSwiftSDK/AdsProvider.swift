//
//  AdsProvider.swift
//  KontextSwiftSDK
//

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


    /// Initializes a new instance of `AdsProvider`.
    ///
    /// - Parameters:
    ///     - configuration: The configuration od immutable setup of the AdsProvider. Can be later accessd through `configuration` property.
    ///     - sessionId: Session ID representing the current user session. If not provided, a new session ID will be generated.
    @MainActor
    public init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool = false
    ) {
        self.configuration = configuration
        self.dependencies = DependencyContainer.defaultContainer(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled
        )
    }

    /// Sets messages to be used as context for ad generation.
    ///
    /// - Starts ads generation when new user message is entered.
    /// - Always pass in all the messages from the conversation, not just the latest ones.
    public func setMessages(_ messages: [MessageRepresentable]) {
        Task {
            do {
                try await dependencies.adsProviderActing
                    .setMessages(messages: mapMessageRepresentables(messages))
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
        Task { await dependencies.adsProviderActing.setDisabled(false) }
    }
    
    /// Disables generation of ads
    ///
    /// Does not **stop**  ads generation for messages from previous calls to `setMessages`
    public func disable() {
        Task { await dependencies.adsProviderActing.setDisabled(true) }
    }
}

// MARK: - Internal methods

extension AdsProvider {
    @MainActor
    func inlineAdViewModel(
        code: String,
        messageId: String,
        otherParams: [String: String]
    ) -> InlineAdViewModel {
        InlineAdViewModel(
            sharedStorage: dependencies.sharedStorage,
            adsServerAPI: dependencies.adsServerAPI,
            adsProviderActing: dependencies.adsProviderActing,
            code: code,
            messageId: messageId,
            otherParams: otherParams
        )
    }
}

// MARK: - Private methods

private extension AdsProvider {
    func mapMessageRepresentables(
        _ messagesRepresentables: [MessageRepresentable]
    ) -> [AdsMessage] {
        messagesRepresentables.map { representable in
            AdsMessage(
                id: representable.id,
                role: representable.role,
                content: representable.content,
                createdAt: representable.createdAt
            )
        }
    }
}
