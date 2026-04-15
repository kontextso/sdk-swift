import Foundation
import Testing
@testable import KontextSwiftSDK

/// Tests SKAdNetworkManager.initImpression() input validation.
///
/// We cannot exercise the full start/end flow because `SKAdNetwork.startImpression`
/// requires entitlements and a valid signed impression. initImpression itself is
/// the most bug-prone part — it validates 8 fields and picks iOS-16 vs. <16
/// paths — so we exhaustively cover it.
///
/// Serialized because SKAdNetworkManager is a main-actor singleton.
@MainActor
@Suite(.serialized)
struct SKAdNetworkManagerTests {
    private func validSkanWithFidelities() -> Skan {
        Skan(
            version: "4.0",
            network: "example.com",
            itunesItem: "123456",
            sourceApp: "0",
            sourceIdentifier: nil,
            campaign: "1",
            fidelities: [AttributionFidelity(fidelity: 1, signature: "sig", nonce: "nonce", timestamp: "1000")],
            nonce: nil, timestamp: nil, signature: nil
        )
    }

    private func validSkanLegacyFields() -> Skan {
        Skan(
            version: "4.0",
            network: "example.com",
            itunesItem: "123456",
            sourceApp: "0",
            sourceIdentifier: nil,
            campaign: nil,
            fidelities: nil,
            nonce: "legacy-nonce",
            timestamp: "1000",
            signature: "legacy-sig"
        )
    }

    // MARK: - initImpression happy paths

    @Test
    func initImpressionSucceedsWithFidelities() async {
        await SKAdNetworkManager.shared.dispose()
        let success = await SKAdNetworkManager.shared.initImpression(validSkanWithFidelities())
        #expect(success == true)
    }

    @Test
    func initImpressionSucceedsWithLegacyFields() async {
        await SKAdNetworkManager.shared.dispose()
        let success = await SKAdNetworkManager.shared.initImpression(validSkanLegacyFields())
        #expect(success == true)
    }

    @Test
    func initImpressionSucceedsWithSourceIdentifierAndCampaign() async {
        await SKAdNetworkManager.shared.dispose()
        let skan = Skan(
            version: "4.0",
            network: "example.com",
            itunesItem: "123456",
            sourceApp: "99",
            sourceIdentifier: "8765",
            campaign: "42",
            fidelities: [AttributionFidelity(fidelity: 1, signature: "s", nonce: "n", timestamp: "1000")],
            nonce: nil, timestamp: nil, signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == true)
    }

    // MARK: - initImpression failure paths

    @Test
    func initImpressionFailsWhenVersionIsBlank() async {
        await SKAdNetworkManager.shared.dispose()
        var skan = validSkanWithFidelities()
        skan = Skan(
            version: "   ", network: skan.network, itunesItem: skan.itunesItem,
            sourceApp: skan.sourceApp, sourceIdentifier: nil, campaign: nil,
            fidelities: skan.fidelities, nonce: nil, timestamp: nil, signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWhenNetworkIsBlank() async {
        await SKAdNetworkManager.shared.dispose()
        var skan = validSkanWithFidelities()
        skan = Skan(
            version: skan.version, network: "", itunesItem: skan.itunesItem,
            sourceApp: skan.sourceApp, sourceIdentifier: nil, campaign: nil,
            fidelities: skan.fidelities, nonce: nil, timestamp: nil, signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWhenItunesItemIsNotNumeric() async {
        await SKAdNetworkManager.shared.dispose()
        var skan = validSkanWithFidelities()
        skan = Skan(
            version: skan.version, network: skan.network, itunesItem: "not-a-number",
            sourceApp: skan.sourceApp, sourceIdentifier: nil, campaign: nil,
            fidelities: skan.fidelities, nonce: nil, timestamp: nil, signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWithNoFidelitiesAndMissingLegacyNonce() async {
        await SKAdNetworkManager.shared.dispose()
        let skan = Skan(
            version: "4.0", network: "example.com", itunesItem: "123",
            sourceApp: "0", sourceIdentifier: nil, campaign: nil,
            fidelities: nil,
            nonce: nil, // missing
            timestamp: "1000",
            signature: "sig"
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWithNoFidelitiesAndMissingLegacyTimestamp() async {
        await SKAdNetworkManager.shared.dispose()
        let skan = Skan(
            version: "4.0", network: "example.com", itunesItem: "123",
            sourceApp: "0", sourceIdentifier: nil, campaign: nil,
            fidelities: nil,
            nonce: "n", timestamp: nil, signature: "sig"
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWithNoFidelitiesAndMissingLegacySignature() async {
        await SKAdNetworkManager.shared.dispose()
        let skan = Skan(
            version: "4.0", network: "example.com", itunesItem: "123",
            sourceApp: "0", sourceIdentifier: nil, campaign: nil,
            fidelities: nil,
            nonce: "n", timestamp: "1000", signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    @Test
    func initImpressionFailsWithEmptyFidelitiesAndMissingLegacyFields() async {
        await SKAdNetworkManager.shared.dispose()
        let skan = Skan(
            version: "4.0", network: "example.com", itunesItem: "123",
            sourceApp: "0", sourceIdentifier: nil, campaign: nil,
            fidelities: [], // empty: falls into legacy path, which is incomplete
            nonce: nil, timestamp: nil, signature: nil
        )
        let success = await SKAdNetworkManager.shared.initImpression(skan)
        #expect(success == false)
    }

    // MARK: - Lifecycle

    @Test
    func disposeIsSafeWhenNothingWasInitialized() async {
        // Calling dispose() on an already-clean manager should be a no-op.
        await SKAdNetworkManager.shared.dispose()
        await SKAdNetworkManager.shared.dispose()
    }

    @Test
    func endImpressionIsSafeWhenNoImpressionActive() async {
        await SKAdNetworkManager.shared.dispose()
        await SKAdNetworkManager.shared.endImpression()
    }

    @Test
    func initAfterInitReplacesPreviousImpression() async {
        await SKAdNetworkManager.shared.dispose()
        let first = await SKAdNetworkManager.shared.initImpression(validSkanWithFidelities())
        let second = await SKAdNetworkManager.shared.initImpression(validSkanWithFidelities())
        #expect(first == true)
        #expect(second == true)
    }

    // MARK: - DefaultSKAdNetworkManager actor-wrapper passthrough

    @Test
    func defaultActorForwardsInitImpression() async {
        let actor = DefaultSKAdNetworkManager.shared
        let success = await actor.initImpression(validSkanWithFidelities())
        #expect(success == true)
        await actor.dispose()
    }
}
