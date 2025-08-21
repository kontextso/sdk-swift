//
//  MockAdsServerAPI.swift
//  KontextSwiftSDK
//


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
    var frameURLReturnValue: URL?

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
        bidCode: String
    ) -> URL? {
        frameURLCalls.append((messageId, bidId, bidCode))
        return frameURLReturnValue
    }

    func redirectURL(relativeURL: URL) -> URL {
        redirectURLCalls.append(relativeURL)
        return redirectURLReturnValue ?? relativeURL
    }
}
