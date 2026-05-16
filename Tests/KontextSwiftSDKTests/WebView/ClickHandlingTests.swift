import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct ClickHandlingTests {

    // MARK: - Helpers

    private func makeSession(adServerUrl: URL = URL(string: "http://0.0.0.0:1")!) -> Session {
        let config = ResolvedConfig(
            publisherToken: "test-token",
            userId: "test-user",
            conversationId: "test-conv",
            enabledPlacementCodes: ["inlineAd"],
            adServerUrl: adServerUrl,
            character: nil,
            variantId: nil,
            regulatory: nil,
            userEmail: nil,
            advertisingId: nil,
            vendorId: nil,
            requestTrackingAuthorization: false,
            onEvent: nil,
            onDebugEvent: nil,
            installId: "00000000-0000-7000-8000-000000000000"
        )
        return Session(config: config)
    }

    // MARK: - ClickData construction

    @Test func clickDataDefaultsToNilValues() {
        let data = IframeEvent.ClickData()
        #expect(data.url == nil)
        #expect(data.target == .browser)
        #expect(data.fallbackUrl == nil)
        #expect(data.appStoreId == nil)
    }

    @Test func clickDataStoresAllProperties() {
        let data = IframeEvent.ClickData(
            url: "https://example.com",
            target: .inApp,
            fallbackUrl: "https://fallback.com",
            appStoreId: "123456"
        )
        #expect(data.url == "https://example.com")
        #expect(data.target == .inApp)
        #expect(data.fallbackUrl == "https://fallback.com")
        #expect(data.appStoreId == "123456")
    }

    // MARK: - Click event handling

    @Test func clickWithNoUrlIsNoOp() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")

        // Should not crash when url is nil
        ad.handleIframeEvent(.clickIframe(IframeEvent.ClickData()))
        // No assertion needed -- just verifying it doesn't crash
    }

    @Test func clickEventAfterDestroyIsIgnored() {
        let session = makeSession()
        let ad = Ad(session: session, messageId: "a1")
        ad.destroy()

        // Should be a no-op after destroy
        ad.handleIframeEvent(.clickIframe(IframeEvent.ClickData(url: "https://example.com")))
        #expect(ad.destroyed)
    }
}
