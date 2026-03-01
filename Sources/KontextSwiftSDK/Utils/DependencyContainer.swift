import UIKit

struct DependencyContainer: Sendable {
    let networking: Networking
    let adsServerAPI: AdsServerAPI
    let adsProviderActing: AdsProviderActing

    init(
        networking: Networking,
        adsServerAPI: AdsServerAPI,
        adsProviderActing: AdsProviderActing
    ) {
        self.networking = networking
        self.adsServerAPI = adsServerAPI
        self.adsProviderActing = adsProviderActing
    }

    @MainActor
    static func defaultContainer(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool
    ) -> DependencyContainer {
        let networking = Network()
        let adsServerAPI = BaseURLAdsServerAPI(
            trackingURL: configuration.adServerUrl,
            contextualURL: configuration.ctxAdServerUrl,  // ← add
            networking: networking
        )
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            urlOpener: UIApplication.shared,
            skAdNetworkManager: DefaultSKAdNetworkManager.shared,
            skOverlayPresenter: SKOverlayManager.shared,
            skStoreProductPresenter: SKStoreProductManager.shared
        )

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor
        )
    }
}
