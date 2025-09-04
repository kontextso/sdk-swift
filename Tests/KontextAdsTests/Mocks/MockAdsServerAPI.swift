import Foundation
@testable import KontextSwiftSDK

final class MockAdsServerAPI: AdsServerAPI, @unchecked Sendable {
    // MARK: - Properties to track calls
    private(set) var preloadCalled = false
    private(set) var preloadSessionId: String?
    private(set) var preloadConfiguration: AdsProviderConfiguration?
    private(set) var preloadMessages: [AdsMessage] = []

    var preloadResult: PreloadedData = .data1
    var preloadError: Error?

    private(set) var frameURLCalls: [(messageId: String, bidId: String, bidCode: String)] = []
    private(set) var componentURLCalls: [(messageId: String, bidId: String, bidCode: String)] = []
    var frameURLReturnValue: URL?
    var componentURLReturnValue: URL?

    private(set) var redirectURLCalls: [URL] = []
    var redirectURLReturnValue: URL?

    // MARK: - AdsServerAPI Implementation

    func preload(
        sessionId: String?,
        configuration: AdsProviderConfiguration,
        messages: [AdsMessage]
    ) async throws -> PreloadedData {
        preloadCalled = true
        preloadSessionId = sessionId
        preloadConfiguration = configuration
        preloadMessages = messages

        if let error = preloadError {
            throw error
        }

        return preloadResult
    }

    func frameURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        otherParams: [String : String]
    ) -> URL? {
        frameURLCalls.append((messageId, bidId, bidCode))
        return frameURLReturnValue
    }

    func componentURL(
        messageId: String,
        bidId: String,
        bidCode: String,
        component: String,
        otherParams: [String : String]
    ) -> URL? {
        componentURLCalls.append((messageId, bidId, bidCode))
        return componentURLReturnValue
    }

    func redirectURL(relativeURL: URL) -> URL {
        redirectURLCalls.append(relativeURL)
        return redirectURLReturnValue ?? relativeURL
    }
}
