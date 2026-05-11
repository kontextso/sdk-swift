import KontextKit

/// Holds shared dependencies for a single session lifecycle.
///
/// Provides a single point of configuration for services used across
/// the SDK. The default container uses production implementations;
/// tests can inject mocks.
@MainActor
struct DependencyContainer {
    /// Open Measurement SDK manager.
    let omManager: OMManaging

    /// SKAdNetwork impression lifecycle manager.
    let skAdNetworkManager: SKAdNetworkManaging

    /// SKStoreProduct presentation manager.
    let skStoreProductManager: SKStoreProductManaging

    /// SKOverlay presentation manager.
    let skOverlayManager: SKOverlayManaging

    /// Creates a container with production defaults.
    ///
    /// `OMManager` is instantiated per session because it carries
    /// per-session OMID activation state. The three KontextKit-backed
    /// managers are wrapped in async/typed adapter classes that translate
    /// to KontextKit's process-global `.shared` singletons under the hood
    /// (the singletons wrap Apple APIs — `SKAdImpression`, `SKOverlay`,
    /// `SKStoreProductViewController` — that don't admit multiple owners).
    static func `default`() -> DependencyContainer {
        let partner = OMPartner(
            name: Constants.omidPartnerName,
            version: Constants.omidPartnerVersion
        )
        return DependencyContainer(
            omManager: OMManager(partner: partner),
            skAdNetworkManager: KontextKitSKAdNetworkAdapter(),
            skStoreProductManager: KontextKitSKStoreProductAdapter(),
            skOverlayManager: KontextKitSKOverlayAdapter()
        )
    }
}
