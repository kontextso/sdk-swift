import KontextKit
@testable import KontextSwiftSDK
import Testing

@MainActor
struct DependencyContainerTests {

    @Test func defaultCreatesContainerWithProductionAdapters() {
        let container = DependencyContainer.default()

        #expect(container.omManager is OMManager)
        #expect(container.skAdNetworkManager is KontextKitSKAdNetworkAdapter)
        #expect(container.skStoreProductManager is KontextKitSKStoreProductAdapter)
        #expect(container.skOverlayManager is KontextKitSKOverlayAdapter)
    }

    @Test func containerStoresAllProvidedManagers() {
        let om = OMManager(partner: OMPartner(name: "test", version: "0.0.0"))
        let skAd: SKAdNetworkManaging = KontextKitSKAdNetworkAdapter()
        let skStore: SKStoreProductManaging = KontextKitSKStoreProductAdapter()
        let skOverlay: SKOverlayManaging = KontextKitSKOverlayAdapter()

        let container = DependencyContainer(
            omManager: om,
            skAdNetworkManager: skAd,
            skStoreProductManager: skStore,
            skOverlayManager: skOverlay
        )

        #expect(container.omManager is OMManager)
        #expect(container.skAdNetworkManager is KontextKitSKAdNetworkAdapter)
        #expect(container.skStoreProductManager is KontextKitSKStoreProductAdapter)
        #expect(container.skOverlayManager is KontextKitSKOverlayAdapter)
    }
}
