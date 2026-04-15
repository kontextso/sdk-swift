@preconcurrency import Combine
import UIKit

struct DependencyContainer: Sendable {
    let networking: Networking
    let adsServerAPI: AdsServerAPI
    let adsProviderActing: AdsProviderActing
    let omService: OMManaging

    init(
        networking: Networking,
        adsServerAPI: AdsServerAPI,
        adsProviderActing: AdsProviderActing,
        omService: OMManaging
    ) {
        self.networking = networking
        self.adsServerAPI = adsServerAPI
        self.adsProviderActing = adsProviderActing
        self.omService = omService
    }

    @MainActor
    static func defaultContainer(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool,
        adWebViewEventSubject: PassthroughSubject<AdWebViewUpdateEvent, Never>
    ) -> DependencyContainer {
        let networking = Network()
        let omService = OMManager()
        let adsServerAPI = BaseURLAdsServerAPI(
            baseURL: configuration.adServerUrl,
            networking: networking
        )
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            urlOpener: UIApplication.shared,
            omService: omService,
            adWebViewEventSubject: adWebViewEventSubject,
            skAdNetworkManager: DefaultSKAdNetworkManager.shared,
            skOverlayPresenter: SKOverlayManager.shared,
            skStoreProductPresenter: SKStoreProductManager.shared
        )

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor,
            omService: omService
        )
    }
}
