//
//  AdsProviderActor.swift
//  KontextSwiftSDK
//

// MARK: - AdsProviderActing

protocol AdsProviderActing: Sendable {
    func setDisabled(_ isDisabled: Bool) async
    
    func setMessages(messages: [AdsMessage]) async throws

    func reset() async
}

// MARK: - AdsProviderActor

actor AdsProviderActor: AdsProviderActing {
    /// Represents a single session of interaction within a conversation.
    /// A new sessionId is generated each time the SDK is initialized—typically when the user opens or reloads the app.
    /// This helps us track discrete usage periods, even within the same ongoing conversation.
    private var sessionId: String?
    /// Indicates whether the ads provider is disabled.
    private var isDisabled: Bool
    /// Last messages to sent to BE
    private var messages: [AdsMessage]
    private var lastPreloadUserMessageCount: Int
    /// Preload timeout in seconds.
    private var preloadTimeout: Int
    
    /// Initial configuration passed down by AdsProvider.
    private let configuration: AdsProviderConfiguration
    private let adsServerAPI: AdsServerAPI
    private let sharedStorage: SharedStorage
    
    init(
        configuration: AdsProviderConfiguration,
        sessionId: String? = nil,
        isDisabled: Bool,
        adsServerAPI: AdsServerAPI,
        sharedStorage: SharedStorage
    ) {
        self.configuration = configuration
        self.sessionId = sessionId
        self.isDisabled = isDisabled
        self.adsServerAPI = adsServerAPI
        self.sharedStorage = sharedStorage
        messages = []
        lastPreloadUserMessageCount = 0
        preloadTimeout = 60
    }
    
    /// Enables or Disables the generation of ads.
    func setDisabled(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }
    
    func setMessages(messages: [AdsMessage]) async throws {
        guard !isDisabled else {
            return
        }
        
        let newUserMessages = messages.filter { $0.role == .user }
        let newUserMessageCount = newUserMessages.count
        let messagesToSend = Array(messages.suffix(10))
        let shouldPreload = lastPreloadUserMessageCount < newUserMessageCount
        self.messages = messages
        
        await MainActor.run {
            if shouldPreload { sharedStorage.bids = [] }
            sharedStorage.messages = messagesToSend
            sharedStorage.lastUserMessageId = messagesToSend
                .last(where: { $0.role == .user })?.id
            sharedStorage.lastAssistantMessageId = messagesToSend
                .last(where: { $0.role == .assistant })?.id
        }
        
        guard shouldPreload else {
            return
        }
        
        self.lastPreloadUserMessageCount = newUserMessageCount
        
        let preloadedData = try await preloadWithTimeout(
            timeout: preloadTimeout,
            sessionId: sessionId,
            configuration: configuration,
            api: adsServerAPI,
            messages: messagesToSend
        )
        
        if preloadedData.permanentError == true {
            isDisabled = true
        }
        
        sessionId = preloadedData.sessionId
        
        await MainActor.run {
            sharedStorage.bids = preloadedData.bids ?? []
            sharedStorage.relevantAssistantMessageId = nil
        }
    }

    func reset() async {
        await MainActor.run {
            sharedStorage.bids = []
            sharedStorage.messages = []
            sharedStorage.lastUserMessageId = nil
            sharedStorage.lastAssistantMessageId = nil
            sharedStorage.relevantAssistantMessageId = nil
        }
    }
}

private extension AdsProviderActor {
    func preloadWithTimeout(
        timeout: Int,
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        api: AdsServerAPI,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        try await withThrowingTaskGroup(of: PreloadedData.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                throw CancellationError()
            }
            group.addTask {
                try await api.preload(
                    sessionId: sessionId,
                    configuration: configuration,
                    messages: messages
                )
            }
            
            guard let data = try await group.next() else {
                throw CancellationError()
            }
            
            group.cancelAll()
            return data
        }
    }
}
