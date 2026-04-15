import Foundation
import Testing
@testable import KontextSwiftSDK

/// Input-validation tests for SKStoreProductManager.
/// Same rationale as SKOverlayManagerTests — the success path needs a live
/// view hierarchy the xctest process doesn't have.
@MainActor
@Suite(.serialized)
struct SKStoreProductManagerTests {
    private func skan(itunesItem: String) -> Skan {
        Skan(
            version: "4.0",
            network: "example.com",
            itunesItem: itunesItem,
            sourceApp: "0",
            sourceIdentifier: nil,
            campaign: nil,
            fidelities: [AttributionFidelity(fidelity: 1, signature: "s", nonce: UUID().uuidString, timestamp: "1000")],
            nonce: nil, timestamp: nil, signature: nil
        )
    }

    @Test
    func presentReturnsFalseForEmptyItunesItem() async {
        let result = await SKStoreProductManager.shared.present(skan: skan(itunesItem: ""))
        #expect(result == false)
    }

    @Test
    func presentReturnsFalseForWhitespaceOnlyItunesItem() async {
        let result = await SKStoreProductManager.shared.present(skan: skan(itunesItem: "   "))
        #expect(result == false)
    }

    @Test
    func presentReturnsFalseForNonNumericItunesItem() async {
        let result = await SKStoreProductManager.shared.present(skan: skan(itunesItem: "not-a-number"))
        #expect(result == false)
    }

    @Test
    func dismissReturnsFalseWhenNothingPresented() async {
        let result = await SKStoreProductManager.shared.dismiss()
        #expect(result == false)
    }
}
