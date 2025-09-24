import UIKit

struct DependencyContainer: Sendable {
    let networking: Networking
    let adsServerAPI: AdsServerAPI
    let adsProviderActing: AdsProviderActing
    let adImpressionService: AdImpressionServicing

    init(
        networking: Networking,
        adsServerAPI: AdsServerAPI,
        adsProviderActing: AdsProviderActing,
        adImpressionService: AdImpressionServicing
    ) {
        self.networking = networking
        self.adsServerAPI = adsServerAPI
        self.adsProviderActing = adsProviderActing
        self.adImpressionService = adImpressionService
    }

    @MainActor
    static func defaultContainer(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool
    ) -> DependencyContainer {
        let networking = Network()
        let adsServerAPI = BaseURLAdsServerAPI(
            baseURL: configuration.adServerUrl,
            networking: networking
        )
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            urlOpener: UIApplication.shared
        )

        let adImpressionService: AdImpressionServicing = {
            if #available(iOS 17.4, *) {
                return AdAttributionImpressionService()
            } else {
                return SKAdNetworkImpressionService()
            }
        }()

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor,
            adImpressionService: adImpressionService
        )
    }
}
