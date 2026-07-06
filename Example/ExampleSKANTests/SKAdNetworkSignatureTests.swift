import XCTest
import StoreKit
import StoreKitTest

/// Option 1 of the "SKAN Testing" plan: validate that the ad server's signed
/// SKAdNetwork payload is accepted by Apple's own StoreKit Test validator
/// (`SKAdTestSession.validateImpression(_:withPublicKey:)`).
///
/// The values below are a REAL `/preload` response — forced `kontextso ad_id:170932`
/// on publisher `liner-1234` (2026-07-06), fidelity-0 (view-through) entry. The same
/// signature has already been verified locally against the public key via ECDSA
/// P-256 / SHA-256, so this test is expected to pass; it confirms Apple's validator
/// agrees. Regenerate with the curl in the SKAN Testing doc if it needs refreshing.
///
/// Requirements:
///  - **Physical device on iOS 16.4+** — the iOS Simulator does not support SKAdNetwork.
///  - `cdkw7geqh8.skadnetwork` present in the host app's Info.plist `SKAdNetworkItems`
///    (added to `Example/Example/Info.plist`).
@available(iOS 16.4, *)
final class SKAdNetworkSignatureTests: XCTestCase {

    /// Our registered ad network's PUBLIC key — base64 of the DER SubjectPublicKeyInfo
    /// (the body of `kontextso_skadnetwork_public_key.pem`). Public key, safe to embed.
    private let publicKey =
        "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEOcpzQ09dUKEQL/sgkDA9OYoQy8W8" +
        "6dZidEWjdLlymmupM8Eb2xbfRWNRBb41WDom9i6ifZtbk+F9hPLdEJAUYw=="

    /// Signed view-through impression (fidelity-0) from a real `/preload` response.
    func testViewThroughSignatureIsValidAgainstOurPublicKey() throws {
        // NOTE: SKAdTestSession forces source-app-id = 0 in the test environment
        // (Apple: "In the testing environment, this value is always 0"), so this
        // payload was signed by the server with sourceApp = 0 (liner-1234's
        // app_store_id temporarily set to "0" to produce a test-env signature).
        let impression = SKAdImpression()
        impression.version = "4.0"
        impression.adNetworkIdentifier = "cdkw7geqh8.skadnetwork"
        impression.sourceIdentifier = 39
        impression.advertisedAppStoreItemIdentifier = 525463029
        impression.adImpressionIdentifier = "77cd4470-fc8d-41ca-a87b-b119cc7a65bb"
        impression.sourceAppStoreItemIdentifier = 0
        impression.timestamp = 1783360869859
        impression.signature =
            "MEUCIQCulUiuDzAjhJUfZcFaRPNLq9PCm5Tw3Y76n8P29wkiIgIgSC3by2i3ORp/mdB4Fla7QkcEQegyOg1Zmn75aMTk3jo="

        let session = SKAdTestSession()

        // `validate(_:publicKey:)` validates a view-through SKAdImpression (fidelity-0).
        // (The StoreKit-rendered / fidelity-1 variant is `validateImpression(parameters:publicKey:)`.)
        // Throws if the signature/params don't validate against the public key.
        XCTAssertNoThrow(
            try session.validate(impression, publicKey: publicKey),
            "Ad-server SKAN signature rejected by SKAdTestSession"
        )
    }
}
