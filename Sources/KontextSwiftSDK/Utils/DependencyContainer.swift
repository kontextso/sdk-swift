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
            adsServerAPI: adsServerAPI
        )

        return DependencyContainer(
            networking: networking,
            adsServerAPI: adsServerAPI,
            adsProviderActing: providerActor
        )
    }
}
