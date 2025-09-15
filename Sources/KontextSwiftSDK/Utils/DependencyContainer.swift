struct DependencyContainer: Sendable {
    let networking: Networking
    let adsServerAPI: AdsServerAPI
    let adsProviderActing: AdsProviderActing
    let omService: OMServicing

    init(
        networking: Networking,
        adsServerAPI: AdsServerAPI,
        adsProviderActing: AdsProviderActing,
        omService: OMServicing
    ) {
        self.networking = networking
        self.adsServerAPI = adsServerAPI
        self.adsProviderActing = adsProviderActing
        self.omService = omService
    }
    
    static func defaultContainer(
        configuration: AdsProviderConfiguration,
        sessionId: String?,
        isDisabled: Bool
    ) -> DependencyContainer {
        let networking = Network()
        let omService = OMService()
        let adsServerAPI = BaseURLAdsServerAPI(
            baseURL: configuration.adServerUrl,
            networking: networking
        )
        let providerActor = AdsProviderActor(
            configuration: configuration,
            sessionId: sessionId,
            isDisabled: isDisabled,
            adsServerAPI: adsServerAPI,
            omService: omService
        )

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor,
            omService: omService
        )
    }
}
