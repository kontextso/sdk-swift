import Foundation
@testable import KontextSwiftSDK
import Testing

@MainActor
struct KontextAdsTests {

    @Test func createSessionReturnsConfiguredSession() {
        let session = KontextAds.createSession(SessionOptions(
            publisherToken: "test-token",
            userId: "user-1",
            conversationId: "conv-1"
        ))

        #expect(session.config.publisherToken == "test-token")
        #expect(session.config.userId == "user-1")
        #expect(session.config.conversationId == "conv-1")
        #expect(!session.destroyed)
    }

    @Test func createSessionAppliesDefaults() {
        // Defaults flow through resolveConfig: empty placement-code array
        // becomes `[Constants.defaultPlacementCode]`, ad server URL
        // defaults to production, requestTrackingAuthorization is true.
        let session = KontextAds.createSession(SessionOptions(
            publisherToken: "t",
            userId: "u",
            conversationId: "c"
        ))

        #expect(session.config.enabledPlacementCodes == [Constants.defaultPlacementCode])
        #expect(session.config.adServerUrl == Constants.defaultAdServerUrl)
        #expect(session.config.requestTrackingAuthorization == true)
    }

    @Test func createSessionForwardsCustomFields() {
        let onEvent: AdEventHandler = { _ in }
        let onDebugEvent: DebugEventHandler = { _, _ in }
        let session = KontextAds.createSession(SessionOptions(
            publisherToken: "t",
            userId: "u",
            conversationId: "c",
            enabledPlacementCodes: ["banner", "interstitial"],
            adServerUrl: "https://example.test",
            advertisingId: "idfa-x",
            vendorId: "idfv-y",
            requestTrackingAuthorization: false,
            onEvent: onEvent,
            onDebugEvent: onDebugEvent
        ))

        #expect(session.config.enabledPlacementCodes == ["banner", "interstitial"])
        #expect(session.config.adServerUrl == "https://example.test")
        #expect(session.config.advertisingId == "idfa-x")
        #expect(session.config.vendorId == "idfv-y")
        #expect(session.config.requestTrackingAuthorization == false)
        #expect(session.config.onEvent != nil)
        #expect(session.config.onDebugEvent != nil)
    }
}
