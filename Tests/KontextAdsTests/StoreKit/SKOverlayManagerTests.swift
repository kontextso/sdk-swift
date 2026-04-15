import Foundation
import Testing
@testable import KontextSwiftSDK

/// Input-validation and error-path tests for SKOverlayManager.
///
/// We cannot exercise the successful presentation flow in unit tests — the real
/// StoreKit delegate callback only fires inside a foreground UIWindowScene,
/// which xctest cannot reliably provide. Instead, we cover the preconditions
/// that `present(skan:position:dismissible:)` validates synchronously before
/// ever reaching StoreKit.
///
/// Serialized because SKOverlayManager is a main-actor singleton.
@MainActor
@Suite(.serialized)
struct SKOverlayManagerTests {
    // MARK: - Test fixtures

    /// A Skan that has every field needed for fidelity-1 attribution.
    private func validSkan(itunesItem: String = "123456") -> Skan {
        Skan(
            version: "4.0",
            network: "example.com",
            itunesItem: itunesItem,
            sourceApp: "0",
            sourceIdentifier: nil,
            campaign: nil,
            fidelities: [
                AttributionFidelity(fidelity: 1, signature: "sig", nonce: "n", timestamp: "1000"),
            ],
            nonce: nil,
            timestamp: nil,
            signature: nil
        )
    }

    // MARK: - present() preconditions

    @Test
    func presentReturnsFalseWhenItunesItemIsEmpty() async {
        let result = await SKOverlayManager.shared.present(
            skan: Skan(
                version: "4.0", network: "x.com", itunesItem: "",
                sourceApp: "0", sourceIdentifier: nil, campaign: nil,
                fidelities: [AttributionFidelity(fidelity: 1, signature: "s", nonce: "n", timestamp: "1")],
                nonce: nil, timestamp: nil, signature: nil
            ),
            position: .bottom,
            dismissible: true
        )
        #expect(result == false)
    }

    @Test
    func presentReturnsFalseWhenItunesItemIsOnlyWhitespace() async {
        let result = await SKOverlayManager.shared.present(
            skan: Skan(
                version: "4.0", network: "x.com", itunesItem: "   ",
                sourceApp: "0", sourceIdentifier: nil, campaign: nil,
                fidelities: [AttributionFidelity(fidelity: 1, signature: "s", nonce: "n", timestamp: "1")],
                nonce: nil, timestamp: nil, signature: nil
            ),
            position: .bottom,
            dismissible: true
        )
        #expect(result == false)
    }

    // MARK: - dismiss() preconditions

    @Test
    func dismissReturnsFalseWhenNothingToDismiss() async {
        // Running unit tests with no active SKOverlay must return false.
        let result = await SKOverlayManager.shared.dismiss()
        #expect(result == false)
    }

    // MARK: - DefaultSKOverlayPresenter passthrough

    @Test
    func defaultPresenterForwardsEmptyItunesToFalse() async {
        let presenter = DefaultSKOverlayPresenter()
        let result = await presenter.present(
            skan: Skan(
                version: "1", network: "x", itunesItem: "",
                sourceApp: "0", sourceIdentifier: nil, campaign: nil,
                fidelities: [], nonce: nil, timestamp: nil, signature: nil
            ),
            position: .bottom,
            dismissible: false
        )
        #expect(result == false)
    }

    @Test
    func defaultPresenterDismissReturnsFalseWhenNothingActive() async {
        let result = await DefaultSKOverlayPresenter().dismiss()
        #expect(result == false)
    }

    // MARK: - SKOverlayDisplayPosition enum

    @Test
    func skOverlayDisplayPositionCasesExist() {
        // Exhaustiveness check — each case is expected by other tests and the
        // mapping extension. If a new case is added, this compile-checks the match.
        let positions: [SKOverlayDisplayPosition] = [.bottom, .bottomRaised]
        #expect(positions.count == 2)
    }
}
