import Foundation
import KontextKit
@testable import KontextSwiftSDK
import Testing

#if canImport(WebKit)
import WebKit
#endif

// MARK: - Mock OMManager

/// A mock OMManager for testing that doesn't depend on real OMSDK binary.
/// `@unchecked Sendable` because tests mutate `var` properties directly;
/// in practice the test runner serializes access on the test executor.
final class MockOMManager: @unchecked Sendable, OMManaging {
    var activateCalled = false
    var activateResult = true
    var createSessionCalled = false
    var createSessionCreativeType: OMCreativeType?
    var shouldThrow = false

    // Track retire/finish calls
    var sessionRetired = false
    var sessionFinished = false
    var sessionStarted = false
    var errorLogged: (errorType: String?, message: String?)?

    func activate() -> Bool {
        activateCalled = true
        return activateResult
    }

    #if canImport(WebKit)
    func createSession(_ webView: WKWebView, url: URL?, creativeType: OMCreativeType) async throws -> OMSession {
        createSessionCalled = true
        createSessionCreativeType = creativeType
        if shouldThrow {
            throw NSError(domain: "OMTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        // We can't create a real OMSession without real OMSDK objects,
        // so this test verifies the manager is called correctly.
        // In a real test environment with OMSDK, this would return a real session.
        fatalError("Cannot create real OMSession in test environment without OMSDK binary")
    }
    #endif
}

struct OMTests {

    // OMCreativeType, OMManager.omsdkScript, and the OMID-layer tests
    // that exercise KontextKit-owned types live in
    // KontextKit/ios/Tests/OMSDKTests.swift — closer to the code they
    // exercise. The tests below cover sdk-swift-specific surface only:
    // sdk-swift's `Constants`, `Bid`, and `BidDTO`.
    // `MockOMManager` (declared above) stays here because SKANTests.swift
    // and other sdk-swift test files use it.

    // MARK: - Constants

    @Test func constantsPartnerName() {
        #expect(Constants.omidPartnerName == "Kontextso")
    }

    @Test func constantsIntegrationVersion() {
        #expect(Constants.omidPartnerVersion == "1.0.0")
    }

    // MARK: - MockOMManager (sanity checks for the test helper)

    @Test func mockOMManagerActivate() {
        let manager = MockOMManager()
        let result = manager.activate()

        #expect(result == true)
        #expect(manager.activateCalled == true)
    }

    @Test func mockOMManagerActivateReturnsFalse() {
        let manager = MockOMManager()
        manager.activateResult = false
        let result = manager.activate()

        #expect(result == false)
        #expect(manager.activateCalled == true)
    }

    // MARK: - Bid with creative type

    @Test func bidWithCreativeType() {
        let bid = Bid(bidId: UUID(), code: "inlineAd", creativeType: .video)
        #expect(bid.creativeType == .video)
    }

    @Test func bidWithoutCreativeType() {
        let bid = Bid(bidId: UUID(), code: "inlineAd")
        #expect(bid.creativeType == nil)
    }

    @Test func bidDTOWithCreativeTypeDecoding() throws {
        // bidId is strictly typed as UUID — invalid UUIDs throw at decode.
        let json = Data("""
        {
            "bidId": "12345678-1234-1234-1234-123456789012",
            "code": "inlineAd",
            "revenue": 0.5,
            "creativeType": "video"
        }
        """.utf8)

        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        let bid = dto.toBid()

        #expect(bid.creativeType == .video)
    }

    @Test func bidDTOWithoutCreativeTypeDecoding() throws {
        let json = Data("""
        {
            "bidId": "12345678-1234-1234-1234-123456789012",
            "code": "inlineAd"
        }
        """.utf8)

        let dto = try JSONDecoder().decode(BidDTO.self, from: json)
        let bid = dto.toBid()

        #expect(bid.creativeType == nil)
    }
}
