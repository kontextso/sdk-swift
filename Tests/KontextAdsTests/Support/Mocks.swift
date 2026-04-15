import Combine
import Foundation
import UIKit
import WebKit
@testable import KontextSwiftSDK

// MARK: - Stub AdsServerAPI

final class StubAdsServerAPI: AdsServerAPI, @unchecked Sendable {
    private let lock = NSLock()

    struct PreloadCall: Sendable {
        let sessionId: String?
        let configuration: AdsProviderConfiguration
        let isDisabled: Bool
        let advertisingId: String?
        let vendorId: String?
        let messages: [AdsMessage]
    }

    private var _preloadCalls: [PreloadCall] = []
    private var _preloadResponder: (@Sendable (PreloadCall) async throws -> PreloadedData)?

    var preloadCalls: [PreloadCall] { lock.lock(); defer { lock.unlock() }; return _preloadCalls }
    var preloadCallCount: Int { preloadCalls.count }

    func setPreloadResponse(_ data: PreloadedData) {
        lock.lock(); defer { lock.unlock() }
        _preloadResponder = { _ in data }
    }
    func setPreloadError(_ error: Error) {
        lock.lock(); defer { lock.unlock() }
        _preloadResponder = { _ in throw error }
    }
    func setPreloadResponder(_ responder: @escaping @Sendable (PreloadCall) async throws -> PreloadedData) {
        lock.lock(); defer { lock.unlock() }
        _preloadResponder = responder
    }

    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        isDisabled: Bool,
        advertisingId: String?,
        vendorId: String?,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        let call = PreloadCall(
            sessionId: sessionId,
            configuration: configuration,
            isDisabled: isDisabled,
            advertisingId: advertisingId,
            vendorId: vendorId,
            messages: messages
        )
        let responder: (@Sendable (PreloadCall) async throws -> PreloadedData)? = lock.withLock {
            _preloadCalls.append(call)
            return _preloadResponder
        }
        guard let responder else {
            throw APIError.invalidResponse(statusCode: -1)
        }
        return try await responder(call)
    }

    @MainActor
    func frameURL(messageId: String, bidId: String, bidCode: String, otherParams: [String: String]) -> URL? {
        URL(string: "https://stub.test/api/frame/\(bidId)")
    }

    @MainActor
    func componentURL(messageId: String, bidId: String, bidCode: String, component: String, otherParams: [String: String]) -> URL? {
        URL(string: "https://stub.test/api/\(component)/\(bidId)")
    }

    func redirectURL(relativeURL: URL) -> URL { relativeURL }
}

// MARK: - Stub URLOpening

@MainActor
final class StubURLOpener: URLOpening {
    private(set) var openedURLs: [URL] = []
    var canOpenAnyURL = true

    func canOpenURL(_ url: URL) -> Bool { canOpenAnyURL }

    func open(
        _ url: URL,
        options: [UIApplication.OpenExternalURLOptionsKey: Any],
        completionHandler completion: (@MainActor @Sendable (Bool) -> Void)?
    ) {
        openedURLs.append(url)
        completion?(true)
    }
}

// MARK: - Stub OMManaging

final class StubOMManager: OMManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var _activateCalls = 0
    private var _createSessionCalls = 0
    private var _shouldThrowOnCreate = false

    var activateCallCount: Int { lock.lock(); defer { lock.unlock() }; return _activateCalls }
    var createSessionCallCount: Int { lock.lock(); defer { lock.unlock() }; return _createSessionCalls }

    func activate() -> Bool {
        lock.lock(); defer { lock.unlock() }
        _activateCalls += 1
        return true
    }

    func createSession(_ webView: WKWebView, url: URL?, creativeType: OmCreativeType) throws -> OMSession {
        lock.lock()
        _createSessionCalls += 1
        let shouldThrow = _shouldThrowOnCreate
        lock.unlock()
        if shouldThrow {
            throw OMManager.OMError.sdkIsNotActive
        }
        // Fail softly — we don't exercise OM session internals in unit tests.
        throw OMManager.OMError.sessionCreationFailed("stub")
    }
}

// MARK: - Stub SKAdNetworkManager

actor StubSKAdNetworkManager: SKAdNetworkManaging {
    private(set) var initCalls: [Skan] = []
    private(set) var startCalls = 0
    private(set) var endCalls = 0
    private(set) var disposeCalls = 0
    private var _initResult = true

    func setInitResult(_ result: Bool) { _initResult = result }

    func initImpression(_ skan: Skan) async -> Bool {
        initCalls.append(skan)
        return _initResult
    }
    func startImpression() async { startCalls += 1 }
    func endImpression() async { endCalls += 1 }
    func dispose() async { disposeCalls += 1 }
}

// MARK: - Stub SKOverlayPresenter

@MainActor
final class StubSKOverlayPresenter: SKOverlayPresenting {
    private(set) var presentCalls: [(skan: Skan, position: SKOverlayDisplayPosition, dismissible: Bool)] = []
    private(set) var dismissCalls = 0
    var presentReturnValue = true
    var dismissReturnValue = true

    func present(skan: Skan, position: SKOverlayDisplayPosition, dismissible: Bool) async -> Bool {
        presentCalls.append((skan, position, dismissible))
        return presentReturnValue
    }

    func dismiss() async -> Bool {
        dismissCalls += 1
        return dismissReturnValue
    }
}

// MARK: - Stub SKStoreProductPresenter

@MainActor
final class StubSKStoreProductPresenter: SKStoreProductPresenting {
    private(set) var presentCalls: [Skan] = []
    private(set) var dismissCalls = 0
    var presentReturnValue = true
    var dismissReturnValue = true

    func present(skan: Skan) async -> Bool {
        presentCalls.append(skan)
        return presentReturnValue
    }

    func dismiss() async -> Bool {
        dismissCalls += 1
        return dismissReturnValue
    }
}

// MARK: - Capturing delegate

final class CapturingDelegate: AdsProviderActingDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [AdsEvent] = []

    var events: [AdsEvent] {
        lock.lock(); defer { lock.unlock() }; return _events
    }

    var eventNames: [String] { events.map(\.name) }

    func adsProviderActing(_ adsProviderActing: AdsProviderActing, didReceiveEvent event: AdsEvent) {
        lock.lock(); defer { lock.unlock() }
        _events.append(event)
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        _events.removeAll()
    }
}

// MARK: - NSLock convenience

extension NSLock {
    func withLock<T>(_ block: () -> T) -> T {
        lock(); defer { unlock() }; return block()
    }
}

// MARK: - Test helpers

/// Fills a PreloadedData as if the server returned a single valid bid.
func preloadedData(
    bidId: UUID = UUID(),
    code: String = "inlineAd",
    position: AdDisplayPosition = .afterAssistantMessage,
    sessionId: String = "sess-1",
    skip: Bool? = nil,
    skipCode: String? = nil,
    permanentError: Bool? = nil,
    impressionTrigger: ImpressionTrigger = .immediate,
    skan: Skan? = nil,
    creativeType: OmCreativeType? = nil
) -> PreloadedData {
    PreloadedData(
        sessionId: sessionId,
        bids: [Bid(
            bidId: bidId,
            code: code,
            adDisplayPosition: position,
            skan: skan,
            impressionTrigger: impressionTrigger,
            creativeType: creativeType
        )],
        remoteLogLevel: nil,
        permanentError: permanentError,
        skip: skip,
        skipCode: skipCode
    )
}

func emptyPreloadedData(
    sessionId: String? = "sess-1",
    skip: Bool? = nil,
    skipCode: String? = nil,
    permanentError: Bool? = nil
) -> PreloadedData {
    PreloadedData(
        sessionId: sessionId,
        bids: [],
        remoteLogLevel: nil,
        permanentError: permanentError,
        skip: skip,
        skipCode: skipCode
    )
}

extension AdsProviderConfiguration {
    static func testConfig(
        placementCodes: [String] = ["inlineAd"]
    ) -> AdsProviderConfiguration {
        AdsProviderConfiguration(
            publisherToken: "pub-tok",
            userId: "u-1",
            conversationId: "c-1",
            enabledPlacementCodes: placementCodes
        )
    }
}
